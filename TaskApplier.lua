-- TaskApplier.lua 
local TaskApplier = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage") -- Example, get services as needed
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
-- Add other services if they are common targets

-- Require TaskParser for extractScriptCode
local Modules = script.Parent
local TaskParser = require(Modules:WaitForChild("TaskParser"))

-- Helper: Find instance by location string (path)
function TaskApplier.findInstanceByPath(pathString)
	if not pathString or pathString == "" then return nil, "Path string is empty" end

	local pathSegments = {}
	for segment in string.gmatch(pathString, "[^/]+") do
		table.insert(pathSegments, segment)
	end

	if #pathSegments == 0 then return nil, "Path string resulted in no segments" end

	local currentInstance = game
	local firstSegment = pathSegments[1]

	-- Try GetService first for top-level services
	local success, service = pcall(game.GetService, game, firstSegment)
	if success and service then
		currentInstance = service
		table.remove(pathSegments, 1)
	else
		-- Fallback to common service variables if GetService fails or path doesn't start with a service name
		local commonServices = {
			Workspace = Workspace,
			ReplicatedStorage = ReplicatedStorage,
			ServerScriptService = ServerScriptService,
			StarterGui = StarterGui,
			StarterPlayer = StarterPlayer,
			ServerStorage = game:GetService("ServerStorage"), -- Ensure it's available
			Lighting = game:GetService("Lighting"),
			SoundService = game:GetService("SoundService"),
			StarterCharacterScripts = StarterPlayer and StarterPlayer:FindFirstChild("StarterCharacterScripts"),
			StarterPlayerScripts = StarterPlayer and StarterPlayer:FindFirstChild("StarterPlayerScripts")
		}
		if commonServices[firstSegment] then
			currentInstance = commonServices[firstSegment]
			table.remove(pathSegments, 1)
		elseif firstSegment == "game" then -- Handle paths like "game/Workspace/Part"
			table.remove(pathSegments, 1)
			if #pathSegments == 0 then -- Path was just "game"
				return game, nil
			end
			-- Update firstSegment for the next check if path was "game/ServiceName/..."
			firstSegment = pathSegments[1]
			local gameService = game:GetService(firstSegment)
			if gameService then
				currentInstance = gameService
				table.remove(pathSegments,1)
			elseif commonServices[firstSegment] then
				currentInstance = commonServices[firstSegment]
				table.remove(pathSegments,1)
			else
				-- Path might be like "game/DirectChildOfGame" which is unusual
				-- currentInstance remains 'game'
			end
		end
	end

	-- If pathSegments is now empty, it means the path was just a service name
	if #pathSegments == 0 then
		if currentInstance ~= game then
			return currentInstance, nil
		else
			return nil, "Path resolved to 'game' but needed a service or instance."
		end
	end

	for _, segmentName in ipairs(pathSegments) do
		if currentInstance then
			currentInstance = currentInstance:FindFirstChild(segmentName)
			if not currentInstance then
				return nil, "Segment '" .. segmentName .. "' not found in path '" .. pathString .. "'"
			end
		else
			-- This case should ideally not be reached if previous checks are done right
			return nil, "Path broken at segment '" .. segmentName .. "' in path '" .. pathString .. "'"
		end
	end
	return currentInstance, nil
end

