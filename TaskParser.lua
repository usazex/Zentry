-- TaskParser.lua Module Script
local TaskParser = {}
local HttpService = game:GetService("HttpService")

local VALID_OPERATION_TYPES = {
	CREATE_INSTANCE = true,
	CREATE_SCRIPT = true,
	UPDATE_INSTANCE = true,
	UPDATE_SCRIPT = true,
	REMOVE_ITEM = true
}

local VALID_SCRIPT_TYPES = {
	Script = true,
	LocalScript = true,
	ModuleScript = true
}

-- Extracts the primary JSON array/object from the AI's response string.
function TaskParser.extractJsonString(responseText)
	if not responseText or responseText:gsub("%s", "") == "" then
		return nil, "Response text is nil or empty"
	end

	-- Common markdown encapsulations
	local patterns = {
		"```json\n(.-)\n```", -- Standard markdown json block
		"```json\n(.-)```",   -- Sometimes missing final newline
		"```(.-)```",         -- Generic markdown block
		"%[.-%]",             -- Raw array
		"%{.-%}"              -- Raw object
	}

	local jsonString
	for _, pattern in ipairs(patterns) do
		local s, e, captured = responseText:find(pattern)
		if captured then
			jsonString = captured
			break
		elseif s and e and not captured then -- For patterns like %[.-%]
			jsonString = responseText:sub(s,e)
			break
		end
	end

	if not jsonString then
        -- If no pattern matched, assume the whole response might be the JSON
        -- but only if it looks like it starts and ends with array/object brackets
        local trimmedResponse = responseText:match("^%s*(.-)%s*$")
        if (trimmedResponse:sub(1,1) == "[" and trimmedResponse:sub(-1,-1) == "]") or
           (trimmedResponse:sub(1,1) == "{" and trimmedResponse:sub(-1,-1) == "}") then
            jsonString = trimmedResponse
        else
            return nil, "No clear JSON array or object found in response. Raw response (first 100 chars): " .. responseText:sub(1, math.min(100, #responseText))
        end
	end

    if jsonString == "" then
        return nil, "Extracted JSON string is empty."
    end

	return jsonString:match("^%s*(.-)%s*$") -- Trim whitespace again
end


function TaskParser.parseTasks(responseText)
	local tasks = {}
	local jsonString, extractErr = TaskParser.extractJsonString(responseText)

	if not jsonString then
		warn("TaskParser: Could not extract JSON string. " .. (extractErr or ""))
		return tasks
	end

	local success, decodedResponse = pcall(HttpService.JSONDecode, HttpService, jsonString)

	if not success then
		warn("TaskParser: Failed to decode JSON. Error: " .. tostring(decodedResponse) .. ". Extracted JSON string (first 300 chars): " .. jsonString:sub(1, math.min(300, #jsonString)))
		return tasks
	end

	if type(decodedResponse) ~= "table" then
		warn("TaskParser: Decoded JSON is not a table. Type: " .. type(decodedResponse))
		return tasks
	end

	local taskList = decodedResponse
	-- If AI returns a single task object instead of an array of one.
	if not decodedResponse[1] and decodedResponse.task_id then
		taskList = {decodedResponse}
	end

	if type(taskList) ~= "table" or (taskList[1] == nil and next(taskList) ~= nil and taskList.task_id == nil) then
		warn("TaskParser: Expected a JSON array of tasks or a single task object. Got: " .. type(taskList))
		return tasks
	end


	for i, rawTaskData in ipairs(taskList) do
		if type(rawTaskData) ~= "table" then
			warn("TaskParser: Task data at index " .. i .. " is not a table. Skipping. Data: " .. tostring(rawTaskData))
			continue
		end

		local task = {}
		local isValidTask = true
		local errors = {}

		-- Mandatory fields
		task.task_id = rawTaskData.task_id
		if not (task.task_id and type(task.task_id) == "string" and task.task_id ~= "") then
			table.insert(errors, "Missing or invalid 'task_id' (string, non-empty)")
			isValidTask = false
		end

		task.operation_type = rawTaskData.operation_type
		if not (task.operation_type and type(task.operation_type) == "string" and VALID_OPERATION_TYPES[task.operation_type]) then
			table.insert(errors, "Missing or invalid 'operation_type' (must be one of: " .. table.concat(table.keys(VALID_OPERATION_TYPES), ", ") .. ")")
			isValidTask = false
		end

		task.target_path = rawTaskData.target_path
		if not (task.target_path and type(task.target_path) == "string" and task.target_path:match("^game%.%w")) then
			table.insert(errors, "Missing or invalid 'target_path' (string, starting with 'game.')")
			isValidTask = false
		end

		task.item_name = rawTaskData.item_name
		if not (task.item_name and type(task.item_name) == "string" and task.item_name ~= "") then
			if task.operation_type and (task.operation_type == "CREATE_INSTANCE" or task.operation_type == "CREATE_SCRIPT") then
				table.insert(errors, "Missing or invalid 'item_name' (string, non-empty, required for CREATE)")
				isValidTask = false
			else
				task.item_name = task.target_path:match("([^%.]+)$") or "UnnamedItem" -- Fallback for non-create if missing
                warn("TaskParser: Task "..(task.task_id or "N/A").." missing item_name for non-CREATE op. Inferred as: "..task.item_name)
			end
		end

		task.description = rawTaskData.description or "No description provided."
		task.reasoning = rawTaskData.reasoning or "No reasoning provided."

		-- Payload validation
		task.payload = rawTaskData.payload
		if not (task.payload and type(task.payload) == "table") then
			if task.operation_type == "REMOVE_ITEM" and (task.payload == nil or (type(task.payload) == "table" and next(task.payload) == nil)) then
				task.payload = {} -- Ensure it's an empty table for REMOVE_ITEM
			else
				table.insert(errors, "Missing or invalid 'payload' (must be a table)")
				isValidTask = false
			end
		end

		if isValidTask and task.payload then
			local opType = task.operation_type -- Use validated operation_type
			if opType == "CREATE_INSTANCE" then
				if not (task.payload.instance_class and type(task.payload.instance_class) == "string") then table.insert(errors, "CREATE_INSTANCE: missing/invalid 'payload.instance_class'") isValidTask = false end
				if not (task.payload.properties and type(task.payload.properties) == "table") then table.insert(errors, "CREATE_INSTANCE: missing/invalid 'payload.properties' table") isValidTask = false end
				if isValidTask and task.payload.properties and task.payload.properties.Name ~= task.item_name then
					warn("TaskParser: CREATE_INSTANCE task '"..(task.task_id).."' payload.properties.Name ('"..tostring(task.payload.properties.Name).."') should match item_name ('"..tostring(task.item_name).."').")
                    -- Enforce item_name if properties.Name is missing, or prioritize item_name.
                    if task.payload.properties.Name == nil then task.payload.properties.Name = task.item_name end
				end
			elseif opType == "CREATE_SCRIPT" then
				if not (task.payload.script_type and type(task.payload.script_type) == "string" and VALID_SCRIPT_TYPES[task.payload.script_type]) then table.insert(errors, "CREATE_SCRIPT: missing/invalid 'payload.script_type'") isValidTask = false end
				if not (type(task.payload.source_code) == "string") then table.insert(errors, "CREATE_SCRIPT: missing/invalid 'payload.source_code' (string)") isValidTask = false end
				if task.payload.properties == nil then task.payload.properties = {} end -- Ensure properties table exists
				if type(task.payload.properties) ~= "table" then table.insert(errors, "CREATE_SCRIPT: 'payload.properties' must be a table if provided") isValidTask = false end
                if isValidTask and task.payload.properties.Name ~= task.item_name then
                     warn("TaskParser: CREATE_SCRIPT task '"..(task.task_id).."' payload.properties.Name ('"..tostring(task.payload.properties.Name).."') should match item_name ('"..tostring(task.item_name).."').")
                    if task.payload.properties.Name == nil then task.payload.properties.Name = task.item_name end
                end
			elseif opType == "UPDATE_INSTANCE" then
				if not (task.payload.properties_to_change and type(task.payload.properties_to_change) == "table" and next(task.payload.properties_to_change) ~= nil) then table.insert(errors, "UPDATE_INSTANCE: missing/invalid 'payload.properties_to_change' (non-empty table)") isValidTask = false end
			elseif opType == "UPDATE_SCRIPT" then
				if not (type(task.payload.new_source_code) == "string") then table.insert(errors, "UPDATE_SCRIPT: missing/invalid 'payload.new_source_code' (string)") isValidTask = false end
				if task.payload.update_strategy ~= "REPLACE_CONTENT" then table.insert(errors, "UPDATE_SCRIPT: 'payload.update_strategy' must be 'REPLACE_CONTENT'") isValidTask = false end
			elseif opType == "REMOVE_ITEM" then
				if next(task.payload) ~= nil then
                    warn("TaskParser: REMOVE_ITEM task '"..(task.task_id).."' has unexpected fields in payload. Payload should be empty. Forcing empty.")
                    task.payload = {}
                end
			end
		end

		if isValidTask then
			table.insert(tasks, task)
		else
			warn("TaskParser: Invalid task data for task_id '" .. tostring(rawTaskData.task_id or "UNKNOWN") .. "'. Errors: " .. table.concat(errors, "; ") .. ". Raw data sample: " .. HttpService:JSONEncode(rawTaskData):sub(1,200))
		end
	end

	if #tasks == 0 and (#taskList > 0 or (type(taskList) == "table" and next(taskList) ~= nil and taskList.task_id ~= nil)) then
		warn("TaskParser: Decoded JSON was not empty, but no valid tasks were parsed according to the new structure. Check AI output. Input JSON (first 300 chars): " .. jsonString:sub(1, math.min(300, #jsonString)))
	elseif #tasks > 0 then
		print("TaskParser: Successfully parsed " .. #tasks .. " tasks using new structure.")
	end

	return tasks
end

return TaskParser
