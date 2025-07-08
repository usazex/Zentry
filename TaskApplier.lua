-- TaskApplier.lua
local TaskApplier = {}
local HttpService = game:GetService("HttpService")

-- Service references for common parent locations
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Helper to resolve a path string to an Instance
local function getInstanceFromPath(pathString)
	if type(pathString) ~= "string" then 
		warn("Path must be a string")
		return nil 
	end

	-- Handle special case for "game"
	if pathString == "game" then
		return game
	end

	-- Normalize path format
	pathString = pathString:gsub("/", "."):gsub("^game%.", "")
	if pathString == "" then return game end

	local current = game
	for part in pathString:gmatch("([^%.]+)") do
		current = current:FindFirstChild(part)
		if not current then 
			warn("Path segment not found:", part, "in path:", pathString)
			return nil 
		end
	end

	return current
end

-- Helper to safely evaluate property values from strings
local function evaluatePropertyValue(valueString, contextInstance)
	if type(valueString) ~= "string" then
		return valueString
	end

	-- Handle common Roblox types
	local env = {
		Vector3 = Vector3,
		Color3 = Color3,
		UDim2 = UDim2,
		CFrame = CFrame,
		Enum = Enum,
		Instance = Instance,
		game = game,
		workspace = Workspace,
		script = contextInstance
	}

	-- Handle basic types
	if valueString == "true" then return true end
	if valueString == "false" then return false end
	if tonumber(valueString) then return tonumber(valueString) end

	-- Handle string literals (FIXED version)
	if valueString:match('^".*"$') or valueString:match("^'.*'$") then
		return valueString:sub(2, -2)
	end

	-- Try evaluating as Lua code
	local func, err = loadstring("return "..valueString)
	if not func then
		return valueString -- Return as raw string if not evaluable
	end

	setfenv(func, env)
	local success, result = pcall(func)
	return success and result or valueString
end

-- Helper to get parent and name from full path
local function getParentAndName(fullPath)
	if not fullPath:match("^game%.") then
		fullPath = "game."..fullPath
	end

	local lastDot = fullPath:reverse():find("%.")
	if not lastDot then return nil, nil, "Invalid path format" end

	local parentPath = fullPath:sub(1, #fullPath - lastDot)
	local itemName = fullPath:sub(#fullPath - lastDot + 2)

	local parent = getInstanceFromPath(parentPath)
	if not parent then
		return nil, nil, "Parent not found: "..parentPath
	end

	return parent, itemName
end

-- Main task application function
function TaskApplier.applyTask(taskData)
	-- Input validation
	if not taskData or type(taskData) ~= "table" then
		return false, "Invalid task data"
	end

	local opType = taskData.operation_type
	local targetPath = taskData.target_path
	local itemName = taskData.item_name or "UnnamedItem"
	local payload = taskData.payload or {}
	local taskId = taskData.task_id or "unknown_task"

	print(string.format("[TaskApplier] Processing task %s: %s on %s", 
		taskId, opType, targetPath))

	-- Handle each operation type
	if opType == "CREATE_INSTANCE" then
		-- Validate
		if not payload.instance_class then
			return false, "Missing instance_class in payload"
		end

		-- Get parent container
		local parent, _, err = getParentAndName(targetPath)
		if not parent then return false, err end

		-- Check if already exists
		if parent:FindFirstChild(itemName) then
			return false, "Instance already exists: "..itemName
		end

		-- Create instance
		local newInstance = Instance.new(payload.instance_class)
		newInstance.Name = itemName

		-- Set properties
		if payload.properties then
			for prop, value in pairs(payload.properties) do
				if prop ~= "Name" then
					pcall(function()
						newInstance[prop] = evaluatePropertyValue(value, newInstance)
					end)
				end
			end
		end

		newInstance.Parent = parent
		return true, "Created "..payload.instance_class..": "..itemName

	elseif opType == "CREATE_SCRIPT" then
		-- Validate
		if not payload.script_type then
			return false, "Missing script_type in payload"
		end
		if not payload.source_code then
			return false, "Missing source_code in payload"
		end

		-- Get parent container
		local parent, _, err = getParentAndName(targetPath)
		if not parent then return false, err end

		-- Check if script already exists
		local existingScript = parent:FindFirstChild(itemName)
		if existingScript then
			if existingScript:IsA("LuaSourceContainer") then
				-- Convert to UPDATE operation
				print("Converting CREATE to UPDATE for existing script:", itemName)
				return TaskApplier.applyTask({
					task_id = taskData.task_id.."_update",
					operation_type = "UPDATE_SCRIPT",
					target_path = targetPath.."."..itemName,
					payload = {
						new_source_code = payload.source_code
					}
				})
			else
				return false, "Name conflict: "..itemName.." exists but is not a script"
			end
		end

		-- Create script
		print("Creating script:", itemName, "in", parent:GetFullName())
		local newScript = Instance.new(payload.script_type)
		newScript.Name = itemName
		newScript.Source = payload.source_code

		-- Set properties
		if payload.properties then
			for prop, value in pairs(payload.properties) do
				if prop ~= "Name" then
					local success, result = pcall(function()
						newScript[prop] = evaluatePropertyValue(value, newScript)
					end)
					if not success then
						warn("Failed to set property", prop, "on script:", result)
					end
				end
			end
		end

		newScript.Parent = parent
		return true, "Created "..payload.script_type..": "..itemName.." in "..parent:GetFullName()

	elseif opType == "UPDATE_INSTANCE" then
		-- Get target instance
		local instance = getInstanceFromPath(targetPath)
		if not instance then
			return false, "Instance not found: "..targetPath
		end

		-- Validate
		if not payload.properties_to_change then
			return false, "Missing properties_to_change in payload"
		end

		-- Apply changes
		local changesApplied = 0
		for prop, value in pairs(payload.properties_to_change) do
			local success = pcall(function()
				instance[prop] = evaluatePropertyValue(value, instance)
			end)
			if success then changesApplied = changesApplied + 1 end
		end

		return true, "Updated "..changesApplied.." properties on "..targetPath

	elseif opType == "UPDATE_SCRIPT" then
		-- Get target script
		local scriptInstance = getInstanceFromPath(targetPath)
		if not scriptInstance then
			return false, "Script not found: "..targetPath
		end
		if not scriptInstance:IsA("LuaSourceContainer") then
			return false, "Target is not a script: "..targetPath
		end

		-- Validate
		if not payload.new_source_code then
			return false, "Missing new_source_code in payload"
		end

		-- Update script
		scriptInstance.Source = payload.new_source_code
		return true, "Updated script: "..targetPath

	elseif opType == "REMOVE_ITEM" then
		-- Get target instance
		local instance = getInstanceFromPath(targetPath)
		if not instance then
			return true, "Item already removed: "..targetPath
		end

		-- Safety check
		if instance == game then
			return false, "Cannot remove game instance"
		end

		instance:Destroy()
		return true, "Removed item: "..targetPath

	else
		return false, "Unsupported operation type: "..tostring(opType)
	end
end

return TaskApplier
