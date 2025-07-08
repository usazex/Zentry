-- GeminiAPI.lua  Module script
local GeminiAPI = {}

local HttpService = game:GetService("HttpService")

GeminiAPI.API_KEY = "" -- Will be set by MainPluginScript
GeminiAPI.API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key="
-- Key will be appended later

local MAX_FILE_STRUCTURE_LENGTH = 2000 -- Max length for file structure JSON in prompt

function GeminiAPI.setAPIKey(apiKey)
	if type(apiKey) == "string" then
		GeminiAPI.API_KEY = apiKey
		print("GeminiAPI: API Key set.")
	else
		warn("GeminiAPI: Invalid API Key provided.")
	end
end

function GeminiAPI.buildPrompt(userPromptText, gameFileStructure)
	local fileStructureJSON = HttpService:JSONEncode(gameFileStructure)

	if #fileStructureJSON > MAX_FILE_STRUCTURE_LENGTH then
		fileStructureJSON = fileStructureJSON:sub(1, MAX_FILE_STRUCTURE_LENGTH) .. "... (truncated)"
	end

	-- The prompt structure remains the same as defined before
	return [[
You are an advanced Roblox development AI assistant.
Your primary task is to meticulously analyze user requests and the provided game file structure to generate a precise plan of action (a blueprint).
This blueprint will consist of a series of tasks to modify the game. You will then immediately provide the full implementation details for each task.

**Critical Analysis Directives:**
1.  **Analyze File Structure:** Carefully examine the `Current Game File Structure` provided. This is your primary source of truth for what currently exists in the game.
2.  **Determine Operation:** For each part of the user's request, decide if it requires CREATING a new item, UPDATING an existing item, or REMOVING an item.
    *   **CREATE:** If the user asks to add something that does *not* exist at the specified path.
    *   **UPDATE:** If the user asks to modify something that *already exists* at the specified path. This includes changing script content or instance properties.
    *   **REMOVE:** If the user asks to delete something that *exists* at the specified path.
3.  **Verify Existence for Updates/Deletes:** Before generating an UPDATE or REMOVE task, ENSURE the target item exists in the `Current Game File Structure`. If it doesn't, and the user implies it should, you may need to create it first if logical, or point out the discrepancy.
4.  **Path Precision:** Be exact with all paths (`target_path`). An item's `target_path` is its full path including its own name (e.g., `Workspace.MyPart`, `ServerScriptService.MyScript`). For CREATE operations, `target_path` refers to the intended full path of the new item.
5.  **Blueprint First, Then Details:** Internally, first formulate a step-by-step blueprint. Then, for each step in your blueprint, generate the corresponding JSON task object with all necessary details (code, properties, etc.) as specified below. The final output should be a single JSON array of these detailed task objects.

Current Game File Structure (JSON format, truncated if too large):
]] .. fileStructureJSON .. [[

User request: ]] .. userPromptText .. [[

**Output Format:**
Respond ONLY with a single JSON array of task objects. Each object must conform to the **strict** structure defined below:

**Detailed JSON Task Object Structure:**
```json
{
  "task_id": "string", // Unique identifier for the task (e.g., "task_001").
  "operation_type": "CREATE_INSTANCE | CREATE_SCRIPT | UPDATE_INSTANCE | UPDATE_SCRIPT | REMOVE_ITEM",
  "target_path": "string", // Full Lua path to the item (e.g., "game.Workspace.Entities.MyPart" or "game.ServerScriptService.MyScript"). For CREATE operations, this is the intended full path of the new item. Path must start with 'game.' followed by service (Workspace, ReplicatedStorage, ServerScriptService, etc.).
  "item_name": "string", // Name of the instance/script. For CREATE, this is the name to assign. For UPDATE/REMOVE, this is informational.
  "description": "string", // Concise explanation of what the task achieves and a brief justification for the operation_type chosen.
  "payload": {
    // Payload structure varies based on operation_type. Include ONLY relevant fields for the operation.
    // For CREATE_INSTANCE:
    //   "instance_class": "string", // ClassName (e.g., "Part", "Folder", "RemoteEvent").
    //   "properties": {"Name": "string_literal", "OtherProp": "valid_lua_expression_string"}, // .Name property is mandatory and must match item_name.
    // For CREATE_SCRIPT:
    //   "script_type": "Script | LocalScript | ModuleScript", // Specify the script's class.
    //   "source_code": "string", // The full Lua source code.
    //   "properties": {"Name": "string_literal", "Disabled": "boolean_literal"}, // .Name property is mandatory and must match item_name. Other script properties like Disabled can be included.
    // For UPDATE_INSTANCE:
    //   "properties_to_change": {"PropertyNameToChange": "new_valid_lua_expression_string"}, // Properties to set on the existing instance.
    // For UPDATE_SCRIPT:
    //   "new_source_code": "string", // The complete new Lua source code.
    //   "update_strategy": "REPLACE_CONTENT", // Currently, this is the only supported strategy.
    // For REMOVE_ITEM:
    //   // No payload needed. target_path is sufficient. Ensure payload is an empty object: {}
  },
  "reasoning": "string" // Brief explanation of why this task is necessary and how it addresses the user's request, referencing the file structure analysis.
}
```

**Key Instructions for JSON Generation:**
-   **`target_path`**: Must be a full Lua-style path starting with `game.` (e.g., `game.Workspace.MyPart`, `game.ServerScriptService.MyModule`).
-   **`item_name`**: For `CREATE` operations, this name *must* be used for the `Name` property within `payload.properties`.
-   **`operation_type`**: Must be one of the specified enums. Your analysis (CREATE, UPDATE, REMOVE) directly maps to these.
-   **`payload`**: Only include fields relevant to the `operation_type`. For example, `UPDATE_SCRIPT` should not have `instance_class`. If an operation type has no specific payload fields (e.g. `REMOVE_ITEM`), provide an empty object `{}` for the payload.
-   **Lua Expressions**: Property values in `properties` or `properties_to_change` must be valid Lua expressions provided as strings (e.g., `"Vector3.new(0,10,0)"`, `"Color3.fromRGB(255,0,0)"`, `"true"`). String literals within these expressions need to be correctly escaped if the expression itself is a string (e.g., `Properties: {"Name": "\"Special Part\""}`). However, for the `Name` property specifically, it's generally better to provide it as a direct string if it's just a name.

**Example Scenario (Conceptual using new structure):**
If `game.ServerScriptService.MyScript` exists, and user says "change MyScript to print 'hello world'":
```json
{
  "task_id": "task_001",
  "operation_type": "UPDATE_SCRIPT",
  "target_path": "game.ServerScriptService.MyScript",
  "item_name": "MyScript",
  "description": "Updates MyScript to print 'hello world' as requested, script found in file structure.",
  "payload": {
    "new_source_code": "print('hello world')",
    "update_strategy": "REPLACE_CONTENT"
  },
  "reasoning": "User requested a change to an existing script. MyScript exists at the specified path."
}
```
If `game.ServerScriptService.AnotherScript` does NOT exist, and user says "create AnotherScript that prints 'test'":
```json
{
  "task_id": "task_002",
  "operation_type": "CREATE_SCRIPT",
  "target_path": "game.ServerScriptService.AnotherScript",
  "item_name": "AnotherScript",
  "description": "Creates a new script AnotherScript to print 'test' as it does not exist.",
  "payload": {
    "script_type": "Script",
    "source_code": "print('test')",
    "properties": {"Name": "AnotherScript"}
  },
  "reasoning": "User requested a new script. AnotherScript does not exist at the specified path."
}
```

Based on the user's request and the provided file structure, generate a JSON array of task objects conforming to this detailed structure.
The AI's ability to correctly map its analysis (CREATE, UPDATE, REMOVE) to the `operation_type` and provide the correct `payload` is CRITICAL.

Respond ONLY with a JSON array of task objects. Example (using NEW structure):
[
  {
    "task_id": "task_001",
    "description": "Adds a script to increase player walk speed.",
    "action": "add_script",
    "location": "ServerScriptService",
    "instance_type": "Script",
    "code": "game.Players.PlayerAdded:Connect(function(player)\n  player.CharacterAdded:Connect(function(character)\n    local humanoid = character:WaitForChild('Humanoid')\n    humanoid.WalkSpeed = 25\n  end)\nend)"
  },
  {
    "name": "KillBrick",
    "description": "Adds a red part that kills players on touch.",
    "action": "add_instance",
    "location": "Workspace",
    "instance_type": "Part",
    "properties": {
      "Name": "KillBrick",
      "Size": "Vector3.new(10,1,10)",
      "Color": "Color3.fromRGB(255,0,0)",
      "Anchored": true,
      "CanCollide": true
    }
  }
]

User request: ]] .. userPromptText
end

