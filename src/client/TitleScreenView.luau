--!strict
--[[
	TitleScreenView (M6)
	The first thing a player sees: the case title over a slow cinematic drift
	through the dark office, with letterbox bars. Shown once per session, on
	join -- a replay goes straight back to the briefing.

	Purely presentational and client-only: it holds the briefing back until
	the player chooses to play, and never touches game state. The bootstrap
	routes the primary input here while it is open.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Components = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Components"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local InputHints = require(script.Parent:WaitForChild("InputHints"))
local CameraController = require(script.Parent:WaitForChild("CameraController"))

local TitleScreenView = {}

local Theme = Config.UI.Theme
local Presentation = Config.Presentation

local gui: ScreenGui? = nil
local fade: Frame? = nil
local fadeables: { GuiObject } = {}
local caseLabel: TextLabel? = nil
local titleLabel: TextLabel? = nil
local playButton: TextButton? = nil
local open = false
local dismissing = false

local dismissed: BindableEvent = Instance.new("BindableEvent")

-- Fires once the title has faded away and the camera is back with the
-- player.
function TitleScreenView.onDismissed(): BindableEvent
	return dismissed
end

function TitleScreenView.isOpen(): boolean
	return open
end

-- The case the title is presenting (from the briefing payload).
function TitleScreenView.setCase(briefing: Types.CaseBriefing)
	if titleLabel and caseLabel then
		titleLabel.Text = string.upper(briefing.title)
		caseLabel.Text = briefing.id
	end
end

local function textTween(object: GuiObject, transparency: number, time: number, delay: number)
	local goal: { [string]: any } = {}
	if object:IsA("TextLabel") or object:IsA("TextButton") then
		goal.TextTransparency = transparency
	end
	if object:GetAttribute("FadesBackground") then
		goal.BackgroundTransparency = transparency
	end
	TweenService:Create(object, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, delay), goal)
		:Play()
end

function TitleScreenView.open()
	if not gui or not fade or open then
		return
	end
	open = true
	dismissing = false
	gui.Enabled = true

	local shot = Presentation.IntroShot
	CameraController.playCinematic(
		CFrame.lookAt(shot.From.Position, shot.From.LookAt),
		CFrame.lookAt(shot.To.Position, shot.To.LookAt),
		shot.Duration
	)

	-- Out of black, then the words arrive one after another.
	fade.BackgroundTransparency = 0
	TweenService:Create(fade, TweenInfo.new(2.2, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 }):Play()
	for index, object in ipairs(fadeables) do
		if object:IsA("TextLabel") or object:IsA("TextButton") then
			object.TextTransparency = 1
		end
		if object:GetAttribute("FadesBackground") then
			object.BackgroundTransparency = 1
		end
		textTween(object, 0, 1.2, 1.0 + index * 0.35)
	end
end

-- Fade to black, hand the camera back, then reveal whatever the phase shows
-- (the briefing, on a first join).
function TitleScreenView.dismiss()
	if not open or dismissing or not gui or not fade then
		return
	end
	dismissing = true
	local fadeIn = TweenService:Create(fade, TweenInfo.new(0.7, Enum.EasingStyle.Sine), { BackgroundTransparency = 0 })
	fadeIn.Completed:Once(function()
		CameraController.stopCinematic()
		for _, object in ipairs(fadeables) do
			object.Visible = false
		end
		open = false
		dismissed:Fire()
		local fadeOut = TweenService:Create(fade, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 })
		fadeOut.Completed:Once(function()
			if gui then
				gui.Enabled = false
			end
		end)
		fadeOut:Play()
	end)
	fadeIn:Play()
end

function TitleScreenView.start()
	gui = Components.screenGui("MysteryCase_Title", 40)
	gui.Enabled = false

	-- Letterbox bars and a darkening wash behind the text.
	for _, edge in ipairs({ 0, 1 }) do
		Components.frame({
			name = if edge == 0 then "LetterboxTop" else "LetterboxBottom",
			size = UDim2.fromScale(1, 0.11),
			position = UDim2.fromScale(0, edge),
			anchor = Vector2.new(0, edge),
			color = Color3.new(0, 0, 0),
			radius = 0,
			parent = gui,
		})
	end

	local wash = Components.frame({
		name = "Wash",
		size = UDim2.fromScale(0.75, 0.78),
		position = UDim2.fromScale(0, 0.89),
		anchor = Vector2.new(0, 1),
		color = Color3.new(0, 0, 0),
		radius = 0,
		parent = gui,
	})
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = -35
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(0.55, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = wash

	-- Text block, anchored bottom-left inside the letterbox.
	local block = Instance.new("Frame")
	block.Name = "TitleBlock"
	block.BackgroundTransparency = 1
	block.Size = UDim2.fromOffset(620, 230)
	block.Position = UDim2.new(0, 72, 0.89, -48)
	block.AnchorPoint = Vector2.new(0, 1)
	block.Parent = gui

	local kicker = Components.text({
		name = "Kicker",
		text = Presentation.Title.Kicker,
		size = UDim2.new(1, 0, 0, 18),
		position = UDim2.fromOffset(0, 0),
		font = Theme.FontBold,
		textSize = 14,
		color = Theme.Accent,
		parent = block,
	})

	local rule = Components.frame({
		name = "Rule",
		size = UDim2.fromOffset(56, 2),
		position = UDim2.fromOffset(0, 28),
		color = Theme.Accent,
		radius = 1,
		parent = block,
	})
	rule:SetAttribute("FadesBackground", true)

	local title = Components.text({
		name = "Title",
		text = Presentation.Title.Fallback,
		size = UDim2.new(1, 0, 0, 72),
		position = UDim2.fromOffset(0, 40),
		font = Theme.FontBold,
		textSize = 64,
		color = Theme.TextPrimary,
		parent = block,
	})
	titleLabel = title

	local case = Components.text({
		name = "Case",
		text = "",
		size = UDim2.new(1, 0, 0, 20),
		position = UDim2.fromOffset(0, 118),
		textSize = 15,
		color = Theme.TextSecondary,
		parent = block,
	})
	caseLabel = case

	local button = Instance.new("TextButton")
	button.Name = "Play"
	button.AutoButtonColor = false
	button.BackgroundColor3 = Theme.Accent
	button.BackgroundTransparency = 0
	button.Size = UDim2.fromOffset(190, 44)
	button.Position = UDim2.fromOffset(0, 168)
	button.Font = Theme.FontBold
	button.TextSize = 17
	button.TextColor3 = Theme.Background
	button.Text = ""
	button:SetAttribute("FadesBackground", true)
	button.Parent = block
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 4)
	buttonCorner.Parent = button
	InputHints.bind(button, "Interact", "Play", "Play")
	button.Activated:Connect(TitleScreenView.dismiss)
	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = Theme.TextPrimary
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = Theme.Accent
	end)
	playButton = button

	local footer = Components.text({
		name = "Footer",
		text = Presentation.Title.Footer,
		size = UDim2.new(1, -72, 0, 18),
		position = UDim2.new(0, 72, 1, -34),
		textSize = 13,
		color = Theme.TextSecondary,
		parent = gui,
	})

	fadeables = { kicker, rule, title, case, button, footer }

	-- Full-screen black used for the fade in from and out to the game.
	local black = Components.frame({
		name = "Fade",
		color = Color3.new(0, 0, 0),
		radius = 0,
		parent = gui,
	})
	black.ZIndex = 10
	fade = black
end

-- For gamepad GUI navigation: the button to select while the title is up.
function TitleScreenView.getPlayButton(): TextButton?
	return playButton
end

return TitleScreenView
