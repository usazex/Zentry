-- TaskApplier.lua
local TaskApplier = {}

-- Roblox Services
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local InsertService = game:GetService("InsertService") -- For inserting models by asset ID if ever needed

-- Helper function to find an instance by its full path
-- Path examples: "Workspace/Model/Part", "ServerScriptService/MyScript"
function TaskApplier.findInstance(path)
	if not path or path == "" then
		return nil, "Path is empty"
	end

	local parts = path:split("/")
	local currentInstance = game

	for i, partName in ipairs(parts) do
		if i == 1 then -- Check against top-level services
			if partName == "Workspace" then
				currentInstance = Workspace
			elseif partName == "ReplicatedStorage" then
				currentInstance = ReplicatedStorage
			elseif partName == "ServerScriptService" then
				currentInstance = ServerScriptService
			elseif partName == "StarterGui" then
				currentInstance = StarterGui
			elseif partName == "StarterPlayer" then
				currentInstance = StarterPlayer
			elseif partName == "ServerStorage" then
				currentInstance = ServerStorage
			elseif partName == "Lighting" then
				currentInstance = Lighting
			elseif partName == "SoundService" then
				currentInstance = SoundService
            elseif game:GetService(partName) then -- Generic GetService
                currentInstance = game:GetService(partName)
			else
				return nil, "Service '" .. partName .. "' not found or not supported."
			end
		else
			if currentInstance then
				currentInstance = currentInstance:FindFirstChild(partName, true) -- Recursive find for subsequent parts
				if not currentInstance then
					return nil, "Instance '" .. partName .. "' not found in '" .. table.concat(parts, "/", 1, i-1) .. "'."
				end
			else
				return nil, "Parent instance became nil while traversing path." -- Should not happen if logic is correct
			end
		end
	end
	return currentInstance, (currentInstance and "Instance found" or "Instance not found at end of path")
end

-- Action Handler: Add Script
local function handleAddScript(taskData)
	local parent, err = TaskApplier.findInstance(taskData.location)
	if not parent then
		return false, "Failed to add script: Parent location '" .. taskData.location .. "' not found. Details: " .. (err or "Unknown error")
	end

	if not taskData.instance_type or not (taskData.instance_type == "Script" or taskData.instance_type == "LocalScript" or taskData.instance_type == "ModuleScript") then
		return false, "Failed to add script: Invalid or missing instance_type. Must be Script, LocalScript, or ModuleScript."
	end

	local scriptName = taskData.name or taskData.instance_type -- Default name if not provided
	local existingScript = parent:FindFirstChild(scriptName)
	if existingScript then
		return false, "Failed to add script: An instance named '" .. scriptName .. "' already exists in '" .. taskData.location .. "'."
	end

	local newScript = Instance.new(taskData.instance_type)
	newScript.Name = scriptName
	newScript.Source = taskData.code or ""
	newScript.Parent = parent

	return true, "'" .. newScript.Name .. "' (" .. newScript.ClassName .. ") created in '" .. taskData.location .. "'."
end

-- Action Handler: Update Script
local function handleUpdateScript(taskData)
	local parentLocation = taskData.location
	local scriptName = taskData.name

	if not scriptName or scriptName == "" then
		return false, "Failed to update script: Script 'name' not specified in task data."
	end

	local fullPathToScript = parentLocation .. "/" .. scriptName
	local scriptInstance, err = TaskApplier.findInstance(fullPathToScript)

	if not scriptInstance then
		return false, "Failed to update script: Script '" .. scriptName .. "' not found at '" .. parentLocation .. "'. Details: " .. (err or "")
	end

	if not (scriptInstance:IsA("BaseScript")) then
		return false, "Failed to update script: Instance '" .. scriptName .. "' at '" .. parentLocation .. "' is not a script."
	end

	scriptInstance.Source = taskData.code or ""
	return true, "Script '" .. scriptName .. "' updated successfully at '" .. parentLocation .. "'."
end

