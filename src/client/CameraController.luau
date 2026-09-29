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

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local CameraController = {}

local player = Players.LocalPlayer
local camera: Camera? = nil
local blendToken = 0

local HIDE_AVATAR_STEP = "MysteryCase_HideAvatarWhileExamining"

local mode: "Explore" | "Examine" | "Cinematic" = "Explore"
local focusPart: BasePart? = nil
local savedMaxZoom: number? = nil
local savedMinZoom: number? = nil
local savedCameraType: Enum.CameraType? = nil
-- Phase 5.1: a scripted shot may set its own field of view; the player's is
-- put back when the cinematic ends.
local savedFieldOfView: number? = nil

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

	local eye = focus - toward * distance + side * (distance * 0.18) + Vector3.new(0, size.Y * 0.25, 0)
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
	Phase 5.1: one scripted shot -- the camera moves once from `from` to
	`to` over `duration` seconds (eased in and out) and holds there, rather
	than drifting back and forth like playCinematic. `to == from` is a still
	shot. Consecutive shots chain: each call replaces the last, and
	stopCinematic hands the camera (and its field of view) back.
]]
function CameraController.playShot(from: CFrame, to: CFrame, duration: number, fieldOfView: number?)
	setExplore()
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
	cam.FieldOfView = fieldOfView or savedFieldOfView :: number
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = from
	setMovementEnabled(false)
	local length = math.max(duration, 1e-3)
	local startClock = os.clock()
	task.spawn(function()
		while token == cinematicToken do
			local alpha = math.min((os.clock() - startClock) / length, 1)
			local eased = (1 - math.cos(alpha * math.pi)) / 2
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = from:Lerp(to, eased)
			if alpha >= 1 then
				return
			end
			RunService.RenderStepped:Wait()
		end
	end)
end

function CameraController.stopCinematic()
	if mode ~= "Cinematic" then
		return
	end
	cinematicToken += 1
	mode = "Explore"
	local cam = getCamera()
	cam.CameraType = savedCameraType or Enum.CameraType.Custom
	savedCameraType = nil
	if savedFieldOfView then
		cam.FieldOfView = savedFieldOfView
		savedFieldOfView = nil
	end
	setMovementEnabled(true)
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
