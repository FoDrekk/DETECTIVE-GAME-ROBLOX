--!strict
--[[
	CutsceneView (Phase 5.1, 5.5)
	Plays a scripted scene the server sends (Types.CutscenePayload): the
	camera moves through each shot (CameraController.playShot), letterbox
	bars frame it, subtitles come and go on their cues, and a shot can dip
	in from or out to black.

	Phase 5.5 adds what an opening needs: a shot can be framed in a SET
	(CutsceneSets: a dressed place built far from the office for the length of
	the scene, or the office itself with something added), lit by a named
	LOOK (CutsceneLighting), hold a FOCUS, fire named SOUND cues
	(SoundController) and set ACTIONS going in its set (a phone buzzing, a door
	sliding), put a TITLE CARD over the picture, and hand the look to the player
	(mouse-look, for the lift). Everything named is data in the case; nothing
	here knows a story.

	Presentation only. The server decides what plays and when it is over;
	this view reports reaching the end (or the investigator skipping) through
	onFinished, and the server checks both. When the server ends a scene
	itself, `stop` closes the view without reporting anything.

	Skipping. An ordinary scene takes two presses of the primary input ([E] /
	(X) / the touch button): the first shows the skip hint, a second within
	Config.Cutscene.SkipConfirmWindow skips. A press meant for something else
	never throws a scene away. The INTRO (isIntro) is skipped by HOLDING the
	primary input (or Space) for Config.Cutscene.SkipHoldSeconds while a meter
	fills; letting go cancels, so it can't happen by accident, and it dips to
	black rather than cutting from a bedroom to the office. A scene the server
	marks unskippable ignores the input.

	However a scene ends -- finished, skipped, stopped by the server -- every
	change it made is undone: the camera, the light, the sets, the sound.

	Timing is scheduled against the clock at the start of the scene, not
	accumulated shot by shot, so a slow frame never drifts the subtitles.
]]

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Components = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Components"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local InputHints = require(script.Parent:WaitForChild("InputHints"))
local CameraController = require(script.Parent:WaitForChild("CameraController"))
local CutsceneLighting = require(script.Parent:WaitForChild("CutsceneLighting"))
local CutsceneSets = require(script.Parent:WaitForChild("CutsceneSets"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))

local CutsceneView = {}

local Theme = Config.UI.Theme
local Style = Config.UI.Cutscene

local SKIP_ACTION = "MysteryCase_CutsceneSkip"

local gui: ScreenGui? = nil
local letterTop: Frame? = nil
local letterBottom: Frame? = nil
local fade: Frame? = nil
local speakerLabel: TextLabel? = nil
local lineLabel: TextLabel? = nil
local skipLabel: TextLabel? = nil
local meterTrack: Frame? = nil
local meterFill: Frame? = nil
local cardBox: Frame? = nil
local cardKicker: TextLabel? = nil
local cardTitle: TextLabel? = nil
local cardSubtitle: TextLabel? = nil

local current: Types.CutscenePayload? = nil
-- Bumped on every play/stop so anything scheduled by an earlier scene (or
-- an earlier line) never lands on top of the next.
local token = 0
local lineToken = 0
local cardToken = 0
local armedUntil = 0
-- Phase 5.5: the hold that skips an intro (nil when nothing is held).
local holdStart: number? = nil
local holdToken = 0
-- Phase 5.5: an intro's skip has begun (the dip to black), and can't begin twice.
local skipping = false
-- Which hint the skip label is showing, so a change of input scheme redraws it.
local hintMode: "none" | "press" | "hold" = "none"

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

local function pointFrame(set: string?, point: Types.CutsceneCameraPoint): CFrame
	local world = CutsceneSets.toWorld(set, point)
	return CFrame.lookAt(world.position, world.lookAt)
end

