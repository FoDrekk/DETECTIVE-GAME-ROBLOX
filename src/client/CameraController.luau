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

local mode: "Explore" | "Examine" = "Explore"
local focusPart: BasePart? = nil
local savedMaxZoom: number? = nil
local savedMinZoom: number? = nil
local savedCameraType: Enum.CameraType? = nil

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
	if mode == "Explore" then
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

-- Blend to a framed view of a target part.
function CameraController.examine(part: BasePart)
	if not part then
		return
	end

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

	local cam = getCamera()
	cam.CameraType = Enum.CameraType.Scriptable

	local size = part.Size
	local distance = math.max(size.Magnitude * 0.9, 4)
	local focus = part.Position
	local target = CFrame.lookAt(
		focus + Vector3.new(0, size.Y * 0.4, 0) - (part.CFrame.LookVector * distance),
		focus
	)
	blendTo(target, Config.Camera.ExamineBlendTime)

	player.CameraMaxZoomDistance = 6
	player.CameraMinZoomDistance = 4
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
