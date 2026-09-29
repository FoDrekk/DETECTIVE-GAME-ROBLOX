--!strict
--[[
	OfficeRoom
	Runtime concerns for the authored investigation environment.

	The office *geometry* is Studio-authored and ships as `assets/Office.rbxm`,
	mapped by Rojo to `Workspace.Office`. This module owns the generic runtime
	integration and contains no case-specific data:

	  1. removes the configured default ground so the authored environment is
	     the only floor,
	  2. applies the evening investigation lighting/atmosphere,
	  3. validates that the authored interactables satisfy the active case's
	     evidence requirements (read from Config, never hardcoded here).

	World building stays in Studio; gameplay logic stays in services; case facts
	stay in Config.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))
local Interactable = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Interactable"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local CaseRegistry = require(game:GetService("ServerStorage"):WaitForChild("Config"):WaitForChild("CaseRegistry"))
local PropKit = require(script.Parent:WaitForChild("PropKit"))

local log = Logger.scoped("OfficeRoom")

local OfficeRoom = {}

local EVIDENCE_PROPS_FOLDER_NAME = "EvidenceProps"
local LOCATION_SIGNS_FOLDER_NAME = "LocationSigns"

local function clearDefaultGround()
	for _, name in ipairs(Config.Environment.DefaultGroundNames) do
		local inst = workspace:FindFirstChild(name)
		if inst then
			inst:Destroy()
		end
	end
end

-- 12:40 AM, after hours. Realistic lighting (local lights cast shadows and
-- read as physical), a restrained colour grade, bloom only on what glows.
local function applyNightLighting()
	local night = Config.Environment.Night
	-- LightingStyle/PrioritizeLightingQuality are the unified-lighting
	-- controls (Lighting.Technology itself is not settable from a script).
	pcall(function()
		local unified: any = Lighting
		unified.LightingStyle = Enum.LightingStyle.Realistic
		unified.PrioritizeLightingQuality = true
	end)
	Lighting.ClockTime = night.ClockTime
	Lighting.Brightness = night.Brightness
	Lighting.Ambient = night.Ambient
	Lighting.OutdoorAmbient = night.OutdoorAmbient
	Lighting.EnvironmentDiffuseScale = night.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = night.EnvironmentSpecularScale
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = night.ShadowSoftness
	Lighting.ExposureCompensation = night.ExposureCompensation
	Lighting.FogStart = 80
	Lighting.FogEnd = 400
	Lighting.FogColor = Color3.fromRGB(24, 28, 40)

	local existingAtmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if existingAtmo then
		existingAtmo:Destroy()
	end
	local atmo = Instance.new("Atmosphere")
	atmo.Density = 0.3
	atmo.Offset = 0.05
	atmo.Color = Color3.fromRGB(52, 60, 84)
	atmo.Decay = Color3.fromRGB(24, 26, 38)
	atmo.Glare = 0
	atmo.Haze = 1.4
	atmo.Parent = Lighting

	local grade = Lighting:FindFirstChild("MysteryCase_Grade")
	if not grade then
		local created = Instance.new("ColorCorrectionEffect")
		created.Name = "MysteryCase_Grade"
		created.Parent = Lighting
		grade = created
	end
	local cc = grade :: ColorCorrectionEffect
	cc.Brightness = 0
	cc.Contrast = night.Contrast
	cc.Saturation = night.Saturation
	cc.TintColor = night.Tint

	local hasBloom = false
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("BloomEffect") then
			hasBloom = true
			child.Intensity = night.BloomIntensity
			child.Size = night.BloomSize
			child.Threshold = night.BloomThreshold
		elseif child:IsA("SunRaysEffect") or child:IsA("DepthOfFieldEffect") then
			-- No sun at midnight; depth of field is the dialogue camera's
			-- (client-side) choice, not a permanent blur.
			child.Enabled = false
		end
	end
	if not hasBloom then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = night.BloomIntensity
		bloom.Size = night.BloomSize
		bloom.Threshold = night.BloomThreshold
		bloom.Parent = Lighting
	end
end

