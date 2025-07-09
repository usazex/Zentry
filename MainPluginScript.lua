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
-- local GeminiAPI = require(script.Parent.GeminiAPI) -- Now used by AgentExecutor
-- local FileScanner = require(script.Parent.FileScanner) -- Now used by AgentExecutor
-- local TaskParser = require(script.Parent.TaskParser) -- Now used by AgentExecutor
-- local TaskApplier = require(script.Parent.TaskApplier) -- Now used by AgentExecutor
local AgentExecutor = require(script.Parent.AgentExecutor)


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

	UI.addBubble(promptText, true, nil) -- Display user's prompt in the UI
	uiElements.inputBox.Text = "" -- Clear the input box

	-- The AgentExecutor will handle the rest:
	-- - Displaying "Thinking..."
	-- - Scanning files
	-- - Building prompt
	-- - Sending to AI
	-- - Parsing tasks
	-- - Applying tasks one by one
	-- - Reporting progress and results to the UI

	-- Run the agent executor in a new coroutine so it doesn't block the main thread
	-- This is important for UI responsiveness and to allow HttpService calls.
	coroutine.wrap(AgentExecutor.executePrompt)(promptText)

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