-- Run `fn` `delay` seconds from now if this scene is still the one on screen (at
-- once when the delay is nothing, so a cue at 0 lands with the shot's first frame).
local function later(sceneToken: number, delay: number, fn: () -> ())
	local function run()
		if sceneToken == token then
			fn()
		end
	end
	if delay <= 0 then
		run()
	else
		task.delay(delay, run)
	end
end

--------------------------------------------------------------------------
-- Subtitles, the hint, the meter, the title card
--------------------------------------------------------------------------

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

-- What the skip hint says for the input scheme in use.
local function hintText(mode: "press" | "hold"): string
	local scheme = InputHints.scheme()
	if mode == "hold" then
		if scheme == "Touch" then
			return "Hold Skip to skip"
		end
		local glyph = InputHints.glyph("Interact") or "[E]"
		if scheme == "Keyboard" then
			return `Hold {glyph} or [Space] to skip`
		end
		return `Hold {glyph} to skip`
	end
	return if scheme == "Touch" then "Tap Skip again to skip" else InputHints.format("Interact", "Skip")
end

local function setSkipHint(visible: boolean, mode: ("press" | "hold")?)
	local label = skipLabel
	if not label then
		return
	end
	if visible then
		local shown: "press" | "hold" = mode or "press"
		hintMode = shown
		label.Text = hintText(shown)
	else
		hintMode = "none"
	end
	tween(label, 0.2, { TextTransparency = if visible then 0 else 1 })
end

-- The hold's progress bar: nil hides it, 0..1 fills it.
local function setMeter(progress: number?)
	local track, fill = meterTrack, meterFill
	if not track or not fill then
		return
	end
	if progress == nil then
		track.Visible = false
		fill.Size = UDim2.fromScale(0, 1)
		return
	end
	track.Visible = true
	fill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
end

local function hideCard(instant: boolean?)
	cardToken += 1
	local box = cardBox
	local kicker, title, subtitle = cardKicker, cardTitle, cardSubtitle
	if not box or not kicker or not title or not subtitle then
		return
	end
	local seconds = if instant then 0 else Style.TitleCard.FadeOut
	for _, label in ipairs({ kicker, title, subtitle }) do
		if seconds > 0 then
			tween(label, seconds, { TextTransparency = 1, TextStrokeTransparency = 1 })
		else
			label.TextTransparency = 1
			label.TextStrokeTransparency = 1
		end
	end
end

local function showCard(spec: Types.CutsceneTitleCard)
	cardToken += 1
	local mine = cardToken
	local kicker, title, subtitle = cardKicker, cardTitle, cardSubtitle
	if not kicker or not title or not subtitle then
		return
	end
	kicker.Text = spec.kicker or ""
	kicker.Visible = spec.kicker ~= nil
	title.Text = spec.title
	subtitle.Text = spec.subtitle or ""
	subtitle.Visible = spec.subtitle ~= nil
	local card = Style.TitleCard
	for _, label in ipairs({ kicker, title, subtitle }) do
		tween(label, card.FadeIn, { TextTransparency = 0, TextStrokeTransparency = 0.6 })
	end
	task.delay(math.max(spec.duration - card.FadeOut, card.FadeIn), function()
		if cardToken == mine then
			hideCard(false)
		end
	end)
end

--------------------------------------------------------------------------
-- Ending
--------------------------------------------------------------------------

local function unbindSkipKeys()
	ContextActionService:UnbindAction(SKIP_ACTION)
end

-- Bars and subtitles away, black lifted, camera back to the player, and every
-- change the scene made to the world undone. `handover` eases an intro's last
-- frame into the player's own camera instead of cutting to it.
local function close(handover: boolean)
	token += 1
	local payload = current
	current = nil
	armedUntil = 0
	holdStart = nil
	holdToken += 1
	skipping = false
	local closing = token
	hideLine()
	hideCard(true)
	setSkipHint(false)
	setMeter(nil)
	unbindSkipKeys()
	-- Cut short, the scene's last frame may be any shot, anywhere: hand back from
	-- behind the player instead (a finished scene ends where the player is).
	if not handover then
		CameraController.lookFromBehindPlayer()
	end
	CameraController.stopCinematic(if handover and payload and payload.isIntro then Style.Handover else nil)
	CutsceneLighting.focus(nil, 0)
	CutsceneLighting.restore(if handover then 0.4 else 0)
	CutsceneSets.leaveAll()
	SoundController.endScene(if handover then 1.6 else 0.6)
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

-- Skip the scene now. An intro dips to black first (its sets and lighting
-- change behind it); an ordinary scene ends at once.
local function skipNow(payload: Types.CutscenePayload)
	local id = payload.id :: string
	if payload.isIntro ~= true then
		close(false)
		finishedEvent:Fire(id, true)
		return
	end
	if skipping then
		return
	end
	skipping = true
	holdStart = nil
	setMeter(nil)
	setSkipHint(false)
	local mine = token
	local black = fade
	if black then
		tween(black, Style.SkipDip, { BackgroundTransparency = 0 })
	end
	task.delay(Style.SkipDip, function()
		if mine ~= token then
			return -- the server ended it meanwhile
		end
		close(false)
		finishedEvent:Fire(id, true)
	end)
end

--------------------------------------------------------------------------
-- The hold that skips an intro
--------------------------------------------------------------------------

local function cancelHold()
	holdStart = nil
	holdToken += 1
	if not skipping then
		setMeter(nil)
	end
end

local function beginHold()
	local payload = current
	if not payload or payload.skippable == false or holdStart or skipping then
		return
	end
	local started = os.clock()
	holdStart = started
	holdToken += 1
	local mine = holdToken
	setSkipHint(true, "hold")
	setMeter(0)
	task.spawn(function()
		while holdStart == started and holdToken == mine and current == payload do
			local progress = (os.clock() - started) / Config.Cutscene.SkipHoldSeconds
			setMeter(progress)
			if progress >= 1 then
				holdStart = nil
				skipNow(payload)
				return
			end
			task.wait()
		end
	end)
end

-- Space (Config.Cutscene.SkipKeys) holds too, while an intro plays.
local function bindSkipKeys()
	local keys: { Enum.KeyCode } = {}
	for _, name in ipairs(Config.Cutscene.SkipKeys) do
		local key = (Enum.KeyCode :: any)[name]
		if key then
			table.insert(keys, key)
		end
	end
	if #keys == 0 then
		return
	end
	ContextActionService:BindAction(SKIP_ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			beginHold()
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			cancelHold()
		end
		return Enum.ContextActionResult.Sink
	end, false, table.unpack(keys))
end

--------------------------------------------------------------------------
-- Shots
--------------------------------------------------------------------------

-- One shot, started now: its set, look and focus, the camera move, its dips,
-- its sound and actions and card, and its subtitle cues (each timed from the
-- start of the shot). Anything still pending when the scene is replaced or closed
-- checks `sceneToken` and does nothing.
local function runShot(shot: Types.CutsceneShot, sceneToken: number)
	local camera = shot.camera
	local set = shot.set
	local from = pointFrame(set, camera.from)
	local to = if camera.to then pointFrame(set, camera.to) else from

	CutsceneSets.enter(set)
	CutsceneLighting.apply(shot.lighting, 0)
	CutsceneLighting.focus(shot.focus, shot.duration)
	CameraController.playShot(from, to, shot.duration, camera.fieldOfView, {
		fieldOfViewTo = camera.fieldOfViewTo,
		ease = camera.ease,
		handheld = camera.handheld,
		mouseLook = shot.mouseLook,
	})

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

	-- Sound: a bed the shot still lists carries on; one it doesn't fades out.
	local listed: { [string]: boolean } = {}
	for _, cue in ipairs(shot.sounds or {}) do
		listed[cue.cue] = true
	end
	SoundController.keepBeds(listed, Style.BedFade)
	for _, cue in ipairs(shot.sounds or {}) do
		later(sceneToken, cue.at, function()
			if cue.stop then
				SoundController.stopCue(cue.cue, cue.fade)
			else
				SoundController.playCue(cue.cue, { volume = cue.volume, fade = cue.fade, from = cue.from })
			end
		end)
	end

	for _, action in ipairs(shot.actions or {}) do
		later(sceneToken, action.at, function()
			CutsceneSets.act(set, action.name, action.args)
		end)
	end

	local card = shot.titleCard
	if card then
		later(sceneToken, card.at, function()
			showCard(card)
		end)
	end

	for _, line in ipairs(shot.lines or {}) do
		later(sceneToken, line.at, function()
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

-- Everything a scene needs ready before its first frame: the sets it is framed
-- in, and its recordings loaded. The screen is black meanwhile.
local function prepare(shots: { Types.CutsceneShot })
	local sets: { string } = {}
	local cues: { string } = {}
	for _, shot in ipairs(shots) do
		if shot.set then
			table.insert(sets, shot.set)
		end
		for _, cue in ipairs(shot.sounds or {}) do
			table.insert(cues, cue.cue)
		end
	end
	CutsceneSets.prepare(sets)
	-- Sounds load off the network: wait for them, but not for long.
	local loaded = false
	task.spawn(function()
		SoundController.preload(cues)
		loaded = true
	end)
	local waited = 0
	while not loaded and waited < Style.PreloadWait do
		waited += task.wait()
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
	if current then
		-- Replacing a scene: what it made is taken down first.
		CutsceneSets.leaveAll()
		CutsceneLighting.restore(0)
		SoundController.endScene(0.2)
		unbindSkipKeys()
	end
	token += 1
	local sceneToken = token
	current = payload
	armedUntil = 0
	holdStart = nil
	holdToken += 1
	skipping = false
	screen.Enabled = true
	hideLine()
	hideCard(true)
	setSkipHint(false)
	setMeter(nil)
	local bar = UDim2.new(1, 0, Style.Letterbox, 0)
	tween(top, Style.BarTime, { Size = bar })
	tween(bottom, Style.BarTime, { Size = bar })

	-- A scene that opens from black is black from this moment, so nothing that
	-- has to be built or loaded first is ever seen.
	local first = shots[1]
	local black = fade
	if black and first.fadeIn and first.fadeIn > 0 then
		black.BackgroundTransparency = 0
	end

	local isIntro = payload.isIntro == true
	SoundController.beginScene(isIntro)
	if isIntro and payload.skippable ~= false then
		bindSkipKeys()
	end

	task.spawn(function()
		prepare(shots)
		if sceneToken ~= token then
			return
		end
		-- The last shot each set is used in: once past it, the set comes down.
		local lastUse: { [string]: number } = {}
		for index, shot in ipairs(shots) do
			if shot.set then
				lastUse[shot.set] = index
			end
		end

		-- Tell the player how to skip, once the scene has settled.
		if isIntro and payload.skippable ~= false then
			later(sceneToken, Style.IntroHintDelay, function()
				if not holdStart then
					setSkipHint(true, "hold")
					task.delay(Style.IntroHintSeconds, function()
						if sceneToken == token and not holdStart and hintMode == "hold" then
							setSkipHint(false)
						end
					end)
				end
			end)
		end

		local sceneStart = os.clock()
		local offset = 0
		for index, shot in ipairs(shots) do
			local untilShot = sceneStart + offset - os.clock()
			if untilShot > 0 then
				task.wait(untilShot)
			end
			if sceneToken ~= token then
				return
			end
			runShot(shot, sceneToken)
			for name, last in pairs(lastUse) do
				if last < index then
					lastUse[name] = nil
					CutsceneSets.release(name)
				end
			end
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
		close(true)
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
	close(false)
	return true
end

--[[
	The primary input while a scene plays. Always consumed (true): nothing
	behind a scene should react. On an intro it starts the hold that skips (and
	`handlePrimaryReleased` ends it); on any other scene the first press arms the
	skip and shows the hint, and a second within the window skips.
]]
function CutsceneView.handlePrimary(): boolean
	local payload = current
	if not payload then
		return false
	end
	if payload.skippable == false then
		return true
	end
	if payload.isIntro == true then
		beginHold()
		return true
	end
	local now = os.clock()
	if now < armedUntil then
		skipNow(payload)
		return true
	end
	armedUntil = now + Config.Cutscene.SkipConfirmWindow
	setSkipHint(true, "press")
	local armedAt = armedUntil
	task.delay(Config.Cutscene.SkipConfirmWindow, function()
		if armedUntil == armedAt and current == payload then
			setSkipHint(false)
		end
	end)
	return true
end

-- The primary input let go: a hold that hadn't finished is cancelled.
function CutsceneView.handlePrimaryReleased()
	if current and current.isIntro == true then
		cancelHold()
	end
end

-- Label for the touch primary button while a scene plays (nil hides it).
function CutsceneView.primaryLabel(): string?
	local payload = current
	if not payload or payload.skippable == false then
		return nil
	end
	return if payload.isIntro == true then "Hold to skip" else "Skip"
end

-- True while the touch primary button should act on press and release (the
-- intro's hold) rather than on a tap.
function CutsceneView.primaryHold(): boolean
	local payload = current
	return payload ~= nil and payload.isIntro == true and payload.skippable ~= false
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

	-- The title card: a small line over a large one over a small one, centred a
	-- little below the middle of the picture.
	local card = Style.TitleCard
	local cardFrame = Instance.new("Frame")
	cardFrame.Name = "TitleCard"
	cardFrame.BackgroundTransparency = 1
	cardFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	cardFrame.Position = UDim2.fromScale(0.5, 0.5 + card.CentreOffset)
	cardFrame.Size = UDim2.new(0.9, 0, 0, 0)
	cardFrame.AutomaticSize = Enum.AutomaticSize.Y
	cardFrame.ZIndex = 4
	cardFrame.Parent = screen
	local cardWidth = Instance.new("UISizeConstraint")
	cardWidth.MaxSize = Vector2.new(card.MaxWidth, math.huge)
	cardWidth.Parent = cardFrame
	local cardList = Instance.new("UIListLayout")
	cardList.SortOrder = Enum.SortOrder.LayoutOrder
	cardList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cardList.Padding = UDim.new(0, 6)
	cardList.Parent = cardFrame
	cardBox = cardFrame

	local function cardLine(name: string, order: number, size: number, font: Enum.Font, color: Color3): TextLabel
		local label = Components.text({
			name = name,
			text = "",
			size = UDim2.new(1, 0, 0, size + 6),
			font = font,
			textSize = size,
			color = color,
			xAlign = Enum.TextXAlignment.Center,
			parent = cardFrame,
		})
		label.LayoutOrder = order
		label.TextTransparency = 1
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.TextStrokeTransparency = 1
		label.ZIndex = 4
		return label
	end
	cardKicker = cardLine("Kicker", 1, card.KickerSize, Theme.FontBold, Theme.Accent)
	cardTitle = cardLine("Title", 2, card.TitleSize, Theme.FontBold, Theme.TextPrimary)
	cardSubtitle = cardLine("Subtitle", 3, card.SubtitleSize, Theme.Font, Theme.TextSecondary)

	-- The skip hint, small, in the bottom bar's right corner.
	local skip = Components.text({
		name = "SkipHint",
		text = "",
		size = UDim2.fromOffset(300, 18),
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

	-- The hold's meter, above the hint.
	local meter = Style.SkipMeter
	local track = Instance.new("Frame")
	track.Name = "SkipMeter"
	track.BackgroundColor3 = Theme.TextPrimary
	track.BackgroundTransparency = 0.8
	track.BorderSizePixel = 0
	track.AnchorPoint = Vector2.new(1, 1)
	track.Position = UDim2.new(1, -meter.Margin, 1, -meter.BottomGap)
	track.Size = UDim2.fromOffset(meter.Width, meter.Height)
	track.Visible = false
	track.ZIndex = 3
	track.Parent = screen
	meterTrack = track
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Theme.Accent
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = 4
	fill.Parent = track
	meterFill = fill

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
		if hintMode ~= "none" and (holdStart or os.clock() < armedUntil or hintMode == "hold") then
			setSkipHint(true, hintMode :: "press" | "hold")
		end
	end)
end

return CutsceneView
