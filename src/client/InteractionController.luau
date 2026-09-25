--!strict
--[[
	InteractionController
	Client-side scanning for nearby interactables, prompt display, and
	dispatching interaction requests to the server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Signals = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signals"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Interactable = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Interactable"))

local InteractionController = {}

local player = Players.LocalPlayer

local currentTarget: Instance? = nil
local currentInfo: Types.InteractionPromptData? = nil
local promptChanged: BindableEvent = Instance.new("BindableEvent")
local paused = false
local requestEvent: RemoteEvent? = nil

function InteractionController.onPromptChanged(): BindableEvent
	return promptChanged
end

function InteractionController.getCurrent(): Types.InteractionPromptData?
	return currentInfo
end

local function getRoot(): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- M6: among interactables in range, prefer the one the player is facing.
-- Distance is scaled by how far off the camera's heading the object lies
-- (x1 dead ahead, x1.9 to the side, x2.8 directly behind), so on a crowded
-- desk the item you are looking at wins over one that is merely closer.
local function facingWeight(offset: Vector3): number
	local camera = workspace.CurrentCamera
	if not camera then
		return 1
	end
	local look = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if look.Magnitude < 0.01 or flat.Magnitude < 0.01 then
		return 1
	end
	return 1 + 0.9 * (1 - look.Unit:Dot(flat.Unit))
end

local function findNearest(): (Instance?, number?)
	local root = getRoot()
	if not root then
		return nil, nil
	end
	local origin = root.Position
	local best: Instance? = nil
	local bestDist: number? = nil
	local bestScore = math.huge
	for _, instance in ipairs(Interactable.getAll()) do
		local part = Interactable.getPart(instance)
		if part and part:IsDescendantOf(workspace) then
			local offset = part.Position - origin
			local dist = offset.Magnitude
			if dist <= Config.Interaction.MaxPromptDistance then
				local score = dist * facingWeight(offset)
				if score < bestScore then
					best = instance
					bestDist = dist
					bestScore = score
				end
			end
		end
	end
	return best, bestDist
end

local function buildPrompt(instance: Instance): Types.InteractionPromptData?
	local descriptor = Interactable.describe(instance)
	if not descriptor then
		return nil
	end
	return {
		instance = descriptor.instance,
		kind = descriptor.kind,
		label = descriptor.label,
		key = Config.Interaction.PrimaryKey,
	}
end

local function setTarget(instance: Instance?)
	if currentTarget == instance then
		return
	end
	currentTarget = instance
	if instance then
		currentInfo = buildPrompt(instance)
	else
		currentInfo = nil
	end
	promptChanged:Fire(currentInfo)
end

local function scan()
	if paused then
		return
	end
	local nearest = findNearest()
	setTarget(nearest)
end

-- Invoked by the central input router. No input binding happens here.
function InteractionController.requestInteract()
	if paused then
		return
	end
	local info = currentInfo
	if not info or not requestEvent then
		return
	end
	requestEvent:FireServer(info.instance, info.kind)
end

-- Suspend scanning and prompt while a modal (e.g. evidence panel) is open.
function InteractionController.pauseScan()
	paused = true
	setTarget(nil)
end

function InteractionController.resumeScan()
	paused = false
end

function InteractionController.start()
	requestEvent = Signals.wait(Signals.Names.InteractionRequest)

	-- Rescan at a fixed cadence rather than every frame.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= Config.Interaction.ScanInterval then
			accumulator = 0
			scan()
		end
	end)
end

return InteractionController
