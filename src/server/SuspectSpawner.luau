--!strict
--[[
	SuspectSpawner
	Runtime placement of physical NPC representations for suspects that
	author an `npcPlacement` (Types.SuspectDefinition). Purely staging: no
	suspect id is hardcoded here -- every suspect with npcPlacement gets an
	NPC; a suspect without it simply has none (Phase 2G shipped SUS-001;
	Phase 2I adds SUS-002 -- no code change was needed for the second one).

	M6: each NPC is a real R15 avatar generated from a HumanoidDescription
	(the suspect's authored `appearance`: body package, hair, outfit
	colours), breathing through Roblox's default idle animation, and turning
	to face whoever starts a conversation with them.

	The rig itself carries no game contract. A separate invisible hitbox Part,
	named after the suspect's id, holds the shared Interactable tag (Talk kind,
	SuspectId attribute), so InteractionService/InteractionController need no
	NPC-specific code path and an ObjectiveRequirement.target can address one
	specific suspect ("SUS-002").
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))
local Interactable = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Interactable"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local CaseService = require(script.Parent:WaitForChild("CaseService"))
local StoryEvents = require(script.Parent:WaitForChild("StoryEvents"))

local log = Logger.scoped("SuspectSpawner")

local SuspectSpawner = {}

local NPC_FOLDER_NAME = "Suspects"
-- The authored npcPlacement.position is the body's centre, 3 studs above the
-- floor (the convention the original block rigs used). Feet are snapped to
-- the floor found below it, falling back to this offset.
local PLACEMENT_HEIGHT = 3
local HITBOX_SIZE = Vector3.new(2.4, 5.2, 1.6)

-- suspectId -> spawned model, for turning toward a speaking player.
local spawnedModels: { [string]: Model } = {}

local function describe(appearance: Types.SuspectAppearance?): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	if not appearance then
		return description
	end
	local body = Config.Characters.Bodies[appearance.body]
	if body then
		description.Torso = body.Torso
		description.LeftArm = body.LeftArm
		description.RightArm = body.RightArm
		description.LeftLeg = body.LeftLeg
		description.RightLeg = body.RightLeg
	else
		log:warn("unknown body package", { body = appearance.body })
	end
	description.HairAccessory = tostring(appearance.hair)
	return description
end

-- Per-part colours rather than BodyColors, which can only colour a whole
-- limb: sleeves stop at the wrist, the jacket stops at the belt, and shoes
-- are their own colour.
local function dress(model: Model, appearance: Types.SuspectAppearance)
	local colors: { [string]: Color3 } = {
		Head = appearance.skin,
		LeftHand = appearance.skin,
		RightHand = appearance.skin,
		UpperTorso = appearance.top,
		LeftUpperArm = appearance.top,
		RightUpperArm = appearance.top,
		LeftLowerArm = appearance.top,
		RightLowerArm = appearance.top,
		LowerTorso = appearance.bottom,
		LeftUpperLeg = appearance.bottom,
		RightUpperLeg = appearance.bottom,
		LeftLowerLeg = appearance.bottom,
		RightLowerLeg = appearance.bottom,
		LeftFoot = appearance.shoes,
		RightFoot = appearance.shoes,
	}
	local bodyColors = model:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors:Destroy()
	end
	for name, color in pairs(colors) do
		local limb = model:FindFirstChild(name)
		if limb and limb:IsA("BasePart") then
			limb.Color = color
		end
	end

	-- Catalog hair ships with its own (often bright) texture; drop it so the
	-- mesh takes a natural authored colour.
	for _, accessory in ipairs(model:GetChildren()) do
		local handle = accessory:IsA("Accessory") and accessory:FindFirstChild("Handle")
		if handle and handle:IsA("MeshPart") then
			handle.TextureID = ""
			handle.Color = appearance.hairColor
		elseif handle and handle:IsA("BasePart") then
			local mesh = handle:FindFirstChildOfClass("SpecialMesh")
			if mesh then
				mesh.TextureId = ""
			end
			handle.Color = appearance.hairColor
		end
	end
end

local function floorBelow(position: Vector3, ignore: Instance): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ignore }
	local hit = workspace:Raycast(position, Vector3.new(0, -PLACEMENT_HEIGHT * 3, 0), params)
	return if hit then hit.Position.Y else position.Y - PLACEMENT_HEIGHT
end

