--!strict
--[[
	CaseBriefingView (M8)
	The case opens on the scene itself: the camera drifts slowly across
	Daniel's office while the case number, the title, a two-line hook and
	the time and place settle into the lower left, over a soft corner shade
	instead of a panel. Most of the frame stays the office.

	Begin investigation is a real button, as well as the primary input and
	the touch primary. Purely presentational: phase changes are
	server-authoritative, and the view only hands the camera back when the
	server moves the phase on (hide).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Components = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Components"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local InputHints = require(script.Parent:WaitForChild("InputHints"))
local CameraController = require(script.Parent:WaitForChild("CameraController"))

local CaseBriefingView = {}

local Theme = Config.UI.Theme
local Style = Config.UI.Briefing

local gui: ScreenGui? = nil
local fade: Frame? = nil
local block: Frame? = nil
local bars: { Frame } = {}
local shade: Frame? = nil
local caseLabel: TextLabel? = nil
local titleLabel: TextLabel? = nil
local hookLabel: TextLabel? = nil
local settingLabel: TextLabel? = nil
local beginButton: TextButton? = nil
-- Text elements, in the order they arrive.
local reveal: { GuiObject } = {}

local open = false
-- Bumped on every show/hide so a transition that is overtaken by the next
-- one never finishes on top of it.
local transition = 0

local beginRequested: BindableEvent = Instance.new("BindableEvent")

function CaseBriefingView.onBeginRequested(): BindableEvent
	return beginRequested
end

function CaseBriefingView.isOpen(): boolean
	return open
end

-- "CASE-001" -> "CASE 001".
local function caseNumber(id: string): string
	return (string.gsub(string.upper(id), "[-_]", " "))
end

local function escapeRich(text: string): string
	return (string.gsub(string.gsub(string.gsub(text, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

local function settingText(briefing: Types.CaseBriefing): string
	local time = briefing.time
	local place = briefing.place
	local accent = Theme.Accent
	local hex = string.format(
		"#%02x%02x%02x",
		math.floor(accent.R * 255 + 0.5),
		math.floor(accent.G * 255 + 0.5),
		math.floor(accent.B * 255 + 0.5)
	)
	if time and place then
		return string.format('<font color="%s">%s</font>    %s', hex, escapeRich(time), escapeRich(place))
	elseif time then
		return string.format('<font color="%s">%s</font>', hex, escapeRich(time))
	end
	return escapeRich(place or "")
end

local function tween(object: Instance, time: number, goal: { [string]: any }, delay: number?): Tween
	local t = TweenService:Create(
		object,
		TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, delay or 0),
		goal
	)
	t:Play()
	return t
end

-- Fade every text element (and the rule/button fills) to `transparency`,
-- one after another when `stagger` is set.
local function fadeReveal(transparency: number, time: number, firstDelay: number, stagger: number)
	for index, object in ipairs(reveal) do
		local goal: { [string]: any } = {}
		if object:IsA("TextLabel") or object:IsA("TextButton") then
			goal.TextTransparency = transparency
		end
		if object:GetAttribute("FadesBackground") then
			goal.BackgroundTransparency = transparency
		end
		tween(object, time, goal, firstDelay + (index - 1) * stagger)
	end
end

function CaseBriefingView.show(briefing: Types.CaseBriefing)
	if not gui or not fade or not block or not caseLabel or not titleLabel or not hookLabel or not settingLabel then
		return
	end
	caseLabel.Text = caseNumber(briefing.id)
	titleLabel.Text = string.upper(briefing.title)
	hookLabel.Text = briefing.description
	settingLabel.Text = settingText(briefing)
	settingLabel.Visible = briefing.time ~= nil or briefing.place ~= nil
	if open then
		-- Already up (the phase and the payload both arrive): just refresh
		-- the words, without restarting the shot.
		return
	end
	open = true
	transition += 1
	gui.Enabled = true

	local shot = Config.Presentation.BriefingShot
	CameraController.playCinematic(
		CFrame.lookAt(shot.From.Position, shot.From.LookAt),
		CFrame.lookAt(shot.To.Position, shot.To.LookAt),
		shot.Duration
	)

	-- Up out of black onto the scene; the bars close in, the shade and the
	-- words follow.
	fade.BackgroundTransparency = 0
	tween(fade, Style.FadeIn, { BackgroundTransparency = 1 })
	for index, bar in ipairs(bars) do
		local edge = index - 1
		bar.Visible = true
		bar.Position = UDim2.fromScale(0, if edge == 0 then -Style.Letterbox else 1 + Style.Letterbox)
		tween(bar, 1.1, { Position = UDim2.fromScale(0, edge) }, 0.2)
	end
	if shade then
		shade.BackgroundTransparency = 1
		tween(shade, 1.4, { BackgroundTransparency = 0 }, 0.3)
	end
	for _, object in ipairs(reveal) do
		if object:IsA("TextLabel") or object:IsA("TextButton") then
			(object :: TextLabel).TextTransparency = 1
		end
		if object:GetAttribute("FadesBackground") then
			object.BackgroundTransparency = 1
		end
	end
	block.Position = UDim2.new(0, Style.Margin, 1 - Style.Letterbox, -Style.BottomGap + 14)
	tween(block, 1.6, { Position = UDim2.new(0, Style.Margin, 1 - Style.Letterbox, -Style.BottomGap) }, 0.5)
	fadeReveal(0, 0.9, 0.7, Style.Stagger)
end

-- The server has moved on (investigation, or anything else): dip to black,
-- hand the camera back to the player, and come up on the office.
function CaseBriefingView.hide()
	if not open or not gui or not fade then
		return
	end
	open = false
	transition += 1
	local token = transition
	local out = tween(fade, 0.35, { BackgroundTransparency = 0 })
	out.Completed:Once(function()
		if token ~= transition then
			return
		end
		CameraController.stopCinematic()
		fadeReveal(1, 0, 0, 0)
		if shade then
			shade.BackgroundTransparency = 1
		end
		for _, bar in ipairs(bars) do
			bar.Visible = false
		end
		local back = tween(fade, 0.6, { BackgroundTransparency = 1 }, 0.1)
		back.Completed:Once(function()
			if token ~= transition or not gui then
				return
			end
			gui.Enabled = false
			for _, bar in ipairs(bars) do
				bar.Visible = true
			end
		end)
	end)
end

local function makeButton(parent: Instance): TextButton
	local button = Instance.new("TextButton")
	button.Name = "Begin"
	button.AutoButtonColor = false
	button.BackgroundColor3 = Theme.Accent
	button.BackgroundTransparency = 0
	button.Size = UDim2.fromOffset(Style.ButtonWidth, 44)
	button.Font = Theme.FontBold
	button.TextSize = 16
	button.TextColor3 = Theme.Background
	button.Text = ""
	button.LayoutOrder = 7
	button:SetAttribute("FadesBackground", true)
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button
	InputHints.bind(button, "Interact", "Begin investigation", "Begin investigation")
	button.Activated:Connect(function()
		if open then
			beginRequested:Fire()
		end
	end)
	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = Theme.TextPrimary
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = Theme.Accent
	end)
	return button
end

function CaseBriefingView.start()
	gui = Components.screenGui("MysteryCase_Briefing", 15)
	local screen = gui :: ScreenGui
	screen.Enabled = false

	-- Letterbox bars: the frame is a shot, not a menu.
	bars = {}
	for _, edge in ipairs({ 0, 1 }) do
		local bar = Components.frame({
			name = if edge == 0 then "LetterboxTop" else "LetterboxBottom",
			size = UDim2.fromScale(1, Style.Letterbox),
			position = UDim2.fromScale(0, edge),
			anchor = Vector2.new(0, edge),
			color = Color3.new(0, 0, 0),
			radius = 0,
			parent = screen,
		})
		table.insert(bars, bar)
	end

	-- A soft shade in the lower-left corner only, so the words read
	-- against the dark without covering the scene.
	local corner = Components.frame({
		name = "Shade",
		size = UDim2.fromScale(0.72, 0.8),
		position = UDim2.fromScale(0, 1 - Style.Letterbox),
		anchor = Vector2.new(0, 1),
		color = Color3.new(0, 0, 0),
		radius = 0,
		parent = screen,
	})
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = -32
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 0.78),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = corner
	shade = corner

	-- The text column, bottom-left, laid out top to bottom:
	-- case number, rule, title, hook, time/place, begin.
	local column = Instance.new("Frame")
	column.Name = "Column"
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(0, 1)
	column.Size = UDim2.new(0.62, 0, 0, 0)
	column.AutomaticSize = Enum.AutomaticSize.Y
	column.Position = UDim2.new(0, Style.Margin, 1 - Style.Letterbox, -Style.BottomGap)
	column.Parent = screen
	local widthCap = Instance.new("UISizeConstraint")
	widthCap.MaxSize = Vector2.new(Style.MaxWidth, math.huge)
	widthCap.Parent = column
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 10)
	list.Parent = column
	block = column

	local function line(
		name: string,
		order: number,
		props: { font: Enum.Font?, textSize: number, color: Color3 }
	): TextLabel
		local label = Components.text({
			name = name,
			text = "",
			size = UDim2.new(1, 0, 0, 0),
			font = props.font,
			textSize = props.textSize,
			color = props.color,
			parent = column,
		})
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.TextWrapped = true
		label.LayoutOrder = order
		return label
	end

	caseLabel = line("CaseNumber", 1, { font = Theme.FontBold, textSize = 14, color = Theme.Accent })

	local rule = Components.frame({
		name = "Rule",
		size = UDim2.fromOffset(48, 2),
		color = Theme.Accent,
		radius = 1,
		parent = column,
	})
	rule.LayoutOrder = 2
	rule:SetAttribute("FadesBackground", true)

	titleLabel = line("Title", 3, { font = Theme.FontBold, textSize = Style.TitleSize, color = Theme.TextPrimary })
	local hook = line("Hook", 4, { textSize = Style.HookSize, color = Style.HookColor })
	hook.LineHeight = 1.2
	hookLabel = hook
	local hookWidth = Instance.new("UISizeConstraint")
	hookWidth.MaxSize = Vector2.new(Style.HookWidth, math.huge)
	hookWidth.Parent = hook

	local setting = line("Setting", 5, { font = Theme.FontBold, textSize = 13, color = Theme.TextSecondary })
	setting.RichText = true
	settingLabel = setting

	-- A little air above the button.
	local spacer = Instance.new("Frame")
	spacer.Name = "Spacer"
	spacer.BackgroundTransparency = 1
	spacer.Size = UDim2.fromOffset(1, 4)
	spacer.LayoutOrder = 6
	spacer.Parent = column

	beginButton = makeButton(column)

	reveal = { caseLabel :: TextLabel, rule, titleLabel :: TextLabel, hook, setting, beginButton :: TextButton }

	-- Small screens (phones): scale the whole overlay down rather than let
	-- the column run into the top bar.
	local scale = Instance.new("UIScale")
	scale.Parent = column
	local function rescale()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		scale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720) * 1.1, 0.62, 1)
	end
	rescale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	-- Full-screen black for the dips in and out of the shot.
	local black = Components.frame({
		name = "Fade",
		color = Color3.new(0, 0, 0),
		transparency = 1,
		radius = 0,
		parent = screen,
	})
	black.ZIndex = 10
	fade = black
end

return CaseBriefingView
