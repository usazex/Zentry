-- TaskApplier.lua Module Script
local TaskApplier = {}

local HttpService = game:GetService("HttpService") -- For decoding property value strings if necessary (though direct eval is used)
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local StarterPlayer = game:GetService("StarterPlayer")
local StarterGui = game:GetService("StarterGui")
local StarterPack = game:GetService("StarterPack")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local TextChatService = game:GetService("TextChatService")
-- Add other services as needed

-- Helper to convert string path like "game.Workspace.MyPart" to an Instance
local function getInstanceFromPath(pathString)
	if not pathString or type(pathString) ~= "string" then
		return nil, "PathString is nil or not a string"
	end

	if not pathString:match("^game%.") then
		return nil, "PathString must start with 'game.'"
	end

	local parts = {}
	for part in pathString:gmatch("([^%.]+)") do
		table.insert(parts, part)
	end

	if #parts == 0 or parts[1] ~= "game" then
		return nil, "Invalid path format or first part is not 'game'"
	end

	local currentInstance = game
	for i = 2, #parts do
		local partName = parts[i]
		local foundInstance = currentInstance:FindFirstChild(partName)
		if not foundInstance then
			return nil, "Could not find instance '" .. partName .. "' in path '" .. pathString .. "' (under parent '"..currentInstance:GetFullName().."')"
		end
		currentInstance = foundInstance
	end
	return currentInstance, nil
end

