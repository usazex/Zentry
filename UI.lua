--UI.lua Module script
local UI = {}

-- Constants
local ACCENT_COLOR = Color3.fromRGB(0, 122, 255)
local BACKGROUND_COLOR = Color3.fromRGB(28, 28, 30)
local SURFACE_COLOR = Color3.fromRGB(44, 44, 46)
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local SUBTLE_TEXT_COLOR = Color3.fromRGB(150, 150, 150)
local ERROR_COLOR = Color3.fromRGB(255, 59, 48)
local SUCCESS_COLOR = Color3.fromRGB(52, 199, 89)
local WARNING_COLOR = Color3.fromRGB(255, 204, 0)

local TweenService = game:GetService("TweenService")

-- This will hold references to key UI elements after creation
local uiElements = {}

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
	local bubbleHorizontalAlignment = Enum.HorizontalAlignment.Left

	if isUser then
		bubbleColor = ACCENT_COLOR
		textColor = Color3.fromRGB(255,255,255)
		textXAlignment = Enum.TextXAlignment.Right
		bubbleHorizontalAlignment = Enum.HorizontalAlignment.Right
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
			textColor = BACKGROUND_COLOR -- Text on yellow warning
		elseif messageType == "thinking" then
			bubbleColor = SURFACE_COLOR
			textColor = SUBTLE_TEXT_COLOR
		end
	end

	-- bubble.HorizontalAlignment = bubbleHorizontalAlignment -- REMOVE this line, not valid for Frame

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
	label.Size = UDim2.new(1, -24, 0,0) -- Max width for text before wrapping, adjusted for padding
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.TextXAlignment = textXAlignment
	label.Parent = contentFrame

	bubble.Parent = uiElements.chatFrame

	contentFrame.Size = UDim2.fromScale(0.95, 0.8)
	contentFrame.BackgroundTransparency = 0.5
	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local goal = { BackgroundTransparency = 0 } -- Size will be handled by AutomaticSize
	local tween = TweenService:Create(contentFrame, tweenInfo, goal)
	tween:Play()

	-- Set alignment on the layout object, not the Frame
	if uiElements.chatLayout then
		if isUser then
			uiElements.chatLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		else
			uiElements.chatLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		end
	end

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
	taskCard.BorderColor3 = Color3.fromRGB(60,60,60)
	taskCard.LayoutOrder = #uiElements.chatFrame:GetChildren() + 1
	-- taskCard.HorizontalAlignment = Enum.HorizontalAlignment.Center -- REMOVE this line, not valid for Frame

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 8)
	cardCorner.Parent = taskCard

	local cardLayout = Instance.new("UIListLayout")
	cardLayout.Padding = UDim.new(0,8)
	cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardLayout.Parent = taskCard
	cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center -- Set alignment on layout

	local cardPadding = Instance.new("UIPadding")
	cardPadding.PaddingTop = UDim.new(0,10)
	cardPadding.PaddingBottom = UDim.new(0,10)
	cardPadding.PaddingLeft = UDim.new(0,10)
	cardPadding.PaddingRight = UDim.new(0,10)
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
	detailsFrame.Size = UDim2.new(1,0,0,20)
	detailsFrame.AutomaticSize = Enum.AutomaticSize.X -- Should be Y for height or X for width based on content
	detailsFrame.LayoutOrder = 3
	detailsFrame.Parent = taskCard

	local detailsLayout = Instance.new("UIListLayout")
	detailsLayout.FillDirection = Enum.FillDirection.Horizontal
	detailsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	detailsLayout.Padding = UDim.new(0,10)
	detailsLayout.Parent = detailsFrame

	local actionLabel = Instance.new("TextLabel")
	actionLabel.Name = "ActionLabel"
	actionLabel.BackgroundTransparency = 1
	actionLabel.Text = "▶️ Action: " .. (taskData.action or "N/A")
	actionLabel.Font = Enum.Font.GothamMedium
	actionLabel.TextColor3 = SUBTLE_TEXT_COLOR
	actionLabel.TextSize = 13
	actionLabel.TextXAlignment = Enum.TextXAlignment.Left
	actionLabel.AutomaticSize = Enum.AutomaticSize.XY
	actionLabel.Parent = detailsFrame

	local locationLabel = Instance.new("TextLabel")
	locationLabel.Name = "LocationLabel"
	locationLabel.BackgroundTransparency = 1
	locationLabel.Text = "📍 Location: " .. (taskData.location or "N/A")
	locationLabel.Font = Enum.Font.GothamMedium
	locationLabel.TextColor3 = SUBTLE_TEXT_COLOR
	locationLabel.TextSize = 13
	locationLabel.TextXAlignment = Enum.TextXAlignment.Left
	locationLabel.AutomaticSize = Enum.AutomaticSize.XY
	locationLabel.Parent = detailsFrame

	local applyBtn = Instance.new("TextButton")
	applyBtn.Name = "ApplyButton"
	applyBtn.Size = UDim2.new(0, 100, 0, 32)
	applyBtn.Text = "Apply ✨"
	applyBtn.Font = Enum.Font.GothamBold
	applyBtn.TextSize = 14
	applyBtn.TextColor3 = Color3.fromRGB(255,255,255)
	applyBtn.BackgroundColor3 = SUCCESS_COLOR
	applyBtn.LayoutOrder = 4
	-- applyBtn.HorizontalAlignment = Enum.HorizontalAlignment.Right -- REMOVE this line, not valid for TextButton

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0,6)
	btnCorner.Parent = applyBtn
	applyBtn.Parent = taskCard

	applyBtn.MouseButton1Click:Connect(function()
		if onApplyCallback then
			onApplyCallback(taskData, applyBtn) -- Pass button for UI updates
		end
	end)

	taskCard.Parent = uiElements.chatFrame

	task.wait(0.05)
	uiElements.chatFrame.CanvasPosition = Vector2.new(0, uiElements.chatFrame.AbsoluteCanvasSize.Y)
	return taskCard
