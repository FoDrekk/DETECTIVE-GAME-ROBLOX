--!strict
--[[
	SuspectSpawner
	Runtime placement of physical NPC representations for suspects that
	author an `npcPlacement` (Types.SuspectDefinition). Purely staging: no
	suspect id is hardcoded here -- every suspect with npcPlacement gets an
	NPC; a suspect without it simply has none.

	Each NPC is a real R15 avatar generated from a HumanoidDescription
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
local RunService = game:GetService("RunService")
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
	if appearance.hair then
		description.HairAccessory = tostring(appearance.hair)
	end
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

--------------------------------------------------------------------------
-- Wardrobe details: small welded parts that make each character readable
-- at a glance (a tie, a scarf, a security patch...). Keys come from the
-- suspect's `appearance.details`; unknown keys are ignored with a warning.
--------------------------------------------------------------------------

local function detailPart(model: Model, limbName: string, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material): Part?
	local limb = model:FindFirstChild(limbName)
	if not limb or not limb:IsA("BasePart") then
		return nil
	end
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = limb.CFrame * offset
	p.Color = color
	p.Material = material
	p.Anchored = false
	p.Massless = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = limb
	weld.Part1 = p
	weld.Parent = p
	return p
end

local function chestFront(model: Model): (number, number)
	local torso = model:FindFirstChild("UpperTorso")
	if torso and torso:IsA("BasePart") then
		return torso.Size.Z / 2, torso.Size.Y / 2
	end
	return 0.5, 0.8
end

local DETAILS: { [string]: (model: Model, appearance: Types.SuspectAppearance) -> () } = {
	-- A white shirt collar and placket showing at the jacket's opening.
	Shirt = function(model, _)
		local front, top = chestFront(model)
		detailPart(model, "UpperTorso", "ShirtFront", Vector3.new(0.5, 0.75, 0.04), CFrame.new(0, top - 0.38, -front - 0.01), Color3.fromRGB(226, 226, 222), Enum.Material.Fabric)
		for _, side in ipairs({ -1, 1 }) do
			detailPart(model, "UpperTorso", "Collar", Vector3.new(0.3, 0.2, 0.05), CFrame.new(side * 0.2, top - 0.08, -front - 0.02) * CFrame.Angles(0, 0, math.rad(side * 30)), Color3.fromRGB(236, 236, 232), Enum.Material.Fabric)
		end
	end,
	Tie = function(model, appearance)
		local front, top = chestFront(model)
		local color = appearance.accent or Color3.fromRGB(110, 30, 36)
		detailPart(model, "UpperTorso", "TieKnot", Vector3.new(0.2, 0.16, 0.07), CFrame.new(0, top - 0.14, -front - 0.04), color, Enum.Material.Fabric)
		detailPart(model, "UpperTorso", "Tie", Vector3.new(0.24, 0.95, 0.04), CFrame.new(0, top - 0.72, -front - 0.035), color, Enum.Material.Fabric)
	end,
	-- A knitted scarf looped at the neck, one end hanging at the front.
	Scarf = function(model, appearance)
		local front, top = chestFront(model)
		local color = appearance.accent or Color3.fromRGB(196, 178, 150)
		for i = 0, 7 do
			local angle = math.rad(i * 45)
			detailPart(
				model,
				"UpperTorso",
				"ScarfLoop",
				Vector3.new(0.42, 0.34, 0.24),
				CFrame.new(math.sin(angle) * 0.55, top + 0.05, math.cos(angle) * 0.42) * CFrame.Angles(0, angle, 0),
				color,
				Enum.Material.Fabric
			)
		end
		detailPart(model, "UpperTorso", "ScarfEnd", Vector3.new(0.34, 0.9, 0.1), CFrame.new(0.28, top - 0.5, -front - 0.06) * CFrame.Angles(0, 0, math.rad(-6)), color, Enum.Material.Fabric)
	end,
	Watch = function(model, _)
		detailPart(model, "LeftLowerArm", "Watch", Vector3.new(0.5, 0.16, 0.5), CFrame.new(0, -0.35, 0), Color3.fromRGB(40, 38, 36), Enum.Material.Leather)
		detailPart(model, "LeftLowerArm", "WatchFace", Vector3.new(0.05, 0.12, 0.2), CFrame.new(-0.27, -0.35, 0), Color3.fromRGB(196, 186, 150), Enum.Material.Metal)
	end,
	-- The guard's shoulder patch and chest badge.
	SecurityPatch = function(model, appearance)
		local front, top = chestFront(model)
		local patch = detailPart(model, "UpperTorso", "SecurityPatch", Vector3.new(0.62, 0.3, 0.04), CFrame.new(-0.45, top - 0.45, -front - 0.02), Color3.fromRGB(24, 28, 40), Enum.Material.Fabric)
		if patch then
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Front
			gui.PixelsPerStud = 120
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.Parent = patch
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.Text = "SECURITY"
			text.TextScaled = true
			text.Font = Enum.Font.GothamBold
			text.TextColor3 = appearance.accent or Color3.fromRGB(214, 190, 120)
			text.Parent = gui
		end
		for _, arm in ipairs({ "LeftUpperArm", "RightUpperArm" }) do
			detailPart(model, arm, "Epaulette", Vector3.new(0.5, 0.06, 0.9), CFrame.new(0, 0.52, 0), Color3.fromRGB(24, 28, 40), Enum.Material.Fabric)
		end
	end,
	Radio = function(model, _)
		detailPart(model, "LowerTorso", "Radio", Vector3.new(0.26, 0.5, 0.22), CFrame.new(0.95, 0.05, 0), Color3.fromRGB(28, 28, 30), Enum.Material.SmoothPlastic)
		detailPart(model, "LowerTorso", "Antenna", Vector3.new(0.05, 0.4, 0.05), CFrame.new(0.99, 0.5, 0.05), Color3.fromRGB(20, 20, 20), Enum.Material.Rubber)
	end,
	Lanyard = function(model, _)
		local front, top = chestFront(model)
		for _, side in ipairs({ -1, 1 }) do
			detailPart(model, "UpperTorso", "Strap", Vector3.new(0.06, 0.8, 0.02), CFrame.new(side * 0.16, top - 0.4, -front - 0.02) * CFrame.Angles(0, 0, math.rad(side * -14)), Color3.fromRGB(150, 30, 34), Enum.Material.Fabric)
		end
		detailPart(model, "UpperTorso", "IdCard", Vector3.new(0.3, 0.42, 0.02), CFrame.new(0, top - 0.95, -front - 0.03), Color3.fromRGB(236, 236, 232), Enum.Material.SmoothPlastic)
	end,
}

local function addDetails(model: Model, appearance: Types.SuspectAppearance)
	for _, key in ipairs(appearance.details or {}) do
		local build = DETAILS[key]
		if build then
			build(model, appearance)
		else
			log:warn("unknown wardrobe detail", { detail = key })
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

-- World-space lowest point of any part in the model: the soles of its feet.
-- Uses each part's own CFrame so a rotated/mesh foot is measured where it is.
local function lowestPoint(model: Model): number
	local lowest = math.huge
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local bottom = (descendant.CFrame * CFrame.new(0, -descendant.Size.Y / 2, 0)).Position.Y
			if bottom < lowest then
				lowest = bottom
			end
		end
	end
	return if lowest == math.huge then 0 else lowest
end

-- Drop the model along Y so the soles of its feet rest on the floor under
-- the authored position (XZ/yaw untouched). Idempotent: re-running after the
-- rig has settled corrects any residual sink.
local function groundModel(model: Model, placement: Types.NpcPlacement)
	local delta = floorBelow(placement.position, model) - lowestPoint(model)
	if math.abs(delta) > 1e-4 then
		model:PivotTo(model:GetPivot() + Vector3.new(0, delta, 0))
	end
end

local function addNameTag(head: BasePart, name: string, role: string)
	local Theme = Config.UI.Theme

	-- Floating name tag: on-theme, and only when you're close enough to talk
	-- (a room full of always-on labels reads as a game menu, not an office).
	local nameTag = Instance.new("BillboardGui")
	nameTag.Name = "NameTag"
	nameTag.Size = UDim2.fromOffset(180, 40)
	nameTag.StudsOffset = Vector3.new(0, 1.9, 0)
	nameTag.AlwaysOnTop = true
	nameTag.MaxDistance = Config.Characters.NameTagDistance
	nameTag.LightInfluence = 0
	nameTag.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, 0, 0, 22)
	nameLabel.Font = Theme.FontBold
	nameLabel.TextSize = 16
	nameLabel.TextColor3 = Theme.TextPrimary
	nameLabel.TextStrokeTransparency = 0.5
	nameLabel.Text = name
	nameLabel.Parent = nameTag

	local roleLabel = Instance.new("TextLabel")
	roleLabel.BackgroundTransparency = 1
	roleLabel.Position = UDim2.fromOffset(0, 21)
	roleLabel.Size = UDim2.new(1, 0, 0, 16)
	roleLabel.Font = Theme.Font
	roleLabel.TextSize = 12
	roleLabel.TextColor3 = Theme.Accent
	roleLabel.TextStrokeTransparency = 0.6
	roleLabel.Text = string.upper(role)
	roleLabel.Parent = nameTag
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
		addDetails(model, suspect.appearance)
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayName = suspect.name
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	-- Fix the rig's proportions now: automatic avatar scaling resizes the
	-- limbs a step after creation (a part's OriginalSize != Size), which
	-- lowers the feet after they have already been grounded below and leaves
	-- the avatar sunk into the floor.
	humanoid.AutomaticScalingEnabled = false

	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
		end
	end

	-- Stand the avatar on the floor under its authored position, facing
	-- its authored lookAt. Ground by the lowest posed part (the feet) rather
	-- than GetBoundingBox, which can report a box above the actual limbs.
	local position = placement.position
	local facing = if placement.lookAt
		then CFrame.lookAt(position, Vector3.new(placement.lookAt.X, position.Y, placement.lookAt.Z))
		else CFrame.new(position)
	model:PivotTo(facing)
	groundModel(model, placement)

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
		addNameTag(head, suspect.name, suspect.role)
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

-- A baked NPC persists in the place (Edit-mode bake). Adopt it by the hitbox
-- part named after the suspect id instead of rebuilding the avatar, so any
-- author repositioning of the model survives.
local function findBakedNpc(folder: Instance, suspect: Types.SuspectDefinition): Model?
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") and child:FindFirstChild(suspect.id, true) then
			return child
		end
	end
	return nil
end

--[[
	Bring baked NPCs' identities in line with case data after a
	rename or a change of skin tone, without rebuilding them: the model name,
	display name, "Talk to" prompt, floating name tag and skin-coloured parts.
	Position, pose, hair and clothes are left alone, and so are any author
	edits to them. Meant for Edit mode (the bake persists on save). Returns
	how many NPCs were patched.
]]
function SuspectSpawner.patchIdentities(): number
	local office = workspace:FindFirstChild(Config.Environment.OfficeModelName)
	local folder = (office or workspace):FindFirstChild(NPC_FOLDER_NAME)
	if not folder then
		return 0
	end
	local patched = 0
	for _, suspect in ipairs(CaseService.getSuspects(Config.Game.AutoStartCase)) do
		local model = findBakedNpc(folder, suspect)
		if model then
			model.Name = suspect.name
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.DisplayName = suspect.name
			end
			local hitbox = model:FindFirstChild(suspect.id, true)
			if hitbox then
				hitbox:SetAttribute(Interactable.AttributeName.PromptLabel, `Talk to {suspect.name}`)
			end
			local nameTag = model:FindFirstChild("NameTag", true)
			local labels = nameTag and nameTag:GetChildren() or {}
			for _, child in ipairs(labels) do
				-- The tag's first label is the name, its second the role.
				if child:IsA("TextLabel") and child.Position == UDim2.new() then
					child.Text = suspect.name
				elseif child:IsA("TextLabel") then
					child.Text = string.upper(suspect.role)
				end
			end
			if suspect.appearance then
				for _, partName in ipairs({ "Head", "LeftHand", "RightHand" }) do
					local limb = model:FindFirstChild(partName)
					if limb and limb:IsA("BasePart") then
						limb.Color = suspect.appearance.skin
					end
				end
			end
			patched += 1
		end
	end
	return patched
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

	local spawned, adopted = 0, 0
	local staged: { { model: Model, placement: Types.NpcPlacement } } = {}
	for _, suspect in ipairs(CaseService.getSuspects(Config.Game.AutoStartCase)) do
		local model = findBakedNpc(folder, suspect)
		if model then
			adopted += 1
		else
			model = buildNpc(suspect)
		end
		if model then
			if not model.Parent then
				model.Parent = folder
			end
			spawnedModels[suspect.id] = model
			local placement = suspect.npcPlacement
			if placement then
				table.insert(staged, { model = model, placement = placement })
			end
			-- The idle loop and the conversation listener are runtime state:
			-- an Edit-mode bake only stages the models.
			if RunService:IsRunning() then
				local humanoid = model:FindFirstChildOfClass("Humanoid")
				if humanoid then
					playIdle(humanoid)
				end
			end
			spawned += 1
		end
	end

	-- The rig's proportional scaling settles a step after creation and can
	-- lower the feet, so re-ground every staged avatar once it has.
	task.wait()
	for _, entry in ipairs(staged) do
		if entry.model.Parent then
			groundModel(entry.model, entry.placement)
		end
	end

	if RunService:IsRunning() then
		StoryEvents.on("ConversationStarted", function(player: Player, data: { [string]: any })
			faceSpeaker(player, data.suspectId)
		end)
	end

	log:info("suspects staged", { count = spawned, adopted = adopted })
end

return SuspectSpawner
