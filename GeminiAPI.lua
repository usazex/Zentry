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
You are an expert Roblox developer assistant.
Your primary goal is to help the user modify their game by creating, updating, or removing instances and scripts.
You will be provided with the current game's file structure. Use this to understand the existing layout and make informed decisions.

Current Game File Structure (JSON format, truncated if too large):
]] .. fileStructureJSON .. [[

User request: ]] .. userPromptText .. [[

Based on the user's request and the provided file structure, break the request down into a list of clear, atomic tasks.
For each task, provide a JSON object with the following fields:
- name: A short, descriptive name for the task (e.g., "Create HealthScript", "UpdatePlayerSpeed", "RemoveOldPlatform").
- description: A concise explanation of what the task achieves.
- action: One of the following strings:
    - "add_script": To create a new Script, LocalScript, or ModuleScript.
    - "update_script": To modify an existing script. Provide the FULL new script content.
    - "add_instance": To create any other Roblox instance (e.g., Part, Folder, RemoteEvent).
    - "update_instance": To change properties of an existing instance.
    - "remove_instance": To delete an existing instance.
- location: The full path to the parent instance where the action should occur (e.g., "Workspace/Entities", "ServerScriptService", "StarterPlayer/StarterPlayerScripts/Utilities").
           For "update_script" or "update_instance" or "remove_instance", this path should point to the PARENT of the item being modified/removed, and the 'name' field should be the name of the item itself.
- instance_type (for "add_instance" and "add_script"): The ClassName of the instance to add (e.g., "Script", "LocalScript", "ModuleScript", "Part", "Folder").
- properties (for "add_instance" and "update_instance"): A JSON object of properties to set on the instance. Example: {"Size": "Vector3.new(10,1,20)", "Color": "Color3.fromRGB(255,0,0)", "Anchored": true}. Values should be valid Lua expressions for Roblox.
- code (for "add_script" and "update_script"): The FULL Lua code for the script. Do NOT use markdown, provide only the plain code string. If updating, this is the complete new script content.

IMPORTANT:
- For "update_script", "update_instance", or "remove_instance", the 'name' field is crucial and must be the exact name of the script/instance to be modified/deleted within its 'location' (parent).
- When generating code for scripts, ensure it is complete and functional.
- Be precise with locations and names. If a location or item does not exist and you are not adding it, state that as a problem or ask for clarification.

Respond ONLY with a JSON array of task objects. Example:
[
  {
    "name": "PlayerSpeedScript",
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
		return nil, "API Key not set in Zentry, set it in the settings Gemini API key"
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
