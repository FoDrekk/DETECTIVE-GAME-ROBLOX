--!strict
--[[
	CutsceneView (Phase 5.1)
	Plays a scripted scene the server sends (Types.CutscenePayload): the
	camera moves through each shot (CameraController.playShot), letterbox
	bars frame it, subtitles come and go on their cues, and a shot can dip
	in from or out to black.

	Presentation only. The server decides what plays and when it is over;
	this view reports reaching the end (or the investigator skipping) through
	onFinished, and the server checks both. When the server ends a scene
	itself, `stop` closes the view without reporting anything.

	Skipping takes two presses of the primary input ([E] / (X) / the touch
	button): the first shows the skip hint, a second within
	Config.Cutscene.SkipConfirmWindow skips. A press meant for something
	else never throws a scene away. A scene the server marks unskippable
	ignores the input.

	Timing is scheduled against the clock at the start of the scene, not
	accumulated shot by shot, so a slow frame never drifts the subtitles.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Components = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Components"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local InputHints = require(script.Parent:WaitForChild("InputHints"))
local CameraController = require(script.Parent:WaitForChild("CameraController"))

local CutsceneView = {}

local Theme = Config.UI.Theme
local Style = Config.UI.Cutscene

local gui: ScreenGui? = nil
local letterTop: Frame? = nil
local letterBottom: Frame? = nil
local fade: Frame? = nil
local speakerLabel: TextLabel? = nil
local lineLabel: TextLabel? = nil
local skipLabel: TextLabel? = nil

local current: Types.CutscenePayload? = nil
-- Bumped on every play/stop so anything scheduled by an earlier scene (or
-- an earlier line) never lands on top of the next.
local token = 0
local lineToken = 0
local armedUntil = 0

local finishedEvent: BindableEvent = Instance.new("BindableEvent")

-- Fired with (cutsceneId, skipped) when the scene reaches its end or the
-- investigator skips it. Not fired by `stop`.
function CutsceneView.onFinished(): BindableEvent
	return finishedEvent
end

function CutsceneView.isPlaying(): boolean
	return current ~= nil
end

-- The id of the scene on screen, if any.
function CutsceneView.currentId(): string?
	local payload = current
	return payload and payload.id
end

local function tween(object: Instance, time: number, goal: { [string]: any }): Tween
	local t = TweenService:Create(object, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function cameraFrame(point: Types.CutsceneCameraPoint): CFrame
	return CFrame.lookAt(point.position, point.lookAt)
end

local function hideLine()
	lineToken += 1
	local line, speaker = lineLabel, speakerLabel
	if line and speaker then
		tween(line, Style.SubtitleFade, { TextTransparency = 1, TextStrokeTransparency = 1 })
		tween(speaker, Style.SubtitleFade, { TextTransparency = 1 })
	end
end

local function showLine(line: Types.CutsceneLine)
	lineToken += 1
	local label, speaker = lineLabel, speakerLabel
	if not label or not speaker then
		return
	end
	label.Text = line.text
	speaker.Text = if line.speaker then string.upper(line.speaker) else ""
	speaker.Visible = line.speaker ~= nil
	tween(label, Style.SubtitleFade, { TextTransparency = 0, TextStrokeTransparency = 0.55 })
	tween(speaker, Style.SubtitleFade, { TextTransparency = 0 })
end

local function setSkipHint(visible: boolean)
	local label = skipLabel
	if not label then
		return
	end
	if visible then
		label.Text = if InputHints.scheme() == "Touch"
			then "Tap Skip again to skip"
			else InputHints.format("Interact", "Skip")
	end
	tween(label, 0.2, { TextTransparency = if visible then 0 else 1 })
end

-- Bars and subtitles away, black lifted, camera back to the player.
local function close()
	token += 1
	current = nil
	armedUntil = 0
	local closing = token
	hideLine()
	setSkipHint(false)
	CameraController.stopCinematic()
	local top, bottom, black = letterTop, letterBottom, fade
	if top and bottom then
		tween(top, Style.BarTime, { Size = UDim2.new(1, 0, 0, 0) })
		tween(bottom, Style.BarTime, { Size = UDim2.new(1, 0, 0, 0) })
	end
	if black then
		tween(black, Style.BarTime, { BackgroundTransparency = 1 })
	end
	task.delay(Style.BarTime, function()
		if closing == token and gui then
			gui.Enabled = false
		end
	end)
end

-- One shot, started now: the camera move, its dips and its subtitle cues
-- (each timed from the start of the shot). Anything still pending when the
-- scene is replaced or closed checks `sceneToken` and does nothing.
local function runShot(shot: Types.CutsceneShot, sceneToken: number)
	local camera = shot.camera
	local from = cameraFrame(camera.from)
	local to = if camera.to then cameraFrame(camera.to) else from
	CameraController.playShot(from, to, shot.duration, camera.fieldOfView)

	local black = fade
	if black then
		local fadeIn = shot.fadeIn
		if fadeIn and fadeIn > 0 then
			black.BackgroundTransparency = 0
			tween(black, fadeIn, { BackgroundTransparency = 1 })
		else
			black.BackgroundTransparency = 1
		end
		local fadeOut = shot.fadeOut
		if fadeOut and fadeOut > 0 then
			task.delay(shot.duration - fadeOut, function()
				if sceneToken == token then
					tween(black, fadeOut, { BackgroundTransparency = 0 })
				end
			end)
		end
	end

	for _, line in ipairs(shot.lines or {}) do
		task.delay(line.at, function()
			if sceneToken ~= token then
				return
			end
			showLine(line)
			local shown = lineToken
			task.delay(line.duration, function()
				if sceneToken == token and shown == lineToken then
					hideLine()
				end
			end)
		end)
	end
end

--[[
	Play a scene the server sent. A scene already on screen is replaced
	(the server never sends two at once; this just keeps the view honest).
]]
function CutsceneView.play(payload: Types.CutscenePayload)
	local shots = payload.shots
	if not payload.active or not payload.id or not shots or #shots == 0 then
		return
	end
	local screen, top, bottom = gui, letterTop, letterBottom
	if not screen or not top or not bottom then
		return
	end
	token += 1
	local sceneToken = token
	current = payload
	armedUntil = 0
	screen.Enabled = true
	hideLine()
	setSkipHint(false)
	local bar = UDim2.new(1, 0, Style.Letterbox, 0)
	tween(top, Style.BarTime, { Size = bar })
	tween(bottom, Style.BarTime, { Size = bar })

	local sceneStart = os.clock()
	task.spawn(function()
		local offset = 0
		for _, shot in ipairs(shots) do
			local untilShot = sceneStart + offset - os.clock()
			if untilShot > 0 then
				task.wait(untilShot)
			end
			if sceneToken ~= token then
				return
			end
			runShot(shot, sceneToken)
			offset += shot.duration
		end
		local remaining = sceneStart + offset - os.clock()
		if remaining > 0 then
			task.wait(remaining)
		end
		if sceneToken ~= token then
			return
		end
		local id = payload.id :: string
		close()
		finishedEvent:Fire(id, false)
	end)
end

-- The server says the scene is over (it ended it, or confirmed our own
-- report). Closes without reporting; `id` guards against a stale message
-- about an earlier scene. Returns true if it closed the scene on screen.
function CutsceneView.stop(id: string?): boolean
	local payload = current
	if not payload or (id ~= nil and payload.id ~= id) then
		return false
	end
	close()
	return true
end

--[[
	The primary input while a scene plays. Always consumed (true): nothing
	behind a scene should react. The first press arms the skip and shows the
	hint; a second within the window skips.
]]
function CutsceneView.handlePrimary(): boolean
	local payload = current
	if not payload then
		return false
	end
	if payload.skippable == false then
		return true
	end
	local now = os.clock()
	if now < armedUntil then
		local id = payload.id :: string
		close()
		finishedEvent:Fire(id, true)
		return true
	end
	armedUntil = now + Config.Cutscene.SkipConfirmWindow
	setSkipHint(true)
	local armedAt = armedUntil
	task.delay(Config.Cutscene.SkipConfirmWindow, function()
		if armedUntil == armedAt and current == payload then
			setSkipHint(false)
		end
	end)
	return true
end

-- Label for the touch primary button while a scene plays (nil hides it).
function CutsceneView.primaryLabel(): string?
	local payload = current
	if not payload or payload.skippable == false then
		return nil
	end
	return "Skip"
end

function CutsceneView.start()
	gui = Components.screenGui("MysteryCase_Cutscene", 26)
	local screen = gui :: ScreenGui
	screen.Enabled = false

	local function bar(name: string, anchorY: number): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0, anchorY)
		f.Position = UDim2.fromScale(0, anchorY)
		f.Size = UDim2.new(1, 0, 0, 0)
		f.ZIndex = 2
		f.Parent = screen
		return f
	end
	letterTop = bar("LetterboxTop", 0)
	letterBottom = bar("LetterboxBottom", 1)

	-- Full-screen black for the dips, under the bars and the words.
	local black = Instance.new("Frame")
	black.Name = "Fade"
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BackgroundTransparency = 1
	black.BorderSizePixel = 0
	black.Size = UDim2.fromScale(1, 1)
	black.ZIndex = 1
	black.Parent = screen
	fade = black

	-- Subtitles: centred just above the bottom bar, the speaker's name over
	-- the line (captions have no name).
	local box = Instance.new("Frame")
	box.Name = "Subtitle"
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.new(0.5, 0, 1 - Style.Letterbox, -Style.SubtitleGap)
	box.Size = UDim2.new(0.8, 0, 0, 0)
	box.AutomaticSize = Enum.AutomaticSize.Y
	box.ZIndex = 3
	box.Parent = screen
	local width = Instance.new("UISizeConstraint")
	width.MaxSize = Vector2.new(Style.SubtitleMaxWidth, math.huge)
	width.Parent = box
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.Padding = UDim.new(0, 4)
	list.Parent = box

	local speaker = Components.text({
		name = "Speaker",
		text = "",
		size = UDim2.new(1, 0, 0, 16),
		font = Theme.FontBold,
		textSize = 13,
		color = Theme.Accent,
		xAlign = Enum.TextXAlignment.Center,
		parent = box,
	})
	speaker.LayoutOrder = 1
	speaker.TextTransparency = 1
	speaker.ZIndex = 3
	speakerLabel = speaker

	local line = Components.text({
		name = "Line",
		text = "",
		size = UDim2.new(1, 0, 0, 0),
		textSize = Style.SubtitleSizeMax,
		color = Theme.TextPrimary,
		xAlign = Enum.TextXAlignment.Center,
		parent = box,
	})
	line.LayoutOrder = 2
	line.AutomaticSize = Enum.AutomaticSize.Y
	line.TextWrapped = true
	line.TextStrokeColor3 = Color3.new(0, 0, 0)
	line.TextTransparency = 1
	line.TextStrokeTransparency = 1
	line.ZIndex = 3
	lineLabel = line

	-- The skip hint, small, in the bottom bar's right corner.
	local skip = Components.text({
		name = "SkipHint",
		text = "",
		size = UDim2.fromOffset(260, 18),
		position = UDim2.new(1, -24, 1, -14),
		anchor = Vector2.new(1, 1),
		textSize = 12,
		color = Theme.TextSecondary,
		xAlign = Enum.TextXAlignment.Right,
		parent = screen,
	})
	skip.TextTransparency = 1
	skip.ZIndex = 3
	skipLabel = skip

	-- Subtitle size follows the screen height, so a phone isn't half words.
	local function resize()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local size = math.floor(camera.ViewportSize.Y * 0.03)
		line.TextSize = math.clamp(size, Style.SubtitleSizeMin, Style.SubtitleSizeMax)
	end
	resize()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
	end
	InputHints.changed().Event:Connect(function()
		if os.clock() < armedUntil then
			setSkipHint(true)
		end
	end)
end

return CutsceneView
