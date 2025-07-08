--UI.lua Module script
local UI = {}

-- Enhanced Constants with better color palette
local ACCENT_COLOR = Color3.fromRGB(0, 122, 255)
local ACCENT_HOVER = Color3.fromRGB(30, 144, 255)
local BACKGROUND_COLOR = Color3.fromRGB(28, 28, 30)
local SURFACE_COLOR = Color3.fromRGB(44, 44, 46)
local ELEVATED_SURFACE = Color3.fromRGB(58, 58, 60)
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local SUBTLE_TEXT_COLOR = Color3.fromRGB(150, 150, 150)
local ERROR_COLOR = Color3.fromRGB(255, 59, 48)
local SUCCESS_COLOR = Color3.fromRGB(52, 199, 89)
local WARNING_COLOR = Color3.fromRGB(255, 204, 0)
local BORDER_COLOR = Color3.fromRGB(70, 70, 72)

local TweenService = game:GetService("TweenService")

-- This will hold references to key UI elements after creation
local uiElements = {}

-- Animation helpers
local function createFadeInTween(element, duration)
	duration = duration or 0.2
	element.BackgroundTransparency = 1
	local tween = TweenService:Create(element, 
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{BackgroundTransparency = 0}
	)
	return tween
end

local function createHoverEffect(button, normalColor, hoverColor)
	button.MouseEnter:Connect(function()
		TweenService:Create(button, 
			TweenInfo.new(0.1, Enum.EasingStyle.Quad), 
			{BackgroundColor3 = hoverColor}
		):Play()
	end)

	button.MouseLeave:Connect(function()
		TweenService:Create(button, 
			TweenInfo.new(0.1, Enum.EasingStyle.Quad), 
			{BackgroundColor3 = normalColor}
		):Play()
	end)
end

