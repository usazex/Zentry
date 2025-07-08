-- Zentry/Modules/GeminiAPI.lua
local GeminiAPI = {}
local HttpService = game:GetService("HttpService")

GeminiAPI.API_KEY = "" -- Set externally via setAPIKey()
GeminiAPI.API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key="
local MAX_FILE_STRUCTURE_LENGTH = 2000

-- Set the API key, validating input
function GeminiAPI.setAPIKey(apiKey)
	if type(apiKey) == "string" and apiKey ~= "" then
		GeminiAPI.API_KEY = apiKey
		print("GeminiAPI: API Key set.")
	else
		warn("GeminiAPI: Invalid API Key provided.")
	end
end

-- Build the prompt sent to the AI, instructing it how to behave clearly and precisely
function GeminiAPI.buildPrompt(userPromptText, gameFileStructure)
	local fileStructureJSON = HttpService:JSONEncode(gameFileStructure)
	if #fileStructureJSON > MAX_FILE_STRUCTURE_LENGTH then
		fileStructureJSON = fileStructureJSON:sub(1, MAX_FILE_STRUCTURE_LENGTH) .. "... (truncated)"
	end

	-- Super clear instructions for AI:
	-- - Use container path in 'target_path' for CREATE tasks
	-- - Put new item name separately in 'item_name'
	-- - Only output a JSON array, no explanation, no markdown
	-- - Use exact Lua path starting with 'game.'
	-- - Allowed operation_types listed
	-- - Each task has payload depending on operation_type
	-- - Return JSON array only
	local prompt = [[
You are an advanced Roblox AI development agent.

Your task: Given the user's request and the current game file structure, generate a JSON array of task objects that perform the needed changes to the game.

Important instructions:
- For CREATE_INSTANCE or CREATE_SCRIPT tasks:
  - Use the parent container's full path (must start with 'game.') as "target_path".
  - Provide the new instance or script name separately as "item_name".
  - Do NOT include the new item's name in "target_path".
- For UPDATE or REMOVE tasks:
  - Use the exact full Lua-style path to the target instance or script as "target_path".
- Use only these operation types:
  CREATE_INSTANCE, CREATE_SCRIPT, UPDATE_INSTANCE, UPDATE_SCRIPT, REMOVE_ITEM.
- Every task must match the JSON format shown below exactly.
- Return ONLY a JSON array, with no extra text, explanation, or markdown.
- Before creating new items, check if they already exist in the file structure
- If an item exists, use UPDATE_SCRIPT instead of CREATE_SCRIPT
- When creating player-related scripts:
  - Client-side interactions (like click detection) should use LocalScripts in StarterPlayerScripts
  - Server-side coin handling should use Scripts in ServerScriptService
  - Use RemoteEvents for client-server communication
---

Current game file structure (truncated if too long):
]] .. fileStructureJSON .. [[

---

User request:
]] .. userPromptText .. [[

---

JSON task object format (for each task):

{
  "task_id": "task_001",
  "operation_type": "CREATE_SCRIPT | CREATE_INSTANCE | UPDATE_SCRIPT | UPDATE_INSTANCE | REMOVE_ITEM",
  "target_path": "game.ServerScriptService", 
  "item_name": "MyScript",
  "description": "Short description of the task purpose.",
  "payload": {
    // CREATE_INSTANCE example:
    // "instance_class": "Part",
    // "properties": { "Name": "MyPart", "Size": "Vector3.new(5,1,5)", "Anchored": "true" }
    
    // CREATE_SCRIPT example:
    // "script_type": "Script | LocalScript | ModuleScript",
    // "source_code": "print('Hello world')",
    // "properties": { "Name": "MyScript", "Disabled": "false" }
    
    // UPDATE_INSTANCE example:
    // "properties_to_change": { "Size": "Vector3.new(10,2,10)" }
    
    // UPDATE_SCRIPT example:
    // "new_source_code": "print('Updated!')",
    // "update_strategy": "REPLACE_CONTENT"
    
    // REMOVE_ITEM example:
    // {}
  },
  "reasoning": "Explain why this task is needed given the user request and current file structure."
}

Return ONLY the JSON array of task objects.
]]

	return prompt
end

-- Send the prompt to Gemini API, handle request and parse response
function GeminiAPI.sendRequest(promptText)
	local apiKey = GeminiAPI.API_KEY
	if apiKey == "" then
		return nil, "GeminiAPI error: API Key not set. Please set it with setAPIKey()."
	end

	local fullApiUrl = GeminiAPI.API_URL .. apiKey

	local requestBody = {
		contents = {
			{
				role = "user",
				parts = {
					{ text = promptText }
				}
			}
		},
		generationConfig = {
			response_mime_type = "text/plain"
		}
	}

	local encodedBody = HttpService:JSONEncode(requestBody)

	local success, response = pcall(function()
		return HttpService:PostAsync(fullApiUrl, encodedBody, Enum.HttpContentType.ApplicationJson)
	end)

	if not success then
		return nil, "GeminiAPI HTTP request failed: " .. tostring(response)
	end

	-- Attempt to parse JSON from response
	local decodeSuccess, decoded = pcall(function()
		return HttpService:JSONDecode(response)
	end)

	if decodeSuccess and decoded then
		-- Check for the nested response structure
		if decoded.candidates and decoded.candidates[1] then
			local candidate = decoded.candidates[1]
			if candidate.content and candidate.content.parts and candidate.content.parts[1] then
				local textContent = candidate.content.parts[1].text
				if textContent then
					-- Try to extract just the JSON array if it's wrapped in markdown
					local jsonArray = textContent:match("%[.*%]")
					return jsonArray or textContent, nil
				end
			end
		end

		-- Fallback: return the entire decoded response if it's an array
		if type(decoded) == "table" and #decoded > 0 then
			return HttpService:JSONEncode(decoded), nil
		end
	end

	return nil, "GeminiAPI error: Unexpected response format. Raw response: " .. response:sub(1, 300)
end

return GeminiAPI