-- Action Handler: Add Instance
local function handleAddInstance(taskData)
	local parent, err = TaskApplier.findInstance(taskData.location)
	if not parent then
		return false, "Failed to add instance: Parent location '" .. taskData.location .. "' not found. Details: " .. (err or "")
	end

	local instanceType = taskData.instance_type
	if not instanceType then
		return false, "Failed to add instance: 'instance_type' not specified."
	end

	local pcallSuccess, newInstance = pcall(function() return Instance.new(instanceType) end)
	if not pcallSuccess or not newInstance then
		return false, "Failed to add instance: Invalid 'instance_type' ('" .. instanceType .. "'). Error: " .. tostring(newInstance) -- newInstance is error message here
	end

	newInstance.Name = taskData.name or instanceType -- Default name if not provided

	-- Apply properties
	if taskData.properties and type(taskData.properties) == "table" then
		for propName, propValueStr in pairs(taskData.properties) do
			-- Attempt to evaluate property values as Lua expressions. This is risky.
			-- For safety, this should ideally use a more controlled property setter.
			-- Example: For Color3.fromRGB(r,g,b), it's fine. For arbitrary code, it's not.
			-- Consider a safer approach if this plugin is for wider distribution.
			local loadSuccess, loadedFunc = pcall(loadstring, "return " .. propValueStr)
			if loadSuccess then
				local valSuccess, value = pcall(loadedFunc)
				if valSuccess then
					local setSuccess, setErr = pcall(function() newInstance[propName] = value end)
					if not setSuccess then
						-- Log warning but continue if one property fails
						warn("TaskApplier: Could not set property '" .. propName .. "' to '" .. propValueStr .. "'. Error: " .. setErr)
					end
				else
					warn("TaskApplier: Could not evaluate property value '" .. propValueStr .. "'. Error: " .. tostring(value))
				end
			else
				warn("TaskApplier: Could not loadstring property value '" .. propValueStr .. "'. Error: " .. tostring(loadedFunc))
			end
		end
	end

	-- Check if an instance with the same name already exists
	local existingInstance = parent:FindFirstChild(newInstance.Name)
	if existingInstance then
		return false, "Failed to add instance: An instance named '" .. newInstance.Name .. "' already exists in '" .. taskData.location .. "'."
	end

	newInstance.Parent = parent
	return true, "'" .. newInstance.Name .. "' (" .. newInstance.ClassName .. ") added to '" .. taskData.location .. "'."
end

-- Action Handler: Update Instance
local function handleUpdateInstance(taskData)
	local parentLocation = taskData.location
	local instanceName = taskData.name

	if not instanceName or instanceName == "" then
		return false, "Failed to update instance: Instance 'name' not specified in task data."
	end

	local fullPathToInstance = parentLocation .. "/" .. instanceName
	local instance, err = TaskApplier.findInstance(fullPathToInstance)

	if not instance then
		return false, "Failed to update instance: Instance '" .. instanceName .. "' not found at '" .. parentLocation .. "'. Details: " .. (err or "")
	end

	if not taskData.properties or type(taskData.properties) ~= "table" or next(taskData.properties) == nil then
		return false, "Failed to update instance: 'properties' table is missing or empty."
	end

	local changesApplied = 0
	local errors = {}
	for propName, propValueStr in pairs(taskData.properties) do
		-- Similar to addInstance, using loadstring is risky.
		local loadSuccess, loadedFunc = pcall(loadstring, "return " .. propValueStr)
		if loadSuccess then
			local valSuccess, value = pcall(loadedFunc)
			if valSuccess then
				local setSuccess, setErr = pcall(function() instance[propName] = value end)
				if setSuccess then
					changesApplied = changesApplied + 1
				else
					table.insert(errors, "Property '" .. propName .. "': " .. setErr)
				end
			else
				table.insert(errors, "Property '" .. propName .. "': Could not evaluate value '" .. propValueStr .. "'. Error: " .. tostring(value))
			end
		else
			table.insert(errors, "Property '" .. propName .. "': Could not loadstring value '" .. propValueStr .. "'. Error: " .. tostring(loadedFunc))
		end
	end

	if changesApplied > 0 and #errors == 0 then
		return true, "Instance '" .. instanceName .. "' updated successfully. (" .. changesApplied .. " properties)"
	elseif changesApplied > 0 and #errors > 0 then
		return true, "Instance '" .. instanceName .. "' partially updated. (" .. changesApplied .. " properties). Errors: " .. table.concat(errors, "; ")
	else
		return false, "Failed to update any properties for instance '" .. instanceName .. "'. Errors: " .. table.concat(errors, "; ")
	end
end

-- Action Handler: Remove Instance
local function handleRemoveInstance(taskData)
	local parentLocation = taskData.location
	local instanceName = taskData.name

	if not instanceName or instanceName == "" then
		return false, "Failed to remove instance: Instance 'name' not specified in task data."
	end

	local fullPathToInstance = parentLocation .. "/" .. instanceName
	local instance, err = TaskApplier.findInstance(fullPathToInstance)

	if not instance then
		return false, "Failed to remove instance: Instance '" .. instanceName .. "' not found at '" .. parentLocation .. "'. Details: " .. (err or "")
	end

	instance:Destroy()
	return true, "Instance '" .. instanceName .. "' removed from '" .. parentLocation .. "'."
end


-- Main function to apply a single task
function TaskApplier.applyTask(taskData)
	if not taskData or not taskData.action then
		return false, "Invalid task data or missing 'action'."
	end

	local action = taskData.action
	local success, message

	if action == "add_script" then
		success, message = handleAddScript(taskData)
	elseif action == "update_script" then
		success, message = handleUpdateScript(taskData)
	elseif action == "add_instance" then
		success, message = handleAddInstance(taskData)
	elseif action == "update_instance" then
		success, message = handleUpdateInstance(taskData)
	elseif action == "remove_instance" then
		success, message = handleRemoveInstance(taskData)
	else
		success = false
		message = "Unknown action type: '" .. action .. "'."
	end

	return success, message
end

return TaskApplier
