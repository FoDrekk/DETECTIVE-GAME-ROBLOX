--!strict
--[[
	CameraController
	Third-person exploration camera with clean blends for future cinematic
	investigation shots. Phase 1: normal exploration plus an examine framing
	that smoothly returns to explore when dismissed.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local CameraController = {}

local player = Players.LocalPlayer
local camera: Camera? = nil
local blendToken = 0

local HIDE_AVATAR_STEP = "MysteryCase_HideAvatarWhileExamining"
local HIDE_IN_SHOT_STEP = "MysteryCase_HideAvatarInShot"

local mode: "Explore" | "Examine" | "Cinematic" = "Explore"
local focusPart: BasePart? = nil
local savedMaxZoom: number? = nil
local savedMinZoom: number? = nil
local savedCameraType: Enum.CameraType? = nil
-- Phase 5.1: a scripted shot may set its own field of view; the player's is
-- put back when the cinematic ends.
local savedFieldOfView: number? = nil
-- Phase 5.4: set while a scripted shot has hidden the investigator's avatar.
local shotHidesAvatar = false

local BLEND_OUT_STEP = "MysteryCase_CameraBlendOut"
local blendOutToken = 0

-- Phase 5.5: a shot that hands the look to the player. Yaw and pitch (radians)
-- are offsets from the shot's own framing; `lookStick` is a gamepad's right
-- stick; `mouseLocked` remembers that this module took the mouse.
local lookYaw = 0
local lookPitch = 0
local lookStick = Vector2.zero
local lookConnection: RBXScriptConnection? = nil
local mouseLocked = false
local LOOK_SENSITIVITY = 0.0032
local LOOK_STICK_SPEED = 2.2
local LOOK_PITCH_LIMIT = math.rad(62)

-- Phase 5.5: a brief shake (a lift starting or stopping): amplitude in studs,
-- decaying to nothing at `shakeUntil`.
local shakeAmplitude = 0
local shakeStart = 0
local shakeUntil = 0

-- The close-up framing sits near the player, so their own avatar would fill
-- the shot. Re-applied every frame after the camera step, because the default
-- camera scripts also write LocalTransparencyModifier.
local function setAvatarHidden(hidden: boolean)
	local character = player.Character
	if not character then
		return
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			descendant.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

local function getCamera(): Camera
	if not camera then
		if not workspace.CurrentCamera then
			workspace:GetPropertyChangedSignal("CurrentCamera"):Wait()
		end
		camera = workspace.CurrentCamera
	end
	return camera :: Camera
end

-- Blend a CFrame over a duration; invalidates any in-flight blend.
local function blendTo(target: CFrame, duration: number)
	blendToken += 1
	local token = blendToken
	local cam = getCamera()
	local from = cam.CFrame
	task.spawn(function()
		local startClock = os.clock()
		while os.clock() - startClock < duration do
			if token ~= blendToken then
				return
			end
			local alpha = math.min((os.clock() - startClock) / duration, 1)
			local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			cam.CFrame = from:Lerp(target, eased)
			RunService.RenderStepped:Wait()
		end
	end)
end

local function setExplore()
	-- Only a close-up is undone here; a cinematic is ended by stopCinematic.
	if mode ~= "Examine" then
		return
	end
	mode = "Explore"
	focusPart = nil
	RunService:UnbindFromRenderStep(HIDE_AVATAR_STEP)
	setAvatarHidden(false)

	local cam = getCamera()
	if savedCameraType then
		cam.CameraType = savedCameraType
	end
	if savedMaxZoom then
		player.CameraMaxZoomDistance = savedMaxZoom
	end
	if savedMinZoom then
		player.CameraMinZoomDistance = savedMinZoom
	end
	savedCameraType = nil
	savedMaxZoom = nil
	savedMinZoom = nil
end

-- Enter the close-up mode (scriptable camera, hidden avatar, tight zoom) and
-- blend to `target`, keeping `part` as the focus that ends the mode if it is
-- destroyed.
local function frame(part: BasePart, target: CFrame)
	CameraController.stopCinematic()
	if savedMaxZoom == nil then
		savedMaxZoom = player.CameraMaxZoomDistance
		savedMinZoom = player.CameraMinZoomDistance
		savedCameraType = getCamera().CameraType
	end

	if mode ~= "Examine" then
		RunService:BindToRenderStep(HIDE_AVATAR_STEP, Enum.RenderPriority.Camera.Value + 1, function()
			setAvatarHidden(true)
		end)
	end
	mode = "Examine"
	focusPart = part

	getCamera().CameraType = Enum.CameraType.Scriptable
	blendTo(target, Config.Camera.ExamineBlendTime)

	player.CameraMaxZoomDistance = 6
	player.CameraMinZoomDistance = 4
end

-- Blend to a framed view of a target part, framed from the player's side so
-- the shot shows the object against the room rather than against a wall.
function CameraController.examine(part: BasePart)
	if not part then
		return
	end

	local size = part.Size
	local distance = math.max(size.Magnitude * 0.9, 4)
	local focus = part.Position + Vector3.new(0, size.Y * 0.4, 0)

	-- Choose the approach direction: from the player toward the object, so the
	-- camera sits on the player's side. Falls back to the object's own
	-- LookVector only when no character is available.
	local character = player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	local toward: Vector3
	if playerRoot and playerRoot:IsA("BasePart") then
		toward = Vector3.new(part.Position.X - playerRoot.Position.X, 0, part.Position.Z - playerRoot.Position.Z)
	else
		toward = part.CFrame.LookVector
	end
	if toward.Magnitude < 0.1 then
		toward = part.CFrame.LookVector
	end
	toward = toward.Unit

	-- Offset slightly to one side (like a three-quarter view) so the object
	-- is not dead-centre and the evidence panel can sit beside it.
	local side = toward:Cross(Vector3.yAxis)
	if side.Magnitude > 0.01 then
		side = side.Unit
	else
		side = Vector3.xAxis
	end

	-- A flat thing (a phone, a sheet of paper) is looked down on; from its own
	-- height the desk edge hides it.
	local lift = if size.Y < 1 then distance * 0.6 else size.Y * 0.25
	local eye = focus - toward * distance + side * (distance * 0.18) + Vector3.new(0, lift, 0)

	-- Keep the shot in the room: a big object (a shelving unit) frames from far
	-- enough back to end up behind a wall, or behind the cabinet next to it.
	-- Look out from where the ray leaves the object's own box (so its collider
	-- and contents don't count) and come in to just short of the first solid
	-- thing. With no room left for a shot, use the player's own eye line: they
	-- are on the side of the object they could reach.
	local offset = eye - focus
	local dir = offset.Unit
	local localFocus = part.CFrame:PointToObjectSpace(focus)
	local localDir = part.CFrame:VectorToObjectSpace(dir)
	local exit = math.huge
	for _, axis in ipairs({ "X", "Y", "Z" }) do
		local d = (localDir :: any)[axis]
		if math.abs(d) > 1e-6 then
			local half = (size :: any)[axis] / 2
			exit = math.min(exit, ((if d > 0 then half else -half) - (localFocus :: any)[axis]) / d)
		end
	end
	exit = math.max(exit, 0) + 0.05
	if exit < offset.Magnitude then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = if character then { part, character } else { part }
		params.RespectCanCollide = true
		local hit = workspace:Raycast(focus + dir * exit, dir * (offset.Magnitude - exit), params)
		if hit then
			local reach = (hit.Position - focus).Magnitude - 0.6
			if reach >= exit + 1 then
				eye = focus + dir * reach
			elseif playerRoot and playerRoot:IsA("BasePart") then
				eye = playerRoot.Position + Vector3.new(0, 2.2, 0)
			end
		end
	end
	frame(part, CFrame.lookAt(eye, focus))
end

-- M6: frame a person's face for a conversation. The shot is taken from the
-- player's side of the subject (they turn to face the player), slightly off
-- axis like an over-the-shoulder shot. `part` is the subject's full-height
-- hitbox; the face sits near its top.
function CameraController.faceSubject(part: BasePart)
	if not part then
		return
	end

	local character = player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	local face = part.Position + Vector3.new(0, part.Size.Y * 0.32, 0)
	local toward = if playerRoot and playerRoot:IsA("BasePart")
		then Vector3.new(playerRoot.Position.X - face.X, 0, playerRoot.Position.Z - face.Z)
		else part.CFrame.LookVector
	if toward.Magnitude < 0.1 then
		toward = part.CFrame.LookVector
	end
	toward = toward.Unit
	local side = toward:Cross(Vector3.yAxis).Unit

	local conv = Config.Camera.Conversation
	local eye = face + toward * conv.Distance + side * conv.SideOffset + Vector3.new(0, conv.Height, 0)
	-- Aim below the face so it sits in the upper third, clear of the
	-- dialogue panel.
	frame(part, CFrame.lookAt(eye, face - Vector3.new(0, conv.AimDrop, 0)))
end

-- M6: a slow, looping camera drift between two framings (the title
-- screen's backdrop). Ping-pongs with sine easing until stopCinematic.
local cinematicToken = 0

-- M8: while a cinematic holds the camera, the character stays put: moving
-- with the camera elsewhere would walk the player somewhere they can't see.
-- The default PlayerModule may be absent (a custom character setup), in
-- which case movement is simply left alone.
local function setMovementEnabled(enabled: boolean)
	local scripts = player:FindFirstChildOfClass("PlayerScripts")
	local module = scripts and scripts:FindFirstChild("PlayerModule")
	if not module or not module:IsA("ModuleScript") then
		return
	end
	pcall(function()
		local controls = (require :: any)(module):GetControls()
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end)
end

function CameraController.playCinematic(from: CFrame, to: CFrame, duration: number)
	setExplore()
	-- A new shot while one is already playing keeps the camera type saved
	-- before the first, or stopCinematic would restore Scriptable.
	if mode ~= "Cinematic" then
		savedCameraType = getCamera().CameraType
	end
	mode = "Cinematic"
	cinematicToken += 1
	local token = cinematicToken
	local cam = getCamera()
	if savedFieldOfView then
		-- Following a scripted shot that set its own: back to the player's.
		cam.FieldOfView = savedFieldOfView
	end
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = from
	setMovementEnabled(false)
	local startClock = os.clock()
	task.spawn(function()
		while token == cinematicToken do
			local t = ((os.clock() - startClock) / duration) % 2
			local alpha = if t > 1 then 2 - t else t
			local eased = (1 - math.cos(alpha * math.pi)) / 2
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = from:Lerp(to, eased)
			RunService.RenderStepped:Wait()
		end
	end)
end

--[[
	Phase 5.5: what a scripted shot can ask of the camera beyond a move.
	  * fieldOfViewTo -- the field of view the move ends on (a push-in or pull-out);
	  * ease -- the move's curve: "InOut" (the default), "Out", "In" or "Linear";
	  * handheld -- 0 (locked off) to 1 (a running camera): a slow drift and a fine
	    tremor, the way a person carrying a camera never quite holds it;
	  * mouseLook -- the camera stays at the shot's own position and the player
	    turns it (mouse, touch drag or right stick). Presence, not control: they
	    still can't move.
]]
export type ShotOptions = {
	fieldOfViewTo: number?,
	ease: string?,
	handheld: number?,
	mouseLook: boolean?,
}

-- Progress (0..1) through a move, for each named curve.
local function easeProgress(name: string?, alpha: number): number
	if name == "Linear" then
		return alpha
	elseif name == "Out" then
		return math.sin(alpha * math.pi / 2)
	elseif name == "In" then
		return 1 - math.cos(alpha * math.pi / 2)
	end
	return (1 - math.cos(alpha * math.pi)) / 2
end

-- A hand-held camera's offset at time `t` (seconds): a low drift plus a fine
-- tremor, scaled by `amount` (0..1). Deterministic noise, so a replay of a shot
-- moves the same way.
local function handheldOffset(t: number, amount: number): CFrame
	local drift = 0.012 * amount
	local tremor = 0.0035 * amount
	local pitch = math.noise(t * 0.7, 11.3) * drift * 2 + math.noise(t * 6.1, 4.7) * tremor * 2
	local yaw = math.noise(t * 0.6, 29.1) * drift * 2 + math.noise(t * 5.4, 17.9) * tremor * 2
	local roll = math.noise(t * 0.5, 41.7) * drift * 0.8
	local sway = Vector3.new(math.noise(t * 0.8, 3.1), math.noise(t * 0.9, 8.3), 0) * 0.06 * amount
	return CFrame.new(sway) * CFrame.Angles(pitch, yaw, roll)
end

local function stopLooking()
	local connection = lookConnection
	if connection then
		connection:Disconnect()
		lookConnection = nil
	end
	if mouseLocked then
		mouseLocked = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
	lookYaw = 0
	lookPitch = 0
	lookStick = Vector2.zero
end

-- Begin handing the look to the player. Consecutive shots that both hand it over
-- keep the way they have turned (a cut inside the lift doesn't snap their view back).
local function startLooking()
	if lookConnection then
		return
	end
	lookYaw = 0
	lookPitch = 0
	if UserInputService.MouseEnabled then
		mouseLocked = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	end
	lookConnection = UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			lookYaw -= input.Delta.X * LOOK_SENSITIVITY
			lookPitch = math.clamp(lookPitch - input.Delta.Y * LOOK_SENSITIVITY, -LOOK_PITCH_LIMIT, LOOK_PITCH_LIMIT)
		elseif input.UserInputType == Enum.UserInputType.Touch and not processed then
			lookYaw -= input.Delta.X * LOOK_SENSITIVITY * 1.4
			lookPitch = math.clamp(lookPitch - input.Delta.Y * LOOK_SENSITIVITY * 1.4, -LOOK_PITCH_LIMIT, LOOK_PITCH_LIMIT)
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			lookStick = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
end

--[[
	Phase 5.1: one scripted shot -- the camera moves once from `from` to
	`to` over `duration` seconds (eased in and out) and holds there, rather
	than drifting back and forth like playCinematic. `to == from` is a still
	shot. Consecutive shots chain: each call replaces the last, and
	stopCinematic hands the camera (and its field of view) back.
	`options` (Phase 5.5) adds a field-of-view move, another ease, a hand-held
	sway, and turning the camera over to the player.
]]
function CameraController.playShot(from: CFrame, to: CFrame, duration: number, fieldOfView: number?, options: ShotOptions?)
	setExplore()
	blendOutToken += 1
	RunService:UnbindFromRenderStep(BLEND_OUT_STEP)
	if mode ~= "Cinematic" then
		savedCameraType = getCamera().CameraType
	end
	mode = "Cinematic"
	cinematicToken += 1
	local token = cinematicToken
	local cam = getCamera()
	if savedFieldOfView == nil then
		savedFieldOfView = cam.FieldOfView
	end
	local opts = options or {}
	local startFov = fieldOfView or savedFieldOfView :: number
	local endFov = opts.fieldOfViewTo or startFov
	cam.FieldOfView = startFov
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = from
	-- Phase 5.4: the investigator is behind the camera, not in the shot: a
	-- scene's cameras are placed in the office wherever they happen to be
	-- standing. Shown again when the scene hands the camera back.
	shotHidesAvatar = true
	setAvatarHidden(true)
	-- Every frame, as for a close-up: the default camera scripts show the avatar
	-- again, and a shot from the player's own eye line (the lift) then looks out
	-- through their hair.
	RunService:UnbindFromRenderStep(HIDE_IN_SHOT_STEP)
	RunService:BindToRenderStep(HIDE_IN_SHOT_STEP, Enum.RenderPriority.Camera.Value + 1, function()
		setAvatarHidden(true)
	end)
	setMovementEnabled(false)
	if opts.mouseLook then
		startLooking()
	else
		stopLooking()
	end
	local handheld = math.clamp(opts.handheld or 0, 0, 1)
	local looking = opts.mouseLook == true
	local baseYaw, basePitch = 0, 0
	if looking then
		basePitch, baseYaw = from:ToOrientation()
	end
	local length = math.max(duration, 1e-3)
	local startClock = os.clock()
	-- A still shot with nothing alive in it needs no frame loop after the first.
	local alive = looking or handheld > 0 or to ~= from or endFov ~= startFov
	task.spawn(function()
		local lastFrame = startClock
		while token == cinematicToken do
			local now = os.clock()
			local elapsed = now - startClock
			local dt = now - lastFrame
			lastFrame = now
			local alpha = math.min(elapsed / length, 1)
			local eased = easeProgress(opts.ease, alpha)
			local frame = from:Lerp(to, eased)
			if looking then
				-- The stick turns the view at a steady rate; the mouse and a drag
				-- have already moved the offsets.
				if lookStick.Magnitude > 0.15 then
					lookYaw -= lookStick.X * LOOK_STICK_SPEED * dt
					lookPitch = math.clamp(lookPitch + lookStick.Y * LOOK_STICK_SPEED * dt, -LOOK_PITCH_LIMIT, LOOK_PITCH_LIMIT)
				end
				frame = CFrame.new(frame.Position) * CFrame.fromOrientation(basePitch + lookPitch, baseYaw + lookYaw, 0)
			end
			if handheld > 0 then
				frame = frame * handheldOffset(elapsed, handheld)
			end
			if shakeAmplitude > 0 and now < shakeUntil then
				local left = (shakeUntil - now) / math.max(shakeUntil - shakeStart, 1e-3)
				local a = shakeAmplitude * left
				frame = frame * CFrame.new(math.noise(now * 31, 1.7) * a, math.noise(now * 29, 5.3) * a, 0)
			end
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = frame
			if endFov ~= startFov then
				cam.FieldOfView = startFov + (endFov - startFov) * eased
			end
			if not alive or (alpha >= 1 and not looking and handheld <= 0 and shakeUntil <= now) then
				return
			end
			RunService.RenderStepped:Wait()
		end
	end)
end

-- Phase 5.5: shake the current shot for `seconds` (a lift shuddering as it
-- starts). Amplitude is in studs and dies away over the shake.
function CameraController.shake(amplitude: number, seconds: number)
	shakeAmplitude = amplitude
	shakeStart = os.clock()
	shakeUntil = shakeStart + seconds
end

-- Phase 5.5: the look the player has turned the camera to (yaw, pitch offsets in
-- radians), for a set that reacts to where they look (a mirror).
function CameraController.getLook(): (number, number)
	return lookYaw, lookPitch
end

--[[
	Hand the camera back. With `blend` seconds the last scripted frame eases into
	whatever the player's own camera makes of the moment (it looks the way the
	scene ended), instead of jumping.
]]
function CameraController.stopCinematic(blend: number?)
	if mode ~= "Cinematic" then
		return
	end
	local cam = getCamera()
	local lastFrame = cam.CFrame
	local lastFov = cam.FieldOfView
	cinematicToken += 1
	mode = "Explore"
	stopLooking()
	shakeAmplitude = 0
	cam.CameraType = savedCameraType or Enum.CameraType.Custom
	savedCameraType = nil
	if savedFieldOfView then
		cam.FieldOfView = savedFieldOfView
		savedFieldOfView = nil
	end
	if shotHidesAvatar then
		shotHidesAvatar = false
		RunService:UnbindFromRenderStep(HIDE_IN_SHOT_STEP)
		setAvatarHidden(false)
	end
	setMovementEnabled(true)

	local seconds = blend or 0
	if seconds > 0 then
		blendOutToken += 1
		local token = blendOutToken
		local startClock = os.clock()
		-- The field of view the player's camera goes back to (their own; nothing
		-- rewrites it each frame, so it is read once, not from the blend).
		local targetFov = cam.FieldOfView
		RunService:BindToRenderStep(BLEND_OUT_STEP, Enum.RenderPriority.Camera.Value + 1, function()
			if token ~= blendOutToken or mode ~= "Explore" then
				-- Something else has taken the camera: leave it alone.
				RunService:UnbindFromRenderStep(BLEND_OUT_STEP)
				return
			end
			local alpha = (os.clock() - startClock) / seconds
			if alpha >= 1 then
				cam.FieldOfView = targetFov
				RunService:UnbindFromRenderStep(BLEND_OUT_STEP)
				return
			end
			local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			-- The player's own camera has just been placed this frame; ease from the
			-- scripted frame toward it.
			cam.CFrame = lastFrame:Lerp(cam.CFrame, eased)
			cam.FieldOfView = lastFov + (targetFov - lastFov) * eased
		end)
	end
end

--[[
	Point the camera from just behind the player, level with the way they face.
	Roblox's own camera takes its direction from wherever the camera last looked,
	so a scene cut short (skipped, or ended by the server) calls this before
	handing back; otherwise the player starts looking down from the angle of a
	shot that may have been framed far away.
]]
function CameraController.lookFromBehindPlayer()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local focus = root.Position + Vector3.new(0, 1.5, 0)
	local facing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if facing.Magnitude < 1e-3 then
		return
	end
	getCamera().CFrame = CFrame.lookAt(focus - facing.Unit * 8 + Vector3.new(0, 1.5, 0), focus)
end

function CameraController.stopExamining()
	setExplore()
end

function CameraController.getMode(): string
	return mode
end

function CameraController.start()
	getCamera().CameraType = Enum.CameraType.Custom

	-- Keep framing stable if a focus part is destroyed.
	RunService.RenderStepped:Connect(function()
		if mode == "Examine" and focusPart and not focusPart:IsDescendantOf(workspace) then
			setExplore()
		end
	end)
end

return CameraController