-- Helper to get the parent instance and the name of the target item from a full path
local function getParentAndName(fullPath)
    if not fullPath or not fullPath:match("^game%.[^%.]+%.") then -- e.g. game.Workspace.Item
        return nil, nil, "Invalid full path format. Must be game.Service.Item... " .. tostring(fullPath)
    end
    local match = fullPath:match("^(.*)%.([^%.]+)$")
    if not match then -- Path might be just game.ServiceName (e.g. game.Workspace)
         return nil, nil, "Path does not seem to point to an item within a service: " .. fullPath
    end

    local parentPath = fullPath:match("^(.*)%.")
    parentPath = parentPath:sub(1, #parentPath -1) -- remove trailing dot
    local itemName = fullPath:match("([^%.]+)$")

    local parentInstance, err = getInstanceFromPath(parentPath)
    if err then
        return nil, nil, "Could not get parent instance from path '" .. parentPath .. "': " .. err
    end
    return parentInstance, itemName, nil
end


-- Helper to evaluate property values from strings.
-- This is a simplified and potentially UNSAFE evaluator.
-- For a production plugin, a proper Lua parser/sandboxed environment would be much safer.
local function evaluatePropertyValue(valueString, contextInstance)
	if type(valueString) ~= "string" then
		return valueString -- Assume it's already a correct type (e.g. boolean, number from JSON)
	end

	-- Simple replacements for Roblox globals (extend as needed)
	local env = {
		Vector3 = Vector3,
		Color3 = Color3,
		UDim2 = UDim2,
		UDim = UDim,
		BrickColor = BrickColor,
		Enum = Enum,
		Instance = Instance,
		game = game, -- Provide game global
		workspace = Workspace, -- Alias for Workspace
		script = contextInstance, -- Context for 'script.Parent' etc. if property refers to it
		print = print,
		true = true,
		false = false,
		nil = nil
		-- NOTE: Add other necessary globals/functions here
	}
    -- Allow numbers directly
    if tonumber(valueString) then return tonumber(valueString) end
    -- Allow booleans directly
    if valueString == "true" then return true end
    if valueString == "false" then return false end


	-- Attempt to load the string as a Lua chunk.
	-- Prepend "return " to make it an expression.
	local func, err = loadstring("return " .. valueString)
	if not func then
		-- If loadstring fails, it might be a plain string literal that doesn't need "return"
		-- or it's an invalid expression. For safety, just return the original string if it looks like one.
		-- This is a very basic heuristic.
		if (valueString:sub(1,1) == '"' and valueString:sub(-1,-1) == '"') or
		   (valueString:sub(1,1) == "'" and valueString:sub(-1,-1) == "'") then
			return valueString:sub(2, -2) -- Return the content of the string literal
		end
        warn("TaskApplier: evaluatePropertyValue: Failed to load value string '" .. valueString .. "' as Lua expression. Error: " .. tostring(err) .. ". Returning as raw string.")
		return valueString -- Return raw string if load fails and it's not a simple string literal
	end

	setfenv(func, env) -- Set the environment for the loaded chunk
	local success, result = pcall(func)

	if success then
		return result
	else
		warn("TaskApplier: evaluatePropertyValue: Failed to execute value string '" .. valueString .. "' as Lua expression. Error: " .. tostring(result) .. ". Returning as raw string.")
		return valueString -- Return raw string if execution fails
	end
end


function TaskApplier.applyTask(taskData)
	if not taskData or not taskData.operation_type then
		return false, "Invalid task data or missing operation_type."
	end

	local opType = taskData.operation_type
	local targetPath = taskData.target_path
	local itemName = taskData.item_name -- Primarily for CREATE, informational for others
	local payload = taskData.payload

	print("TaskApplier: Processing task_id '"..tostring(taskData.task_id).."' - operation: " .. opType .. ", target: " .. targetPath)

	if opType == "CREATE_INSTANCE" then
		local parentInstance, newItemName, err = getParentAndName(targetPath)
		if err then return false, "CREATE_INSTANCE: " .. err end
		if not parentInstance then return false, "CREATE_INSTANCE: Parent instance not found for path '" .. targetPath .. "'" end
        if newItemName ~= itemName then
            warn("TaskApplier: CREATE_INSTANCE item_name ('"..itemName.."') mismatch with name from target_path ('"..newItemName.."'). Using item_name from payload or task.")
            newItemName = itemName -- Prioritize task's item_name
        end

		if parentInstance:FindFirstChild(newItemName) then
			return false, "CREATE_INSTANCE: Item '" .. newItemName .. "' already exists in '" .. parentInstance:GetFullName() .. "'."
		end
		if not payload or not payload.instance_class or not payload.properties then
			return false, "CREATE_INSTANCE: Invalid payload. Missing instance_class or properties."
		end

		local newInstance = Instance.new(payload.instance_class)
		newInstance.Name = newItemName -- Ensure name is set from the consistent source

		for propName, propValueStr in pairs(payload.properties) do
			if propName ~= "Name" then -- Name is already handled
				local success, err = pcall(function() newInstance[propName] = evaluatePropertyValue(propValueStr, newInstance) end)
				if not success then
					warn("TaskApplier: CREATE_INSTANCE: Failed to set property '" .. propName .. "' on '" .. newItemName .. "'. Error: " .. err)
                    -- Optionally, return false here or collect errors
				end
			end
		end
		newInstance.Parent = parentInstance
		return true, "Instance '" .. newItemName .. "' of type '" .. payload.instance_class .. "' created at '" .. parentInstance:GetFullName() .. "'."

	elseif opType == "CREATE_SCRIPT" then
		local parentInstance, newScriptName, err = getParentAndName(targetPath)
		if err then return false, "CREATE_SCRIPT: " .. err end
        if not parentInstance then return false, "CREATE_SCRIPT: Parent instance not found for path '" .. targetPath .. "'" end
        if newScriptName ~= itemName then
            warn("TaskApplier: CREATE_SCRIPT item_name ('"..itemName.."') mismatch with name from target_path ('"..newScriptName.."'). Using item_name from payload or task.")
            newScriptName = itemName -- Prioritize task's item_name
        end

		if parentInstance:FindFirstChild(newScriptName) then
			return false, "CREATE_SCRIPT: Script '" .. newScriptName .. "' already exists in '" .. parentInstance:GetFullName() .. "'."
		end
		if not payload or not payload.script_type or payload.source_code == nil then
			return false, "CREATE_SCRIPT: Invalid payload. Missing script_type or source_code."
		end

		local newScript = Instance.new(payload.script_type)
		newScript.Name = newScriptName
		newScript.Source = payload.source_code

        if payload.properties then
            for propName, propValueStr in pairs(payload.properties) do
                if propName ~= "Name" then -- Name is already handled
                    local success, errProp = pcall(function() newScript[propName] = evaluatePropertyValue(propValueStr, newScript) end)
                    if not success then
                        warn("TaskApplier: CREATE_SCRIPT: Failed to set property '" .. propName .. "' on '" .. newScriptName .. "'. Error: " .. errProp)
                    end
                end
            end
        end

		newScript.Parent = parentInstance
		return true, "Script '" .. newScriptName .. "' of type '" .. payload.script_type .. "' created at '" .. parentInstance:GetFullName() .. "'."

	elseif opType == "UPDATE_INSTANCE" then
		local instance, err = getInstanceFromPath(targetPath)
		if err then return false, "UPDATE_INSTANCE: " .. err end
		if not instance then return false, "UPDATE_INSTANCE: Instance not found at path '" .. targetPath .. "'." end

		if not payload or not payload.properties_to_change or next(payload.properties_to_change) == nil then
			return false, "UPDATE_INSTANCE: Invalid payload. Missing or empty properties_to_change."
		end

        local changesApplied = 0
		for propName, propValueStr in pairs(payload.properties_to_change) do
            if propName == "Name" and instance.Name ~= propValueStr then
                -- TODO: Handle renaming carefully, check if new name conflicts in parent
                -- For now, allow direct name change if explicitly provided
                 warn("TaskApplier: UPDATE_INSTANCE attempting to change Name property for '"..targetPath.."' to '"..propValueStr.."'. This might have side effects if not handled carefully by AI.")
            end
			local success, errSet = pcall(function() instance[propName] = evaluatePropertyValue(propValueStr, instance) end)
			if not success then
				warn("TaskApplier: UPDATE_INSTANCE: Failed to set property '" .. propName .. "' on '" .. targetPath .. "'. Error: " .. errSet)
                -- Optionally, return false here or collect errors
			else
                changesApplied = changesApplied + 1
            end
		end
		return true, "Instance '" .. targetPath .. "' updated. ("..changesApplied.." properties attempted)"

	elseif opType == "UPDATE_SCRIPT" then
		local scriptInstance, err = getInstanceFromPath(targetPath)
		if err then return false, "UPDATE_SCRIPT: " .. err end
		if not scriptInstance then return false, "UPDATE_SCRIPT: Script not found at path '" .. targetPath .. "'." end
		if not scriptInstance:IsA("BaseScript") then return false, "UPDATE_SCRIPT: Instance at '" .. targetPath .. "' is not a script (found " .. scriptInstance.ClassName .. ")." end

		if not payload or payload.new_source_code == nil or payload.update_strategy ~= "REPLACE_CONTENT" then
			return false, "UPDATE_SCRIPT: Invalid payload. Missing new_source_code or incorrect update_strategy."
		end

		scriptInstance.Source = payload.new_source_code
		return true, "Script '" .. targetPath .. "' updated."

	elseif opType == "REMOVE_ITEM" then
		local instance, err = getInstanceFromPath(targetPath)
		if err then return false, "REMOVE_ITEM: " .. err end -- Error finding, likely means it doesn't exist as expected
		if not instance then
            -- This case should ideally be caught by AI's analysis.
            -- If AI still generates REMOVE for non-existent, treat as "success" (idempotency) or specific warning.
			return true, "REMOVE_ITEM: Item at path '" .. targetPath .. "' not found. Assumed already removed or path incorrect."
		end
        if instance == game then return false, "REMOVE_ITEM: Cannot remove the 'game' instance." end
        -- Add more guards for essential services if needed

		instance:Destroy()
		return true, "Item '" .. targetPath .. "' removed."
	else
		return false, "Unknown operation_type: " .. opType
	end
end

return TaskApplier