function UI.addBubble(text, isUser, messageType)
	if not uiElements.chatFrame or not uiElements.chatLayout then
		print("UI_MODULE_ERROR: chatFrame or chatLayout not initialized in UI module.")
		return
	end

	local bubble = Instance.new("Frame")
	bubble.BackgroundTransparency = 1
	bubble.Size = UDim2.new(0.95, 0, 0, 0)
	bubble.AutomaticSize = Enum.AutomaticSize.Y
	bubble.LayoutOrder = #uiElements.chatFrame:GetChildren() + 1

	local bubbleColor
	local textColor = TEXT_COLOR
	local textXAlignment = Enum.TextXAlignment.Left

	if isUser then
		bubbleColor = ACCENT_COLOR
		textColor = Color3.fromRGB(255,255,255)
		textXAlignment = Enum.TextXAlignment.Right
	else
		bubbleColor = SURFACE_COLOR
		if messageType == "error" then
			bubbleColor = ERROR_COLOR
			textColor = Color3.fromRGB(255,255,255)
		elseif messageType == "success" then
			bubbleColor = SUCCESS_COLOR
			textColor = Color3.fromRGB(255,255,255)
		elseif messageType == "warning" then
			bubbleColor = WARNING_COLOR
			textColor = BACKGROUND_COLOR
		elseif messageType == "info" then
			bubbleColor = ACCENT_COLOR
			textColor = Color3.fromRGB(255,255,255)
		elseif messageType == "thinking" then
			bubbleColor = SURFACE_COLOR
			textColor = SUBTLE_TEXT_COLOR
		end
	end

	local contentFrame = Instance.new("Frame")
	contentFrame.BackgroundColor3 = bubbleColor
	contentFrame.AutomaticSize = Enum.AutomaticSize.XY
	contentFrame.Parent = bubble

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = contentFrame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = contentFrame

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextWrapped = true
	label.TextSize = 15
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = textColor
	label.Size = UDim2.new(1, -24, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.TextXAlignment = textXAlignment
	label.Parent = contentFrame

	bubble.Parent = uiElements.chatFrame

	-- Enhanced animation
	local tween = createFadeInTween(contentFrame, 0.3)
	tween:Play()

	task.wait(0.05)
	uiElements.chatFrame.CanvasPosition = Vector2.new(0, uiElements.chatFrame.AbsoluteCanvasSize.Y)

	return bubble
end

function UI.createTaskCard(taskData, taskIndex, onApplyCallback)
	if not uiElements.chatFrame then
		print("UI_MODULE_ERROR: chatFrame not initialized for createTaskCard.")
		return
	end

	local taskCard = Instance.new("Frame")
	taskCard.Name = "TaskCard_" .. taskIndex
	taskCard.BackgroundColor3 = SURFACE_COLOR
	taskCard.Size = UDim2.new(0.95, 0, 0, 0)
	taskCard.AutomaticSize = Enum.AutomaticSize.Y
	taskCard.BorderSizePixel = 1
	taskCard.BorderColor3 = BORDER_COLOR
	taskCard.LayoutOrder = #uiElements.chatFrame:GetChildren() + 1

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 8)
	cardCorner.Parent = taskCard

	local cardLayout = Instance.new("UIListLayout")
	cardLayout.Padding = UDim.new(0, 8)
	cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardLayout.Parent = taskCard

	local cardPadding = Instance.new("UIPadding")
	cardPadding.PaddingTop = UDim.new(0, 15)
	cardPadding.PaddingBottom = UDim.new(0, 15)
	cardPadding.PaddingLeft = UDim.new(0, 15)
	cardPadding.PaddingRight = UDim.new(0, 15)
	cardPadding.Parent = taskCard

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = "📋 Task " .. taskIndex .. ": " .. (taskData.name or "Unnamed Task")
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextColor3 = ACCENT_COLOR
	nameLabel.TextSize = 16
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Size = UDim2.new(1, 0, 0, 20)
	nameLabel.LayoutOrder = 1
	nameLabel.Parent = taskCard

	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "DescriptionLabel"
	descLabel.BackgroundTransparency = 1
	descLabel.Text = taskData.description or "No description provided."
	descLabel.Font = Enum.Font.GothamMedium
	descLabel.TextColor3 = TEXT_COLOR
	descLabel.TextSize = 14
	descLabel.TextWrapped = true
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.Size = UDim2.new(1, 0, 0, 0)
	descLabel.AutomaticSize = Enum.AutomaticSize.Y
	descLabel.LayoutOrder = 2
	descLabel.Parent = taskCard

	local detailsFrame = Instance.new("Frame")
	detailsFrame.Name = "DetailsFrame"
	detailsFrame.BackgroundTransparency = 1
	detailsFrame.Size = UDim2.new(1, 0, 0, 20)
	detailsFrame.AutomaticSize = Enum.AutomaticSize.Y
	detailsFrame.LayoutOrder = 3
	detailsFrame.Parent = taskCard

	local detailsLayout = Instance.new("UIListLayout")
	detailsLayout.FillDirection = Enum.FillDirection.Horizontal
	detailsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	detailsLayout.Padding = UDim.new(0, 15)
	detailsLayout.Parent = detailsFrame

	local actionLabel = Instance.new("TextLabel")
	actionLabel.Name = "ActionLabel"
	actionLabel.BackgroundTransparency = 1
	actionLabel.Text = "▶️ " .. (taskData.action or "N/A")
	actionLabel.Font = Enum.Font.GothamMedium
	actionLabel.TextColor3 = SUBTLE_TEXT_COLOR
	actionLabel.TextSize = 13
	actionLabel.TextXAlignment = Enum.TextXAlignment.Left
	actionLabel.AutomaticSize = Enum.AutomaticSize.XY
	actionLabel.Parent = detailsFrame

	local locationLabel = Instance.new("TextLabel")
	locationLabel.Name = "LocationLabel"
	locationLabel.BackgroundTransparency = 1
	locationLabel.Text = "📍 " .. (taskData.location or "N/A")
	locationLabel.Font = Enum.Font.GothamMedium
	locationLabel.TextColor3 = SUBTLE_TEXT_COLOR
	locationLabel.TextSize = 13
	locationLabel.TextXAlignment = Enum.TextXAlignment.Left
	locationLabel.AutomaticSize = Enum.AutomaticSize.XY
	locationLabel.Parent = detailsFrame

	local applyBtn = Instance.new("TextButton")
	applyBtn.Name = "ApplyButton"
	applyBtn.Size = UDim2.new(0, 120, 0, 35)
	applyBtn.Text = "Apply ✨"
	applyBtn.Font = Enum.Font.GothamBold
	applyBtn.TextSize = 14
	applyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	applyBtn.BackgroundColor3 = SUCCESS_COLOR
	applyBtn.LayoutOrder = 4

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = applyBtn

	-- Enhanced button hover effect
	createHoverEffect(applyBtn, SUCCESS_COLOR, SUCCESS_COLOR:Lerp(Color3.new(1, 1, 1), 0.1))

	applyBtn.Parent = taskCard

	applyBtn.MouseButton1Click:Connect(function()
		if onApplyCallback then
			onApplyCallback(taskData, applyBtn)
		end
	end)

	taskCard.Parent = uiElements.chatFrame

	-- Animate card appearance
	local tween = createFadeInTween(taskCard, 0.3)
	tween:Play()

	task.wait(0.05)
	uiElements.chatFrame.CanvasPosition = Vector2.new(0, uiElements.chatFrame.AbsoluteCanvasSize.Y)

	return taskCard