-- Convert string value to actual Roblox type if possible
function TaskApplier.convertPropertyValue(valueStr)
	if type(valueStr) ~= "string" then
		return valueStr -- Return as is if not a string (e.g. already boolean/number from JSON)
	end

	-- Try Vector3
	local x,y,z = valueStr:match("^Vector3%.new%((%-?%d*%.?%d*),%s*(%-?%d*%.?%d*),%s*(%-?%d*%.?%d*)%)$")
	if x then return Vector3.new(tonumber(x), tonumber(y), tonumber(z)) end

	-- Try Color3
	local r,g,b = valueStr:match("^Color3%.fromRGB%((%d+),%s*(%d+),%s*(%d+)%)$")
	if r then return Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b)) end
	r,g,b = valueStr:match("^Color3%.new%((%d*%.?%d*),%s*(%d*%.?%d*),%s*(%d*%.?%d*)%)$")
	if r then return Color3.new(tonumber(r), tonumber(g), tonumber(b)) end

	-- Try boolean (string "true" or "false")
	if valueStr:lower() == "true" then return true end
	if valueStr:lower() == "false" then return false end

	-- Try number
	local num = tonumber(valueStr)
	if num then return num end

	-- Default to string (remove quotes if it's a quoted string from AI)
	return valueStr:match('^"(.*)"$') or valueStr:match("^'(.*)'$") or valueStr
end

-- Apply properties from a table to an instance
function TaskApplier.applyProperties(instance, propertiesTable)
	if not propertiesTable or type(propertiesTable) ~= "table" then return {} end
	local appliedProps = {}
	local failedProps = {}

	for propName, propValueInput in pairs(propertiesTable) do
		local actualValue = TaskApplier.convertPropertyValue(propValueInput)
		local success, err = pcall(function()
			instance[propName] = actualValue
		end)
		if success then
			table.insert(appliedProps, propName)
		else
			table.insert(failedProps, {name = propName, value = tostring(propValueInput), error = err})
		end
	end
	return appliedProps, failedProps
end

-- Actually apply task to game
-- Returns: success (boolean), message (string)
function TaskApplier.applyTask(taskData)
	if not TaskParser then TaskParser = require(script.Parent:FindFirstChild("TaskParser")) end
	if not TaskParser then return false, "TaskParser module not found." end

	local action = (taskData.action or ""):lower()
	local parentPath = taskData.location
	local parentInstance, findError = TaskApplier.findInstanceByPath(parentPath)

	if not parentInstance then
		return false, "Parent location not found: '" .. tostring(parentPath) .. "'. " .. (findError or "")
	end

	local taskName = taskData.name or "UnnamedTask"

	if action == "add_script" or action == "add_instance" then
		local instanceType = taskData.instance_type or (action == "add_script" and "Script" or "Part")
		local newInstance
		local createSuccess, createErr = pcall(function() newInstance = Instance.new(instanceType) end)
		if not createSuccess or not newInstance then
			return false, "Failed to create instance of type '"..instanceType.."'. Error: "..tostring(createErr)
		end

		newInstance.Name = taskName
		if taskData.properties then
			local _, failedProps = TaskApplier.applyProperties(newInstance, taskData.properties)
			if taskData.properties.Name then -- Name property might be in properties, prefer that
				newInstance.Name = TaskApplier.convertPropertyValue(taskData.properties.Name)
			end
			if #failedProps > 0 then
				-- Partial success, but some properties failed. Report this.
				local failureDetails = ""
				for _, fp in ipairs(failedProps) do failureDetails = failureDetails .. fp.name .. " (" .. fp.error .. "); " end
				-- Message can be improved to show this later
			end
		end

		if action == "add_script" then
			local code = TaskParser.extractScriptCode(taskData)
			newInstance.Source = "-- Script generated by AI Vibe Coder ✨ (Zentry)\n" .. code
		end

		newInstance.Parent = parentInstance
		return true, "Added '" .. newInstance.Name .. "' (" .. instanceType .. ") to " .. parentInstance:GetFullName()

	elseif action == "update_script" then
		if not taskData.name then return false, "'name' field missing for update_script on parent " .. parentPath end
		local targetScript = parentInstance:FindFirstChild(taskData.name)
		if targetScript and (targetScript:IsA("Script") or targetScript:IsA("LocalScript") or targetScript:IsA("ModuleScript")) then
			local code = TaskParser.extractScriptCode(taskData)
			targetScript.Source = code
			return true, "Script '" .. taskData.name .. "' in " .. parentInstance:GetFullName() .. " updated."
		else
			return false, "Could not find script '" .. taskData.name .. "' to update in " .. parentInstance:GetFullName()
		end

	elseif action == "update_instance" then
		if not taskData.name then return false, "'name' field missing for update_instance on parent " .. parentPath end
		local targetInstance = parentInstance:FindFirstChild(taskData.name)
		if targetInstance then
			if taskData.properties then
				local _, failedProps = TaskApplier.applyProperties(targetInstance, taskData.properties)
				local message = "Instance '" .. taskData.name .. "' in " .. parentInstance:GetFullName() .. " updated."
				if #failedProps > 0 then
					message = message .. " Some properties failed to apply."
				end
				return true, message
			else
				return true, "Instance '" .. taskData.name .. "' found, but no properties provided for update." -- Or consider this a warning/partial success
			end
		else
			return false, "Could not find instance '" .. taskData.name .. "' to update in " .. parentInstance:GetFullName()
		end

	elseif action == "remove_instance" then
		if not taskData.name then return false, "'name' field missing for remove_instance on parent " .. parentPath end
		local targetInstance = parentInstance:FindFirstChild(taskData.name)
		if targetInstance then
			targetInstance:Destroy()
			return true, "Instance '" .. taskData.name .. "' removed from " .. parentInstance:GetFullName()
		else
			return false, "Could not find instance '" .. taskData.name .. "' to remove in " .. parentInstance:GetFullName()
		end
	else
		return false, "Unknown or unsupported action: '" .. tostring(taskData.action) .. "' for task '" .. taskName .. "'."
	end
end

return TaskApplier

