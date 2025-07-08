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
-- uiElements should contain .inputBox, .sendButton, .chatFrame, .apiKeyInput, .autoApproverToggle etc.

-- Settings Keys
local API_KEY_SETTING = "GeminiApiKey"
local AUTO_APPROVER_SETTING = "AutoApproverEnabled"

-- Function to load settings
local function loadSettings()
	local apiKey = plugin:GetSetting(API_KEY_SETTING)
	if apiKey and uiElements.apiKeyInput then
		uiElements.apiKeyInput.Text = apiKey
		GeminiAPI.setAPIKey(apiKey) -- Set the API key in the module
	end

	local autoApproverEnabled = plugin:GetSetting(AUTO_APPROVER_SETTING)
	if uiElements.autoApproverToggle then
		if autoApproverEnabled == true then -- Explicitly check for true
			uiElements.autoApproverToggle.Text = "ON"
			uiElements.autoApproverToggle.BackgroundColor3 = UI.SUCCESS_COLOR or Color3.fromRGB(52, 199, 89)
		else
			uiElements.autoApproverToggle.Text = "OFF"
			uiElements.autoApproverToggle.BackgroundColor3 = UI.ERROR_COLOR or Color3.fromRGB(255, 59, 48)
		end
	end
	print("AI Vibe Coder (Zentry): Settings loaded. API Key saved:", apiKey ~= nil, "Auto Approver:", autoApproverEnabled)
end

-- Load settings when the plugin starts
loadSettings()

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

	local autoApproverEnabled = plugin:GetSetting(AUTO_APPROVER_SETTING)

	if autoApproverEnabled then
		UI.addBubble("🤖 Auto-approver enabled. Attempting to apply tasks directly...", false, "info") -- Using "info" or a new message type
		local allTasksAppliedSuccessfully = true
		for i, taskData in ipairs(tasks) do
			UI.addBubble("Applying task " .. i .. ": " .. (taskData.name or "Unnamed Task"), false, "info")
			local success, message = TaskApplier.applyTask(taskData)
			if success then
				UI.addBubble("Task '" .. (taskData.name or "Unnamed") .. "': " .. message, false, "success")
			else
				UI.addBubble("Task '" .. (taskData.name or "Unnamed") .. "' failed: " .. message, false, "error")
				allTasksAppliedSuccessfully = false
				-- Optional: Decide if you want to stop on first failure or try all tasks
			end
			task.wait(0.1) -- Small delay to allow UI updates and prevent flooding
		end
		if allTasksAppliedSuccessfully then
			UI.addBubble("All tasks auto-applied successfully. ✨", false, "success")
		else
			UI.addBubble("Some tasks could not be auto-applied. Please review errors.", false, "warning")
		end
	else
		-- Existing manual task card creation logic
		for i, taskData in ipairs(tasks) do
			UI.createTaskCard(taskData, i, function(selectedTaskData, applyButtonInstance)
				local success, message = TaskApplier.applyTask(selectedTaskData)
				if success then
					applyButtonInstance.Text = "Applied ✔️"
					applyButtonInstance.BackgroundColor3 = Color3.fromRGB(80,80,80)
					applyButtonInstance.TextColor3 = UI.SUBTLE_TEXT_COLOR or Color3.fromRGB(150,150,150)
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
end

-- Connect Send Button
if uiElements.sendButton then
	uiElements.sendButton.MouseButton1Click:Connect(onSend)
else
	warn("AI Vibe Coder: Send Button not found in UI elements after UI creation.")
end

-- Connect Settings Elements
if uiElements.apiKeyInput then
	uiElements.apiKeyInput.FocusLost:Connect(function(enterPressed)
		local newApiKey = uiElements.apiKeyInput.Text
		plugin:SetSetting(API_KEY_SETTING, newApiKey)
		print("AI Vibe Coder (Zentry): API Key setting saved.")
		GeminiAPI.setAPIKey(newApiKey) -- Update the API key in the module
	end)
else
	warn("AI Vibe Coder: ApiKeyInput not found in UI elements.")
end

if uiElements.autoApproverToggle then
	uiElements.autoApproverToggle.MouseButton1Click:Connect(function()
		-- The visual toggle is handled in UI.lua
		-- Here we just save the new state based on the button's current text
		local isEnabled = (uiElements.autoApproverToggle.Text == "ON")
		plugin:SetSetting(AUTO_APPROVER_SETTING, isEnabled)
		print("AI Vibe Coder (Zentry): Auto Approver setting saved:", isEnabled)
	end)
else
	warn("AI Vibe Coder: AutoApproverToggle not found in UI elements.")
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