end

function UI.createLayout(widgetInstance)
	uiElements = {}

	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(1, 0, 1, 0)
	mainFrame.BackgroundColor3 = BACKGROUND_COLOR
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = widgetInstance
	uiElements.mainFrame = mainFrame

	local mainLayout = Instance.new("UIListLayout")
	mainLayout.Name = "MainLayout"
	mainLayout.FillDirection = Enum.FillDirection.Vertical
	mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
	mainLayout.Padding = UDim.new(0, 10)
	mainLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	mainLayout.Parent = mainFrame

	-- Enhanced Title Bar
	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, -20, 0, 50)
	titleBar.BackgroundColor3 = ELEVATED_SURFACE
	titleBar.LayoutOrder = 1
	titleBar.Parent = mainFrame

	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 12)
	titleCorner.Parent = titleBar

	local titlePadding = Instance.new("UIPadding")
	titlePadding.PaddingLeft = UDim.new(0, 15)
	titlePadding.PaddingRight = UDim.new(0, 15)
	titlePadding.Parent = titleBar

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, -60, 1, 0)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "AI Vibe Coder ✨"
	titleLabel.TextColor3 = ACCENT_COLOR
	titleLabel.TextSize = 22
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = titleBar
	uiElements.titleLabel = titleLabel

	-- Enhanced Settings Button
	local settingsButton = Instance.new("TextButton")
	settingsButton.Name = "SettingsButton"
	settingsButton.Size = UDim2.new(0, 40, 0, 40)
	settingsButton.Position = UDim2.new(1, -50, 0, 5)
	settingsButton.Text = "⚙️"
	settingsButton.TextSize = 20
	settingsButton.TextColor3 = TEXT_COLOR
	settingsButton.BackgroundColor3 = SURFACE_COLOR
	settingsButton.Font = Enum.Font.GothamBold
	settingsButton.Parent = titleBar

	local settingsCorner = Instance.new("UICorner")
	settingsCorner.CornerRadius = UDim.new(0, 8)
	settingsCorner.Parent = settingsButton

	createHoverEffect(settingsButton, SURFACE_COLOR, ELEVATED_SURFACE)
	uiElements.settingsButton = settingsButton

	-- Chat Frame
	local chatFrame = Instance.new("ScrollingFrame")
	chatFrame.Name = "ChatFrame"
	chatFrame.Size = UDim2.new(1, -20, 1, -140)
	chatFrame.BackgroundColor3 = SURFACE_COLOR
	chatFrame.BorderSizePixel = 0
	chatFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	chatFrame.ScrollBarThickness = 6
	chatFrame.ScrollBarImageColor3 = ACCENT_COLOR
	chatFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	chatFrame.LayoutOrder = 2
	chatFrame.Parent = mainFrame

	local chatCorner = Instance.new("UICorner")
	chatCorner.CornerRadius = UDim.new(0, 12)
	chatCorner.Parent = chatFrame

	local chatPadding = Instance.new("UIPadding")
	chatPadding.PaddingTop = UDim.new(0, 10)
	chatPadding.PaddingBottom = UDim.new(0, 10)
	chatPadding.PaddingLeft = UDim.new(0, 10)
	chatPadding.PaddingRight = UDim.new(0, 10)
	chatPadding.Parent = chatFrame

	uiElements.chatFrame = chatFrame

	local chatLayout = Instance.new("UIListLayout")
	chatLayout.Name = "ChatLayout"
	chatLayout.Padding = UDim.new(0, 10)
	chatLayout.SortOrder = Enum.SortOrder.LayoutOrder
	chatLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	chatLayout.Parent = chatFrame
	uiElements.chatLayout = chatLayout

	-- Enhanced Input Frame
	local inputFrame = Instance.new("Frame")
	inputFrame.Name = "InputFrame"
	inputFrame.Size = UDim2.new(1, -20, 0, 70)
	inputFrame.BackgroundColor3 = ELEVATED_SURFACE
	inputFrame.LayoutOrder = 3
	inputFrame.Parent = mainFrame

	local inputCorner = Instance.new("UICorner")
	inputCorner.CornerRadius = UDim.new(0, 12)
	inputCorner.Parent = inputFrame

	local inputPadding = Instance.new("UIPadding")
	inputPadding.PaddingTop = UDim.new(0, 10)
	inputPadding.PaddingBottom = UDim.new(0, 10)
	inputPadding.PaddingLeft = UDim.new(0, 15)
	inputPadding.PaddingRight = UDim.new(0, 15)
	inputPadding.Parent = inputFrame

	uiElements.inputFrame = inputFrame

	local inputBox = Instance.new("TextBox")
	inputBox.Name = "InputBox"
	inputBox.Size = UDim2.new(1, -110, 0, 50)
	inputBox.Position = UDim2.new(0, 0, 0, 0)
	inputBox.PlaceholderText = "Tell the AI what to code..."
	inputBox.Text = ""
	inputBox.TextSize = 16
	inputBox.Font = Enum.Font.GothamMedium
	inputBox.TextColor3 = TEXT_COLOR
	inputBox.BackgroundColor3 = BACKGROUND_COLOR
	inputBox.ClearTextOnFocus = false
	inputBox.MultiLine = true
	inputBox.TextWrapped = true
	inputBox.TextXAlignment = Enum.TextXAlignment.Left
	inputBox.TextYAlignment = Enum.TextYAlignment.Top

	local inputBoxCorner = Instance.new("UICorner")
	inputBoxCorner.CornerRadius = UDim.new(0, 8)
	inputBoxCorner.Parent = inputBox

	local inputBoxPadding = Instance.new("UIPadding")
	inputBoxPadding.PaddingTop = UDim.new(0, 10)
	inputBoxPadding.PaddingBottom = UDim.new(0, 10)
	inputBoxPadding.PaddingLeft = UDim.new(0, 12)
	inputBoxPadding.PaddingRight = UDim.new(0, 12)
	inputBoxPadding.Parent = inputBox

	local inputStroke = Instance.new("UIStroke")
	inputStroke.Color = ACCENT_COLOR
	inputStroke.Thickness = 0
	inputStroke.Parent = inputBox

	inputBox.Parent = inputFrame
	uiElements.inputBox = inputBox
	uiElements.inputBoxStroke = inputStroke

	inputBox.Focused:Connect(function()
		TweenService:Create(inputStroke, TweenInfo.new(0.2), {Thickness = 2}):Play()
	end)
	inputBox.FocusLost:Connect(function()
		TweenService:Create(inputStroke, TweenInfo.new(0.2), {Thickness = 0}):Play()
	end)

	-- Enhanced Send Button
	local sendButton = Instance.new("TextButton")
	sendButton.Name = "SendButton"
	sendButton.Size = UDim2.new(0, 90, 0, 50)
	sendButton.Position = UDim2.new(1, -90, 0, 0)
	sendButton.Text = "Send ✨"
	sendButton.TextSize = 16
	sendButton.Font = Enum.Font.GothamBold
	sendButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	sendButton.BackgroundColor3 = ACCENT_COLOR
	sendButton.Parent = inputFrame

	local sendCorner = Instance.new("UICorner")
	sendCorner.CornerRadius = UDim.new(0, 8)
	sendCorner.Parent = sendButton

	createHoverEffect(sendButton, ACCENT_COLOR, ACCENT_HOVER)
	uiElements.sendButton = sendButton

	-- Create the settings panel
	UI.createSettingsPanel(mainFrame)

	-- Connect settings button
	if uiElements.settingsButton and uiElements.settingsPanel then
		uiElements.settingsButton.MouseButton1Click:Connect(function()
			local isVisible = uiElements.settingsPanel.Visible
			uiElements.settingsPanel.Visible = not isVisible

			if not isVisible then
				-- Animate panel appearance
				uiElements.settingsPanel.Size = UDim2.new(1, -20, 0, 0)
				local tween = TweenService:Create(uiElements.settingsPanel, 
					TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{Size = UDim2.new(1, -20, 0, 200)}
				)
				tween:Play()
			end
		end)
	end

	return uiElements