--[[
	Confirm the authored environment exposes every evidence id the active case
	declares. Requirements come from case data, so adding a case never requires
	editing this module.
]]
local function validateInteractables()
	local presentEvidence: { [string]: boolean } = {}
	local interactableCount = 0

	for _, instance in ipairs(Interactable.getAll()) do
		interactableCount += 1
		local descriptor = Interactable.describe(instance)
		if descriptor and descriptor.evidenceId then
			presentEvidence[descriptor.evidenceId] = true
		end
	end

	if interactableCount == 0 then
		log:warn(`no "{Interactable.TAG}"-tagged instances found; is Workspace.{Config.Environment.OfficeModelName} synced?`)
		return
	end

	local caseDef = CaseRegistry.get(Config.Game.AutoStartCase)
	if not caseDef then
		log:warn(`active case '{Config.Game.AutoStartCase}' is not registered; skipping evidence validation`)
		return
	end

	-- Phase 5.1: evidence a conversation hands over needs no object in the
	-- world (DialogueNodeDefinition.grantsEvidence).
	local grantedByDialogue: { [string]: boolean } = {}
	for _, conversation in ipairs(caseDef.conversations) do
		for _, node in pairs(conversation.nodes) do
			for _, evidenceId in ipairs(node.grantsEvidence or {}) do
				grantedByDialogue[evidenceId] = true
			end
		end
	end

	for _, evidence in ipairs(caseDef.evidence) do
		if not presentEvidence[evidence.id] and not grantedByDialogue[evidence.id] then
			log:warn("missing authored interactable for case evidence", {
				evidenceId = evidence.id,
				name = evidence.name,
			})
		end
	end
end

--[[
	Builds a minimal, static, wall-panel-style prop for evidence that authors
	`propPlacement` -- for evidence with no hand-placed counterpart in the
	Studio-authored `assets/Office.rbxm`. Mirrors `SuspectSpawner.buildNpc`'s
	npcPlacement-driven pattern exactly, kept here (not a new service) since
	this is the module already responsible for runtime office setup. No
	evidence id is hardcoded: any evidence with `propPlacement` gets a prop;
	evidence without it simply has none (must already exist as a Studio prop,
	as EV-001/002/003 do).
]]
local function buildEvidenceProp(evidence: Types.EvidenceDefinition, folder: Instance): BasePart?
	local placement = evidence.propPlacement
	if not placement then
		return nil
	end

	local target = if placement.lookAt
		then CFrame.lookAt(placement.position, Vector3.new(placement.lookAt.X, placement.position.Y, placement.lookAt.Z))
		else CFrame.new(placement.position)

	-- The look comes from PropKit (by style); the Interactable contract lives
	-- on a part named after the evidence id -- the visible body when there is
	-- a style, a plain panel otherwise.
	local part: BasePart
	if placement.style then
		local model, body = PropKit.evidence(placement.style, folder, target)
		model.Name = `{evidence.id}_Look`
		part = body
	else
		local panel = Instance.new("Part")
		panel.Size = Vector3.new(2, 3, 0.3)
		panel.Color = Color3.fromRGB(52, 58, 74)
		panel.Material = Enum.Material.Metal
		panel.Anchored = true
		panel.CanCollide = false
		panel.CFrame = target
		part = panel
	end
	part.Name = evidence.id

	CollectionService:AddTag(part, Interactable.TAG)
	part:SetAttribute(Interactable.AttributeName.Kind, "Read")
	local verb = if placement.style == "Printout" then "Read" else "Examine"
	part:SetAttribute(Interactable.AttributeName.PromptLabel, `{verb} {evidence.name}`)
	part:SetAttribute(Interactable.AttributeName.EvidenceId, evidence.id)

	return part
end

local function spawnEvidenceProps()
	local office = workspace:FindFirstChild(Config.Environment.OfficeModelName)
	local parent = office or workspace

	local folder = parent:FindFirstChild(EVIDENCE_PROPS_FOLDER_NAME)
	if folder then
		-- Baked already: adopted as-is so author repositioning survives.
		return
	end
	folder = Instance.new("Folder")
	folder.Name = EVIDENCE_PROPS_FOLDER_NAME
	folder.Parent = parent

	local caseDef = CaseRegistry.get(Config.Game.AutoStartCase)
	if not caseDef then
		return
	end

	local spawned = 0
	for _, evidence in ipairs(caseDef.evidence) do
		local prop = buildEvidenceProp(evidence, folder)
		if prop then
			prop.Parent = folder
			spawned += 1
		end
	end

	if spawned > 0 then
		log:info("evidence props spawned", { count = spawned })
	end
end

