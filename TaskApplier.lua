-- Zentry/Modules/TaskParser.lua
local TaskParser = {}
local HttpService = game:GetService("HttpService")

-- Normalizes a path from "Workspace/MyPart" or "game/Workspace/MyPart"
-- to "game.Workspace.MyPart"
local function normalizePath(path)
	if typeof(path) ~= "string" then return nil end
	path = path:gsub("/", ".")
	if not path:match("^game%.") then
		path = "game." .. path
	end
	return path
end

-- Validate required fields based on operation_type
local function isValidTask(task)
	if typeof(task) ~= "table" then return false, "Task is not a table." end
	if not task.operation_type or typeof(task.operation_type) ~= "string" then
		return false, "Missing or invalid 'operation_type'."
	end

	local op = task.operation_type
	local required = {
		CREATE_INSTANCE = { "target_path", "item_name", "payload" },
		CREATE_SCRIPT = { "target_path", "item_name", "payload" },
		UPDATE_INSTANCE = { "target_path", "payload" },
		UPDATE_SCRIPT = { "target_path", "payload" },
		REMOVE_ITEM = { "target_path" }
	}

	if not required[op] then
		return false, "Unsupported operation_type: " .. tostring(op)
	end

	-- NEW: Validate target_path for CREATE operations
	if (op == "CREATE_INSTANCE" or op == "CREATE_SCRIPT") then
		if task.target_path == "game" then
			return false, "Cannot create directly under 'game' - specify a child container"
		end

		-- Check for valid containers
		local validContainers = {
			["game.Workspace"] = true,
			["game.ServerScriptService"] = true,
			["game.ServerStorage"] = true,
			["game.ReplicatedStorage"] = true,
			["game.StarterPlayer"] = true,
			["game.StarterPlayer.StarterPlayerScripts"] = true,
			["game.StarterPlayer.StarterCharacterScripts"] = true,
			["game.StarterGui"] = true,
			["game.StarterPack"] = true
		}

		if not validContainers[task.target_path] then
			return false, "Invalid container path: "..task.target_path..". Must be a valid Roblox container"
		end
	end

	for _, field in ipairs(required[op]) do
		if task[field] == nil then
			return false, "Missing required field '" .. field .. "' for operation '" .. op .. "'"
		end
	end

	return true
end

-- Attempt to extract JSON from potentially malformed response
local function extractJSON(response)
	-- First try to parse as direct JSON
	local success, decoded = pcall(HttpService.JSONDecode, HttpService, response)
	if success then return decoded end

	-- Clean the response by removing markdown code blocks
	local cleaned = response:gsub("^```json\n", ""):gsub("\n```$", ""):gsub("^```", ""):gsub("```$", "")

	-- Try to find a JSON array in the cleaned response
	local jsonArray = cleaned:match("%[.*%]")
	if jsonArray then
		success, decoded = pcall(HttpService.JSONDecode, HttpService, jsonArray)
		if success then return decoded end
	end

	-- Try to parse the entire cleaned response
	success, decoded = pcall(HttpService.JSONDecode, HttpService, cleaned)
	if success then return decoded end

	-- Final fallback - look for any JSON-like structure
	local anyJson = cleaned:match("[%[%{].*[%]%}]")
	if anyJson then
		success, decoded = pcall(HttpService.JSONDecode, HttpService, anyJson)
		if success then return decoded end
	end

	return nil, "Failed to extract JSON from response"
end

function TaskParser.parseTasks(aiResponse)
	if typeof(aiResponse) ~= "string" then
		warn("TaskParser: AI response must be a string.")
		return {}
	end

	-- Attempt to extract and parse JSON
	local decoded, err = extractJSON(aiResponse)
	if not decoded then
		warn("TaskParser: Failed to parse JSON: " .. tostring(err))
		warn("Raw response that failed to parse: " .. aiResponse:sub(1, 300))
		return {}
	end

	-- Handle nested Gemini API response structure
	if decoded.candidates and decoded.candidates[1] then
		local candidate = decoded.candidates[1]
		if candidate.content and candidate.content.parts and candidate.content.parts[1] then
			local textContent = candidate.content.parts[1].text
			if textContent then
				decoded, err = extractJSON(textContent)
				if not decoded then
					warn("TaskParser: Failed to parse nested JSON: " .. tostring(err))
					return {}
				end
			end
		end
	end

	-- Ensure we have an array of tasks
	if typeof(decoded) ~= "table" or #decoded == 0 then
		if decoded and decoded.tasks and type(decoded.tasks) == "table" then
			decoded = decoded.tasks -- Handle {tasks: [...]} format
		else
			warn("TaskParser: Decoded JSON is not a task array.")
			return {}
		end
	end

	local parsedTasks = {}

	for i, task in ipairs(decoded) do
		-- Normalize the path for consistency
		if task.target_path then
			task.target_path = normalizePath(task.target_path)
		end

		-- NEW: Better task naming to avoid "Unnamed Task"
		if not task.task_id then
			task.task_id = "task_" .. tostring(i)
		end
		if not task.description then
			task.description = task.operation_type .. " operation on " .. (task.target_path or "unknown")
		end
		if not task.item_name then
			task.item_name = "UnnamedItem_" .. tostring(i)
		end

		local isValid, validationErr = isValidTask(task)
		if isValid then
			table.insert(parsedTasks, task)
		else
			warn("TaskParser: Invalid task '" .. tostring(task.task_id) .. "'. Error: " .. validationErr)
		end
	end

	if #parsedTasks == 0 then
		warn("TaskParser: No valid tasks were parsed. Original response: " .. aiResponse:sub(1, 300))
	end

	return parsedTasks
end

return TaskParser
