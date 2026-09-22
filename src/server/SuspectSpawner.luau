--!strict
--[[
	SuspectSpawner
	Runtime placement of physical NPC representations for suspects that
	author an `npcPlacement` (Types.SuspectDefinition). Purely staging: no
	suspect id is hardcoded here -- every suspect with npcPlacement gets an
	NPC; a suspect without it simply has none yet (Phase 2G ships exactly
	one, per SUS-001's authored data).

	Builds a minimal, static (unanimated) humanoid rig and tags it with the
	shared Interactable contract (Talk kind, SuspectId attribute), so
	InteractionService/InteractionController need no NPC-specific code path.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))
local Interactable = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Interactable"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local CaseService = require(script.Parent:WaitForChild("CaseService"))

local log = Logger.scoped("SuspectSpawner")

local SuspectSpawner = {}

local NPC_FOLDER_NAME = "Suspects"

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	return p
end

-- Builds a simple, static R6-proportioned humanoid rig for a suspect. No
-- animation or AI this phase -- a believable but static office presence.
-- Parts are assembled clustered at the origin, then the whole model is
-- pivoted into place with a single rigid transform.
local function buildNpc(suspect: Types.SuspectDefinition): Model?
	local placement = suspect.npcPlacement
	if not placement then
		return nil
	end

	local Theme = Config.UI.Theme

	local model = Instance.new("Model")
	model.Name = suspect.name

	local rootPart = part("HumanoidRootPart", Vector3.new(2, 2, 1), Color3.new(0, 0, 0), Enum.Material.Plastic)
	rootPart.Transparency = 1
	rootPart.Parent = model
	model.PrimaryPart = rootPart

	local torso = part("Torso", Vector3.new(2, 2, 1), Color3.fromRGB(52, 58, 74), Enum.Material.Fabric)
	torso.CFrame = CFrame.new(0, 0, 0)
	torso.Parent = model

	local head = part("Head", Vector3.new(1.4, 1.4, 1.4), Color3.fromRGB(222, 184, 155), Enum.Material.SmoothPlastic)
	head.Shape = Enum.PartType.Ball
	head.CFrame = CFrame.new(0, 1.7, 0)
	head.Parent = model

	local leftArm = part("Left Arm", Vector3.new(1, 2, 1), Color3.fromRGB(222, 184, 155), Enum.Material.SmoothPlastic)
	leftArm.CFrame = CFrame.new(-1.5, 0, 0)
	leftArm.Parent = model

	local rightArm = part("Right Arm", Vector3.new(1, 2, 1), Color3.fromRGB(222, 184, 155), Enum.Material.SmoothPlastic)
	rightArm.CFrame = CFrame.new(1.5, 0, 0)
	rightArm.Parent = model

	local leftLeg = part("Left Leg", Vector3.new(1, 2, 1), Color3.fromRGB(30, 32, 40), Enum.Material.Fabric)
	leftLeg.CFrame = CFrame.new(-0.5, -2, 0)
	leftLeg.Parent = model

	local rightLeg = part("Right Leg", Vector3.new(1, 2, 1), Color3.fromRGB(30, 32, 40), Enum.Material.Fabric)
	rightLeg.CFrame = CFrame.new(0.5, -2, 0)
	rightLeg.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayName = suspect.name
	humanoid.RequiresNeck = false
	humanoid.Parent = model

	-- Floating name tag: readable, on-theme, matches the game's dark
	-- cinematic UI rather than the default Roblox healthbar/nametag.
	local nameTag = Instance.new("BillboardGui")
	nameTag.Name = "NameTag"
	nameTag.Size = UDim2.fromOffset(160, 34)
	nameTag.StudsOffset = Vector3.new(0, 2.4, 0)
	nameTag.AlwaysOnTop = true
	nameTag.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.fromScale(1, 1)
	nameLabel.Font = Theme.FontBold
	nameLabel.TextSize = 16
	nameLabel.TextColor3 = Theme.TextPrimary
	nameLabel.TextStrokeTransparency = 0.5
	nameLabel.Text = suspect.name
	nameLabel.Parent = nameTag

	local target = if placement.lookAt
		then CFrame.lookAt(placement.position, Vector3.new(placement.lookAt.X, placement.position.Y, placement.lookAt.Z))
		else CFrame.new(placement.position)
	model:PivotTo(target)

	CollectionService:AddTag(rootPart, Interactable.TAG)
	rootPart:SetAttribute(Interactable.AttributeName.Kind, "Talk")
	rootPart:SetAttribute(Interactable.AttributeName.PromptLabel, `Talk to {suspect.name}`)
	rootPart:SetAttribute(Interactable.AttributeName.SuspectId, suspect.id)

	return model
end

function SuspectSpawner.start()
	local office = workspace:FindFirstChild(Config.Environment.OfficeModelName)
	local parent = office or workspace

	local folder = parent:FindFirstChild(NPC_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = NPC_FOLDER_NAME
		folder.Parent = parent
	end

	local spawned = 0
	for _, suspect in ipairs(CaseService.getSuspects(Config.Game.AutoStartCase)) do
		local model = buildNpc(suspect)
		if model then
			model.Parent = folder
			spawned += 1
		end
	end

	log:info("suspects spawned", { count = spawned })
end

return SuspectSpawner
