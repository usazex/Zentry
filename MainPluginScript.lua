-- Zentry/MainPluginScript.lua

-- Services
local HttpService = game:GetService("HttpService") -- Keep if any JSON operations remain here, or for modules
local UserInputService = game:GetService("UserInputService")
-- Selection, Workspace, etc. will be used by modules directly or passed if necessary

-- Main Plugin Objects
local toolbar = plugin:CreateToolbar("AI Vibe Coder (Zentry)")
local pluginButton = toolbar:CreateButton("Open AI Vibe", "Open AI Vibe Coding Plugin", "rbxassetid://75157895955061") -- Using a generic icon

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	true,   -- Initial enabled
	false,  -- Override enabled
	420,    -- Default width
	650,    -- Default height
	320,    -- Min width
	420     -- Min height
)
local pluginWidget = plugin:CreateDockWidgetPluginGui("AIVibeCodingWidget_Zentry", widgetInfo)
pluginWidget.Title = "AI Vibe Coder (Zentry)"

-- Require Modules
-- Assuming modules are in a subfolder named "Modules" relative to this script's location
local ModulesFolder = script.Parent -- Or define path if different

local UI = require(script.Parent.UI)
local GeminiAPI = require(script.Parent.GeminiAPI)
local FileScanner = require(script.Parent.FileScanner)
local TaskParser = require(script.Parent.TaskParser)
local TaskApplier = require(script.Parent.TaskApplier)


-- Create the UI and get references to key elements
local uiElements = UI.createLayout(pluginWidget)
print("AI Vibe Coder (Zentry): UI layout created - ", uiElements ~= nil)
-- uiElements should contain .inputBox, .sendButton, .chatFrame, etc.

-- Core 'onSend' logic
local function onSend()
	local promptText = uiElements.inputBox.Text
	if promptText == "" then
		return
	end

	UI.addBubble(promptText, true, nil) -- Let addBubble handle user type styling
	uiElements.inputBox.Text = ""

	local thinkingBubble = UI.addBubble("Thinking...", false, "thinking")

	-- Fetch file structure
	local gameFileStructure = FileScanner.getGameFileStructure()
	print("AI Vibe Coder (Zentry): GameFileStructure fetched. Truncated sample: ", HttpService:JSONEncode(gameFileStructure):sub(1, 200)) -- Print a sample

	-- Build prompt for Gemini
	local geminiRequestPrompt = GeminiAPI.buildPrompt(promptText, gameFileStructure)
	-- It's good practice not to print the full Gemini prompt if it's very large or contains sensitive structure details repeatedly.
	-- We can assume buildPrompt works if fileStructure and promptText are okay.
	print("AI Vibe Coder (Zentry): Gemini request prompt built.")

	-- Send to Gemini
	local responseText, err = GeminiAPI.sendRequest(geminiRequestPrompt)
	print("AI Vibe Coder (Zentry): Raw AI Response Text: '", responseText, "' Error (if any):", err) -- CRITICAL PRINT

	if thinkingBubble and thinkingBubble.Parent then thinkingBubble:Destroy() end

	if not responseText then
		UI.addBubble("Error communicating with AI: " .. (err or "Unknown error"), false, "error")
		return
	end

	local tasks = TaskParser.parseTasks(responseText)
	-- print("AI Vibe Coder (Zentry): Tasks parsed. Count: ", #tasks) -- Optional: keep for detailed debugging

	if #tasks == 0 then
		local maxResponseLengthInBubble = 200 -- Max characters of raw response to show in bubble
		local truncatedResponse = responseText
		if responseText and #responseText > maxResponseLengthInBubble then
			truncatedResponse = responseText:sub(1, maxResponseLengthInBubble) .. "... (see console for full AI response)"
		elseif not responseText then
			truncatedResponse = "(empty or nil response from AI)"
		end
		UI.addBubble("No actionable tasks found in AI response. Raw AI output: '" .. truncatedResponse .. "'", false, "warning")
		print("AI Vibe Coder (Zentry): Task parsing resulted in 0 tasks. Full AI response was: ", responseText or "(empty or nil response)")
		return
	end

	for i, taskData in ipairs(tasks) do
		-- For each task, create a card. The 'Apply' button on the card needs a callback.
		UI.createTaskCard(taskData, i, function(selectedTaskData, applyButtonInstance)
			-- This callback is executed when an "Apply" button on a task card is clicked
			local success, message = TaskApplier.applyTask(selectedTaskData)
			if success then
				applyButtonInstance.Text = "Applied ✔️"
				applyButtonInstance.BackgroundColor3 = Color3.fromRGB(80,80,80)
				applyButtonInstance.TextColor3 = UI.SUBTLE_TEXT_COLOR or Color3.fromRGB(150,150,150) -- Access color from UI module
				applyButtonInstance.Active = false
				UI.addBubble("Task '" .. (selectedTaskData.name or "Unnamed") .. "': " .. message, false, "success")
			else
				applyButtonInstance.BackgroundColor3 = UI.ERROR_COLOR or Color3.fromRGB(255,59,48)
				applyButtonInstance.Text = "Failed ❌"
				UI.addBubble("Task '" .. (selectedTaskData.name or "Unnamed") .. "' failed: " .. message, false, "error")
			end
		end)
	end
end

-- Connect Send Button
if uiElements.sendButton then
	uiElements.sendButton.MouseButton1Click:Connect(onSend)
else
	warn("AI Vibe Coder: Send Button not found in UI elements after UI creation.")
end

-- Handle Enter Key Submission for InputBox
if uiElements.inputBox then
	local inputBeganConnection
	uiElements.inputBox.Focused:Connect(function()
		if inputBeganConnection then inputBeganConnection:Disconnect() end
		inputBeganConnection = UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
			if not uiElements.inputBox:IsFocused() then return end
			if input.KeyCode == Enum.KeyCode.Return then
				if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
					return -- Allow newline for Shift+Enter
				else
					-- Enter alone: Submit
					-- Setting gameProcessedEvent = true should prevent the newline.
					-- However, for TextBoxes, the event might fire after the newline is already processed by the TextBox.
					-- A common workaround is to call Send and then clear/reset text if needed.
					-- For now, rely on gameProcessedEvent and the fact that onSend clears the input.
					-- gameProcessedEvent = true -- This doesn't work as expected here to prevent newline
					onSend()
					-- To truly prevent newline, one might need to capture text, set to "", then process.
					-- But onSend() already clears it. The visual blip of a newline appearing briefly might occur.
				end
			end
		end)
	end)
	uiElements.inputBox.FocusLost:Connect(function()
		if inputBeganConnection then
			inputBeganConnection:Disconnect()
			inputBeganConnection = nil
		end
	end)
else
	warn("AI Vibe Coder: InputBox not found in UI elements after UI creation.")
end

-- Toggle plugin widget visibility
pluginButton.Click:Connect(function()
	pluginWidget.Enabled = not pluginWidget.Enabled
end)

-- Initial state
pluginWidget.Enabled = false

print("AI Vibe Coder (Zentry) Loaded. Modules required. UI Created.")