end


function UI.createLayout(widgetInstance)
	uiElements = {} -- Clear previous elements if any (for potential re-runs, though unlikely for plugins)

	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(1,0,1,0)
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

	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, -20, 0, 40)
	titleBar.BackgroundColor3 = SURFACE_COLOR
	titleBar.LayoutOrder = 1
	titleBar.Parent = mainFrame
	local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0,8); tc.Parent = titleBar;
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, -20, 1, 0); titleLabel.Position = UDim2.new(0, 10, 0, 0)
	titleLabel.BackgroundTransparency = 1; titleLabel.Text = "AI Vibe Coder ✨"
	titleLabel.TextColor3 = ACCENT_COLOR; titleLabel.TextSize = 20
	titleLabel.Font = Enum.Font.GothamBold; titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = titleBar
	uiElements.titleLabel = titleLabel

	-- File Explorer (Placeholder - to be implemented later)
	local fileExplorerFrame = Instance.new("Frame")
	fileExplorerFrame.Name = "FileExplorerFrame"
	fileExplorerFrame.Size = UDim2.new(1, -20, 0, 150); fileExplorerFrame.BackgroundColor3 = SURFACE_COLOR
	fileExplorerFrame.Visible = false; fileExplorerFrame.LayoutOrder = 2; fileExplorerFrame.Parent = mainFrame
	local fec = Instance.new("UICorner"); fec.CornerRadius = UDim.new(0,8); fec.Parent = fileExplorerFrame;
	-- ... (file explorer contents would go here if it were functional) ...
	uiElements.fileExplorerFrame = fileExplorerFrame

	local chatFrame = Instance.new("ScrollingFrame")
	chatFrame.Name = "ChatFrame"
	chatFrame.Size = UDim2.new(1, -20, 1, -120)
	chatFrame.BackgroundColor3 = BACKGROUND_COLOR; chatFrame.BorderSizePixel = 0
	chatFrame.CanvasSize = UDim2.new(0,0,0,0); chatFrame.ScrollBarThickness = 8
	chatFrame.ScrollBarImageColor3 = ACCENT_COLOR; chatFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	chatFrame.LayoutOrder = 3; chatFrame.Parent = mainFrame
	uiElements.chatFrame = chatFrame

	local chatLayout = Instance.new("UIListLayout")
	chatLayout.Name = "ChatLayout"
	chatLayout.Padding = UDim.new(0, 8); chatLayout.SortOrder = Enum.SortOrder.LayoutOrder
	chatLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	chatLayout.Parent = chatFrame
	uiElements.chatLayout = chatLayout

	local inputFrame = Instance.new("Frame")
	inputFrame.Name = "InputFrame"
	inputFrame.Size = UDim2.new(1, -20, 0, 60); inputFrame.BackgroundColor3 = SURFACE_COLOR
	inputFrame.LayoutOrder = 4; inputFrame.Visible = true; inputFrame.Parent = mainFrame
	local ifc = Instance.new("UICorner"); ifc.CornerRadius = UDim.new(0,8); ifc.Parent = inputFrame;
	uiElements.inputFrame = inputFrame

	local inputBox = Instance.new("TextBox")
	inputBox.Name = "InputBox"
	inputBox.Size = UDim2.new(1, -100, 0, 40); inputBox.Position = UDim2.new(0, 10, 0, 10)
	inputBox.PlaceholderText = "Tell the AI what to code..."; inputBox.Text = ""
	inputBox.TextSize = 16; inputBox.Font = Enum.Font.GothamMedium
	inputBox.TextColor3 = TEXT_COLOR; inputBox.BackgroundColor3 = BACKGROUND_COLOR
	inputBox.ClearTextOnFocus = false; inputBox.MultiLine = true; inputBox.TextWrapped = true
	local ibs = Instance.new("UIStroke"); ibs.Color = ACCENT_COLOR; ibs.Thickness = 0; ibs.Parent = inputBox;
	local ibc = Instance.new("UICorner"); ibc.CornerRadius = UDim.new(0,6); ibc.Parent = inputBox;
	inputBox.Parent = inputFrame
	uiElements.inputBox = inputBox
	uiElements.inputBoxStroke = ibs -- Store stroke for focus effect

	inputBox.Focused:Connect(function() ibs.Thickness = 1.5 end)
	inputBox.FocusLost:Connect(function() ibs.Thickness = 0 end)

	local sendButton = Instance.new("TextButton")
	sendButton.Name = "SendButton"
	sendButton.Size = UDim2.new(0, 80, 0, 40); sendButton.Position = UDim2.new(1, -90, 0, 10)
	sendButton.Text = "Send"; sendButton.TextSize = 16; sendButton.Font = Enum.Font.GothamBold
	sendButton.TextColor3 = Color3.fromRGB(255,255,255); sendButton.BackgroundColor3 = ACCENT_COLOR
	sendButton.Visible = true
	local sbc = Instance.new("UICorner"); sbc.CornerRadius = UDim.new(0,6); sbc.Parent = sendButton;
	sendButton.Parent = inputFrame
	uiElements.sendButton = sendButton

	local baseSendColor = sendButton.BackgroundColor3
	sendButton.MouseEnter:Connect(function() sendButton.BackgroundColor3 = baseSendColor:Lerp(Color3.new(0,0,0), 0.15) end)
	sendButton.MouseLeave:Connect(function() sendButton.BackgroundColor3 = baseSendColor end)

	return uiElements -- Return all created key elements
end

return UI