end

function UI.createSettingsPanel(mainFrame)
	local TweenService = game:GetService("TweenService")

	local ACCENT_COLOR = Color3.fromRGB(0, 162, 255)
	local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
	local SUBTLE_TEXT_COLOR = Color3.fromRGB(170, 170, 170)
	local BACKGROUND_COLOR = Color3.fromRGB(40, 40, 40)
	local BORDER_COLOR = Color3.fromRGB(80, 80, 80)
	local ELEVATED_SURFACE = Color3.fromRGB(30, 30, 30)
	local ERROR_COLOR = Color3.fromRGB(200, 50, 50)
	local SUCCESS_COLOR = Color3.fromRGB(50, 200, 50)

	local function applyHoverEffect(button, baseColor, hoverColor)
		button.MouseEnter:Connect(function()
			TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = hoverColor}):Play()
		end)
		button.MouseLeave:Connect(function()
			TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = baseColor}):Play()
		end)
	end

	local settingsPanel = Instance.new("Frame")
	settingsPanel.Name = "SettingsPanel"
	settingsPanel.Size = UDim2.new(1, -20, 0, 220) -- Increased height for input
	settingsPanel.Position = UDim2.new(0, 10, 0, 70)
	settingsPanel.BackgroundTransparency = 1
	settingsPanel.BorderSizePixel = 0
	settingsPanel.Visible = false
	settingsPanel.ZIndex = 15
	settingsPanel.Parent = mainFrame

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 12)
	panelCorner.Parent = settingsPanel

	local panelLayout = Instance.new("UIListLayout")
	panelLayout.Padding = UDim.new(0, 10)
	panelLayout.SortOrder = Enum.SortOrder.LayoutOrder
	panelLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	panelLayout.Parent = settingsPanel

	local panelPadding = Instance.new("UIPadding")
	panelPadding.PaddingTop = UDim.new(0, 15)
	panelPadding.PaddingBottom = UDim.new(0, 15)
	panelPadding.PaddingLeft = UDim.new(0, 15)
	panelPadding.PaddingRight = UDim.new(0, 15)
	panelPadding.Parent = settingsPanel

	-- Title
	local settingsTitle = Instance.new("TextLabel")
	settingsTitle.Name = "SettingsTitle"
	settingsTitle.Size = UDim2.new(1, 0, 0, 22)
	settingsTitle.Text = "⚙️ Settings"
	settingsTitle.TextColor3 = ACCENT_COLOR
	settingsTitle.Font = Enum.Font.GothamBold
	settingsTitle.TextSize = 16
	settingsTitle.TextXAlignment = Enum.TextXAlignment.Left
	settingsTitle.BackgroundTransparency = 1
	settingsTitle.LayoutOrder = 1
	settingsTitle.Parent = settingsPanel

	-- API Key Label
	local apiKeyLabel = Instance.new("TextLabel")
	apiKeyLabel.Name = "ApiKeyLabel"
	apiKeyLabel.Size = UDim2.new(1, 0, 0, 18)
	apiKeyLabel.Text = "🔑 Gemini API Key"
	apiKeyLabel.TextColor3 = TEXT_COLOR
	apiKeyLabel.Font = Enum.Font.GothamMedium
	apiKeyLabel.TextSize = 13
	apiKeyLabel.TextXAlignment = Enum.TextXAlignment.Left
	apiKeyLabel.BackgroundTransparency = 1
	apiKeyLabel.LayoutOrder = 2
	apiKeyLabel.Parent = settingsPanel

	local apiKeyInput = Instance.new("TextBox")
	apiKeyInput.Name = "ApiKeyInput"
	apiKeyInput.Size = UDim2.new(1, 0, 0, 30)
	apiKeyInput.PlaceholderText = "Enter your Gemini API Key..."
	apiKeyInput.PlaceholderColor3 = SUBTLE_TEXT_COLOR
	apiKeyInput.Text = ""
	apiKeyInput.TextColor3 = TEXT_COLOR
	apiKeyInput.BackgroundColor3 = BACKGROUND_COLOR
	apiKeyInput.Font = Enum.Font.Gotham
	apiKeyInput.TextSize = 13
	apiKeyInput.TextXAlignment = Enum.TextXAlignment.Left
	apiKeyInput.ClearTextOnFocus = false
	apiKeyInput.LayoutOrder = 3
	apiKeyInput.Parent = settingsPanel

	local apiKeyCorner = Instance.new("UICorner")
	apiKeyCorner.CornerRadius = UDim.new(0, 8)
	apiKeyCorner.Parent = apiKeyInput

	local apiKeyPadding = Instance.new("UIPadding")
	apiKeyPadding.PaddingLeft = UDim.new(0, 12)
	apiKeyPadding.PaddingRight = UDim.new(0, 12)
	apiKeyPadding.Parent = apiKeyInput

	local apiKeyStroke = Instance.new("UIStroke")
	apiKeyStroke.Color = BORDER_COLOR
	apiKeyStroke.Thickness = 1
	apiKeyStroke.Parent = apiKeyInput

	apiKeyInput.Focused:Connect(function()
		TweenService:Create(apiKeyStroke, TweenInfo.new(0.2), {Color = ACCENT_COLOR}):Play()
	end)
	apiKeyInput.FocusLost:Connect(function()
		TweenService:Create(apiKeyStroke, TweenInfo.new(0.2), {Color = BORDER_COLOR}):Play()
	end)

	-- Toggle Label
	local autoApproverLabel = Instance.new("TextLabel")
	autoApproverLabel.Name = "AutoApproverLabel"
	autoApproverLabel.Size = UDim2.new(1, 0, 0, 18)
	autoApproverLabel.Text = "🤖 Auto Approve Changes"
	autoApproverLabel.TextColor3 = TEXT_COLOR
	autoApproverLabel.Font = Enum.Font.GothamMedium
	autoApproverLabel.TextSize = 13
	autoApproverLabel.TextXAlignment = Enum.TextXAlignment.Left
	autoApproverLabel.BackgroundTransparency = 1
	autoApproverLabel.LayoutOrder = 4
	autoApproverLabel.Parent = settingsPanel

	-- Toggle Row
	local toggleRow = Instance.new("Frame")
	toggleRow.Name = "ToggleRow"
	toggleRow.Size = UDim2.new(1, 0, 0, 32)
	toggleRow.BackgroundTransparency = 1
	toggleRow.LayoutOrder = 5
	toggleRow.Parent = settingsPanel

	local toggleLayout = Instance.new("UIListLayout")
	toggleLayout.FillDirection = Enum.FillDirection.Horizontal
	toggleLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	toggleLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	toggleLayout.SortOrder = Enum.SortOrder.LayoutOrder
	toggleLayout.Padding = UDim.new(0, 8)
	toggleLayout.Parent = toggleRow

	local toggleDescription = Instance.new("TextLabel")
	toggleDescription.Name = "ToggleDescription"
	toggleDescription.Size = UDim2.new(1, -90, 1, 0)
	toggleDescription.Text = "Auto-apply AI suggestions"
	toggleDescription.TextColor3 = SUBTLE_TEXT_COLOR
	toggleDescription.Font = Enum.Font.Gotham
	toggleDescription.TextSize = 11
	toggleDescription.TextXAlignment = Enum.TextXAlignment.Left
	toggleDescription.BackgroundTransparency = 1
	toggleDescription.Parent = toggleRow

	local autoApproverToggle = Instance.new("TextButton")
	autoApproverToggle.Name = "AutoApproverToggle"
	autoApproverToggle.Size = UDim2.new(0, 70, 0, 28)
	autoApproverToggle.Text = "OFF"
	autoApproverToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
	autoApproverToggle.BackgroundColor3 = ERROR_COLOR
	autoApproverToggle.Font = Enum.Font.GothamBold
	autoApproverToggle.TextSize = 12
	autoApproverToggle.Parent = toggleRow

	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 18)
	toggleCorner.Parent = autoApproverToggle

	-- Toggle logic
	local isToggleOn = false
	local function updateToggleState()
		local newColor = isToggleOn and SUCCESS_COLOR or ERROR_COLOR
		autoApproverToggle.Text = isToggleOn and "ON" or "OFF"
		TweenService:Create(autoApproverToggle, TweenInfo.new(0.2), {
			BackgroundColor3 = newColor
		}):Play()
		applyHoverEffect(autoApproverToggle, newColor, newColor:Lerp(Color3.new(1, 1, 1), 0.1))
	end

	autoApproverToggle.MouseButton1Click:Connect(function()
		isToggleOn = not isToggleOn
		updateToggleState()
	end)

	updateToggleState()

	-- Store references
	uiElements.settingsPanel = settingsPanel
	uiElements.apiKeyInput = apiKeyInput
	uiElements.autoApproverToggle = autoApproverToggle
	uiElements.autoApproverLabel = autoApproverLabel

	return settingsPanel
