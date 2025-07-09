-- AgentExecutor.lua
local AgentExecutor = {}

-- Required Modules (ensure these are correctly pathed in MainPluginScript)
local FileScanner = require(script.Parent.FileScanner)
local GeminiAPI = require(script.Parent.GeminiAPI)
local TaskParser = require(script.Parent.TaskParser)
local TaskApplier = require(script.Parent.TaskApplier)
local UI = require(script.Parent.UI) -- To provide feedback

local HttpService = game:GetService("HttpService") -- For debugging gameFileStructure

function AgentExecutor.executePrompt(userPromptText)
	-- 1. Add "Thinking..." bubble
	local thinkingBubble = UI.addBubble("🧠 AI Agent is thinking...", false, "thinking")

	-- 2. Scan game files
	UI.addBubble("🔍 Scanning game files...", false, nil)
	local gameFileStructure = FileScanner.getGameFileStructure()
	-- For debugging, print a small part of the structure
	-- print("AgentExecutor: GameFileStructure (sample): ", HttpService:JSONEncode(gameFileStructure):sub(1, 200))
	UI.addBubble("✅ Game files scanned.", false, "success")

	-- 3. Build prompt for AI
	UI.addBubble("📝 Preparing request for AI...", false, nil)
	local geminiRequestPrompt = GeminiAPI.buildPrompt(userPromptText, gameFileStructure)
	-- print("AgentExecutor: Gemini Request Prompt built.") -- Can be very long

	-- 4. Send request to AI and get tasks (blueprint)
	UI.addBubble("💬 Sending request to AI...", false, nil)
	local responseText, err = GeminiAPI.sendRequest(geminiRequestPrompt)

	-- Remove "Thinking..." bubble once response is received or error occurs
	if thinkingBubble and thinkingBubble.Parent then
		thinkingBubble:Destroy()
	end

	if not responseText then
		UI.addBubble("❌ Error communicating with AI: " .. (err or "Unknown error"), false, "error")
		return
	end
	-- print("AgentExecutor: Raw AI Response: ", responseText) -- For debugging

	UI.addBubble("📄 AI response received, parsing tasks...", false, nil)
	local tasks = TaskParser.parseTasks(responseText)

	if #tasks == 0 then
		local maxResponseLengthInBubble = 250
		local truncatedResponse = responseText
		if responseText and #responseText > maxResponseLengthInBubble then
			truncatedResponse = responseText:sub(1, maxResponseLengthInBubble) .. "... (see console for full AI response)"
		elseif not responseText then
			truncatedResponse = "(empty or nil response from AI)"
		end
		UI.addBubble("⚠️ No actionable tasks found in AI response. AI Output: '" .. truncatedResponse .. "'", false, "warning")
		print("AgentExecutor: Task parsing resulted in 0 tasks. Full AI response was: ", responseText or "(empty or nil response)")
		return
	end

	UI.addBubble("✅ Blueprint of " .. #tasks .. " tasks received. Starting execution...", false, "success")

	-- 5. Iteratively apply tasks
	for i, taskData in ipairs(tasks) do
		UI.addBubble("👉 Executing Task " .. i .. "/" .. #tasks .. ": " .. (taskData.name or "Unnamed Task"), false, nil)

		-- Display task details using a card (optional, could also just be bubbles)
		-- UI.createTaskCard(taskData, i, function() end) -- Non-interactive card, just for display
		-- For now, sticking to bubbles for simplicity of flow in AgentExecutor.
		-- The MainPluginScript previously created interactive cards. This is a different approach.

		local success, message = TaskApplier.applyTask(taskData)

		if success then
			UI.addBubble("✔️ Task " .. i .. " ('" .. (taskData.name or "Unnamed") .. "') applied: " .. message, false, "success")
		else
			UI.addBubble("❌ Task " .. i .. " ('" .. (taskData.name or "Unnamed") .. "') failed: " .. message, false, "error")
		end

		-- Add a small delay between tasks if needed, e.g., task.wait(0.5)
	end

	UI.addBubble("🎉 All tasks processed.", false, "success")
end

return AgentExecutor
