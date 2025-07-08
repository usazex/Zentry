-- TaskParser.lua Module script
local TaskParser = {}

local HttpService = game:GetService("HttpService") -- For JSONDecode

-- Robustly extract JSON array from Gemini's response
function TaskParser.parseTasks(responseText)
	if not responseText or responseText == "" then return {} end

	-- Try to find JSON array in response (e.g. ```json [...] ``` or just [...])
	local jsonOnly = responseText
	local _, _, potentialJson = responseText:find("```json\n(.-)\n```")
	if potentialJson then
		jsonOnly = potentialJson
	else
		_, _, potentialJson = responseText:find("```(.-)```") -- More generic code block
		if potentialJson then
			jsonOnly = potentialJson
		end
	end

	-- Trim whitespace that might affect JSON parsing
	jsonOnly = jsonOnly:match("^%s*(.-)%s*$")

	local ok, data = pcall(function() return HttpService:JSONDecode(jsonOnly) end)
	if ok then
		if type(data) == "table" then
			-- If the root is an array, return it directly
			if #data > 0 and type(data[1]) == "table" then -- Check if it's an array of tables
				return data
				-- Sometimes AI might wrap it in a "tasks": [...] object
			elseif data.tasks and type(data.tasks) == "table" then
				return data.tasks
			end
		end
	end

	-- Fallback: if JSON decoding failed or format was unexpected, try to find a raw array string
	local jsonStart, jsonEnd = responseText:find("%[.-%]")
	if jsonStart and jsonEnd then
		local jsonStr = responseText:sub(jsonStart, jsonEnd)
		ok, data = pcall(function() return HttpService:JSONDecode(jsonStr) end)
		if ok and type(data) == "table" then
			return data
		end
	end

	-- If all parsing fails, return empty table
	return {}
end

-- Extract code from task (handles code field, code blocks, or fallback to description)
function TaskParser.extractScriptCode(task)
	if task.code and type(task.code) == "string" and #task.code > 0 then
		local code = task.code
		-- Remove markdown code block if present (e.g. ```lua ... ``` or ``` ... ```)
		code = code:gsub("^%s*```lua\n?", "") -- Handles optional newline after ```lua
		code = code:gsub("\n?```%s*$", "")    -- Handles optional newline before ```
		code = code:gsub("^%s*```\n?", "")    -- Handles generic ``` blocks
		return code:match("^%s*(.-)%s*$") -- Trim whitespace
	end

	-- Try to extract code from description if code field missing (less reliable)
	if task.description and type(task.description) == "string" then
		local _, _, codeFromDesc = task.description:find("```lua\n(.-)\n```")
		if codeFromDesc then return codeFromDesc:match("^%s*(.-)%s*$") end

		_, _, codeFromDesc = task.description:find("```(.-)```")
		if codeFromDesc then return codeFromDesc:match("^%s*(.-)%s*$") end
	end

	-- Fallback: no code found or provided in expected format
	return "-- AI Vibe Coder: No valid code provided in task."
end

return TaskParser