end


-- Additional utility functions for better UX
function UI.showNotification(message, messageType, duration)
	duration = duration or 3

	if not uiElements.mainFrame then
		return
	end

	local notification = Instance.new("Frame")
	notification.Name = "Notification"
	notification.Size = UDim2.new(0, 300, 0, 50)
	notification.Position = UDim2.new(1, -320, 0, 20)
	notification.BackgroundColor3 = messageType == "error" and ERROR_COLOR or 
		messageType == "success" and SUCCESS_COLOR or 
		messageType == "warning" and WARNING_COLOR or 
		ACCENT_COLOR
	notification.BorderSizePixel = 0
	notification.ZIndex = 20
	notification.Parent = uiElements.mainFrame

	local notifCorner = Instance.new("UICorner")
	notifCorner.CornerRadius = UDim.new(0, 8)
	notifCorner.Parent = notification

	local notifLabel = Instance.new("TextLabel")
	notifLabel.Size = UDim2.new(1, -20, 1, 0)
	notifLabel.Position = UDim2.new(0, 10, 0, 0)
	notifLabel.BackgroundTransparency = 1
	notifLabel.Text = message
	notifLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	notifLabel.Font = Enum.Font.GothamMedium
	notifLabel.TextSize = 14
	notifLabel.TextXAlignment = Enum.TextXAlignment.Left
	notifLabel.TextWrapped = true
	notifLabel.Parent = notification

	-- Animate in
	notification.Position = UDim2.new(1, 0, 0, 20)
	TweenService:Create(notification, 
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = UDim2.new(1, -320, 0, 20)}
	):Play()

	-- Auto dismiss
	task.wait(duration)
	TweenService:Create(notification, 
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{Position = UDim2.new(1, 0, 0, 20)}
	):Play()

	task.wait(0.3)
	notification:Destroy()