local function addNameTag(head: BasePart, name: string)
	local Theme = Config.UI.Theme

	-- Floating name tag: readable, on-theme, matches the game's dark
	-- cinematic UI rather than the default Roblox healthbar/nametag.
	local nameTag = Instance.new("BillboardGui")
	nameTag.Name = "NameTag"
	nameTag.Size = UDim2.fromOffset(160, 34)
	nameTag.StudsOffset = Vector3.new(0, 1.9, 0)
	nameTag.AlwaysOnTop = true
	nameTag.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.fromScale(1, 1)
	nameLabel.Font = Theme.FontBold
	nameLabel.TextSize = 16
	nameLabel.TextColor3 = Theme.TextPrimary
	nameLabel.TextStrokeTransparency = 0.5
	nameLabel.Text = name
	nameLabel.Parent = nameTag
end

local function playIdle(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		local created = Instance.new("Animator")
		created.Parent = humanoid
		animator = created
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = Config.Characters.IdleAnimation
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(animation)
	end)
	if ok and track then
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Idle
		track:Play()
	else
		log:warn("idle animation failed to load", { error = tostring(track) })
	end
end

local function buildNpc(suspect: Types.SuspectDefinition): Model?
	local placement = suspect.npcPlacement
	if not placement then
		return nil
	end

	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(describe(suspect.appearance), Enum.HumanoidRigType.R15)
	end)
	if not ok then
		log:warn("could not build suspect avatar", { suspectId = suspect.id, error = tostring(result) })
		return nil
	end
	local model = result :: Model
	model.Name = suspect.name

	-- The Animate LocalScript never runs on a server-owned NPC; the idle is
	-- played directly below.
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	if suspect.appearance then
		dress(model, suspect.appearance)
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayName = suspect.name
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)

	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
		end
	end

	-- Stand the avatar on the floor under its authored position, facing
	-- its authored lookAt.
	local position = placement.position
	local facing = if placement.lookAt
		then CFrame.lookAt(position, Vector3.new(placement.lookAt.X, position.Y, placement.lookAt.Z))
		else CFrame.new(position)
	model:PivotTo(facing)
	local boxCFrame, boxSize = model:GetBoundingBox()
	local feetY = boxCFrame.Position.Y - boxSize.Y / 2
	model:PivotTo(facing + Vector3.new(0, floorBelow(position, model) - feetY, 0))

	-- The interaction contract lives on its own part, welded to the root
	-- so it follows the avatar when it turns.
	local hitbox = Instance.new("Part")
	hitbox.Name = suspect.id
	hitbox.Size = HITBOX_SIZE
	hitbox.Transparency = 1
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.Anchored = false
	hitbox.Massless = true
	hitbox.CFrame = root.CFrame
	hitbox.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = hitbox
	weld.Parent = hitbox

	CollectionService:AddTag(hitbox, Interactable.TAG)
	hitbox:SetAttribute(Interactable.AttributeName.Kind, "Talk")
	hitbox:SetAttribute(Interactable.AttributeName.PromptLabel, `Talk to {suspect.name}`)
	hitbox:SetAttribute(Interactable.AttributeName.SuspectId, suspect.id)

	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		addNameTag(head, suspect.name)
	end

	return model
end

-- Turn a suspect in place (yaw only) to face the player who is talking to
-- them. The anchored root carries the whole rig and the welded hitbox.
local function faceSpeaker(player: Player, suspectId: string)
	local model = spawnedModels[suspectId]
	if not model or not model.Parent or typeof(player) ~= "Instance" then
		return
	end
	local character = player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (playerRoot and playerRoot:IsA("BasePart") and root and root:IsA("BasePart")) then
		return
	end
	local from = root.Position
	local toward = Vector3.new(playerRoot.Position.X, from.Y, playerRoot.Position.Z)
	if (toward - from).Magnitude < 0.1 then
		return
	end
	TweenService:Create(
		root,
		TweenInfo.new(Config.Characters.TurnTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ CFrame = CFrame.lookAt(from, toward) }
	):Play()
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
			spawnedModels[suspect.id] = model
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				playIdle(humanoid)
			end
			spawned += 1
		end
	end

	StoryEvents.on("ConversationStarted", function(player: Player, data: { [string]: any })
		faceSpeaker(player, data.suspectId)
	end)

	log:info("suspects spawned", { count = spawned })
end

return SuspectSpawner