function GeminiAPI.sendRequest(promptText)
	local apiKey = GeminiAPI.API_KEY
	if apiKey == "" then
		return nil, "API Key not set in Zentry/Modules/GeminiAPI.lua. Please replace YOUR_API_KEY_HERE with your actual Gemini API key."
	end

	local fullApiUrl = GeminiAPI.API_URL .. apiKey

	local requestBody = {
		contents = {{
			role = "user",
			parts = {{text = promptText}}
		}},
		generationConfig = {
			response_mime_type = "text/plain" -- Requesting plain text to simplify parsing
		}
	}
	local encodedBody = HttpService:JSONEncode(requestBody)

	local success, responseContent = pcall(function()
		return HttpService:PostAsync(fullApiUrl, encodedBody, Enum.HttpContentType.ApplicationJson)
	end)

	if not success then
		return nil, "HttpService:PostAsync failed: " .. tostring(responseContent) -- responseContent is error msg here
	end

	-- Try to extract text from Gemini's response format
	-- Gemini often wraps its JSON in a larger structure, even when text/plain is requested for the parts.
	local decodedResponse
	local decodeSuccess, decodeResult = pcall(function() return HttpService:JSONDecode(responseContent) end)

	if decodeSuccess and decodeResult then
		if decodeResult.candidates and
			decodeResult.candidates[1] and
			decodeResult.candidates[1].content and
			decodeResult.candidates[1].content.parts and
			decodeResult.candidates[1].content.parts[1] and
			decodeResult.candidates[1].content.parts[1].text then
			return decodeResult.candidates[1].content.parts[1].text, nil
		elseif decodeResult.error then -- Handle cases where Gemini API itself returns an error object
			return nil, "Gemini API Error: " .. (decodeResult.error.message or HttpService:JSONEncode(decodeResult.error))
		end
	end

	-- If direct text extraction fails, but PostAsync succeeded, return the raw responseContent.
	-- It might be plain JSON array, or plain text, or an error message not caught above.
	return responseContent, nil
end

return GeminiAPI