end

function UI.updateSettingsVisibility(isVisible)
	if uiElements.settingsPanel then
		uiElements.settingsPanel.Visible = isVisible
	end
end

function UI.getApiKey()
	if uiElements.apiKeyInput then
		return uiElements.apiKeyInput.Text
	end
	return ""
end

function UI.setApiKey(key)
	if uiElements.apiKeyInput then
		uiElements.apiKeyInput.Text = key
	end
end

function UI.getAutoApproverState()
	if uiElements.autoApproverToggle then
		return uiElements.autoApproverToggle.Text == "ON"
	end
	return false
end

function UI.setAutoApproverState(enabled)
	if uiElements.autoApproverToggle then
		uiElements.autoApproverToggle.Text = enabled and "ON" or "OFF"
		uiElements.autoApproverToggle.BackgroundColor3 = enabled and SUCCESS_COLOR or ERROR_COLOR
	end
end

-- Enhanced input handling
function UI.setupInputHandlers()
	if uiElements.inputBox and uiElements.sendButton then
		-- Enter key to send
		uiElements.inputBox.FocusLost:Connect(function(enterPressed)
			if enterPressed and uiElements.inputBox.Text ~= "" then
				uiElements.sendButton.MouseButton1Click:Fire()
			end
		end)

		-- Auto-resize input box based on content
		uiElements.inputBox:GetPropertyChangedSignal("Text"):Connect(function()
			local textService = game:GetService("TextService")
			local textSize = textService:GetTextSize(
				uiElements.inputBox.Text,
				uiElements.inputBox.TextSize,
				uiElements.inputBox.Font,
				Vector2.new(uiElements.inputBox.AbsoluteSize.X - 24, math.huge)
			)

			local newHeight = math.max(50, math.min(150, textSize.Y + 20))
			uiElements.inputBox.Size = UDim2.new(1, -110, 0, newHeight)
			uiElements.inputFrame.Size = UDim2.new(1, -20, 0, newHeight + 20)
			uiElements.sendButton.Size = UDim2.new(0, 90, 0, newHeight)
		end)
	end
end

-- Initialize enhanced features
function UI.initialize()
	if uiElements.mainFrame then
		UI.setupInputHandlers()

		-- Add welcome message
		task.wait(0.5)
		UI.addBubble("Welcome to AI Vibe Coder! ✨ Configure your settings and start coding with AI assistance.", false, "info")
	end
end

return UI