--[[
	Builds a small wall plaque naming a location, for any location that
	authors `signPlacement` (M3). Mirrors buildEvidenceProp's
	placement-driven pattern exactly. Not an Interactable -- purely
	wayfinding, not a clue -- and not tagged, so it never competes with a
	real interaction prompt.
]]
local function buildLocationSign(location: Types.LocationDefinition): BasePart?
	local placement = location.signPlacement
	if not placement then
		return nil
	end

	local Theme = Config.UI.Theme

	local plaque = Instance.new("Part")
	plaque.Name = "Sign_" .. location.id
	plaque.Size = Vector3.new(2.6, 0.8, 0.06)
	plaque.Color = Color3.fromRGB(30, 31, 35)
	plaque.Material = Enum.Material.Metal
	plaque.Anchored = true
	plaque.CanCollide = false

	local target = if placement.lookAt
		then CFrame.lookAt(placement.position, Vector3.new(placement.lookAt.X, placement.position.Y, placement.lookAt.Z))
		else CFrame.new(placement.position)
	plaque.CFrame = target

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.PixelsPerStud = 60
	gui.Parent = plaque

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = string.upper(placement.text)
	label.Font = Theme.FontBold
	label.TextColor3 = Theme.Accent
	label.TextScaled = true
	label.Parent = gui

	return plaque
end

local function buildLocationSigns()
	local office = workspace:FindFirstChild(Config.Environment.OfficeModelName)
	local parent = office or workspace

	local folder = parent:FindFirstChild(LOCATION_SIGNS_FOLDER_NAME)
	if folder then
		-- Baked already: adopted as-is so author repositioning survives.
		return
	end
	folder = Instance.new("Folder")
	folder.Name = LOCATION_SIGNS_FOLDER_NAME
	folder.Parent = parent

	local caseDef = CaseRegistry.get(Config.Game.AutoStartCase)
	if not caseDef then
		return
	end

	local spawned = 0
	for _, location in ipairs(caseDef.locations) do
		local sign = buildLocationSign(location)
		if sign then
			sign.Parent = folder
			spawned += 1
		end
	end

	if spawned > 0 then
		log:info("location signs spawned", { count = spawned })
	end
end

--[[
	Apply authored flavour text (Phase 2O) to no-evidence interactables by
	instance name. Additive and runtime-only: an entry whose instance is
	absent is skipped, and any interactable that carries evidence is never
	touched (so a real clue can never be given flavour text). No case id is
	hardcoded; the text comes from case data.
]]
local function applyObservations()
	local caseDef = CaseRegistry.get(Config.Game.AutoStartCase)
	if not caseDef or not caseDef.observations then
		return
	end

	local applied = 0
	for _, observation in ipairs(caseDef.observations) do
		for _, instance in ipairs(Interactable.getAll()) do
			if instance.Name == observation.instanceName then
				local descriptor = Interactable.describe(instance)
				if descriptor and not descriptor.evidenceId then
					instance:SetAttribute(Interactable.AttributeName.ObservationText, observation.text)
					if observation.label then
						-- Phase 2P: an authored asset's own prompt label can
						-- read as real evidence next to the actual clue (e.g.
						-- "Examine Coffee Cup" beside the visitor's cup); let
						-- the case override it without touching the asset.
						instance:SetAttribute(Interactable.AttributeName.PromptLabel, observation.label)
					end
					applied += 1
				end
			end
		end
	end

	if applied > 0 then
		log:info("observations applied", { count = applied })
	end
end

--[[
	Phase 2P: stale-bake detection. `office` here is whatever the currently
	open/loaded `.rbxl` already carries (before this boot's builders run),
	so this reads the stamp left by the *last* `EnvironmentBake.bake()`, not
	anything this session has touched yet. A place that was never baked
	(fresh from `assets/Office.rbxm` via Rojo, no generated folders yet)
	carries no `Baked` attribute at all -- nothing to warn about, since this
	boot's builders will generate current-version geometry from scratch.
	Only warns; never rebuilds or blocks boot, and never touches the
	builders' own reuse-existing-folders adoption.
]]
local function warnIfBakeStale(office: Instance?)
	if not office or not office:GetAttribute("Baked") then
		return
	end
	local stamped = office:GetAttribute("BuilderVersion")
	local current = Config.Environment.BuilderVersion
	if stamped ~= current then
		log:warn("baked office geometry predates the current builder code; re-bake and save in Edit mode", {
			stampedVersion = stamped,
			currentVersion = current,
		})
	end
end

function OfficeRoom.start()
	clearDefaultGround()

	local office = workspace:FindFirstChild(Config.Environment.OfficeModelName)
	if not office then
		log:warn(`Workspace.{Config.Environment.OfficeModelName} not found; run Rojo sync to load the authored environment`)
	end
	warnIfBakeStale(office)

	applyNightLighting()
	spawnEvidenceProps()
	buildLocationSigns()
	log:info("environment ready", { office = office ~= nil })
end

-- Runs once every environment module has built its props (the interior
-- adds interactable flavour objects), so authored observations find them.
function OfficeRoom.finalize()
	applyObservations()
	validateInteractables()
end

return OfficeRoom
