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
local CaseRegistry = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CaseRegistry"))

local log = Logger.scoped("OfficeRoom")

local OfficeRoom = {}

local function clearDefaultGround()
	for _, name in ipairs(Config.Environment.DefaultGroundNames) do
		local inst = workspace:FindFirstChild(name)
		if inst then
			inst:Destroy()
		end
	end
end

local function applyEveningLighting()
	-- Evening / late-night office mood. Bright enough to play comfortably.
	Lighting.ClockTime = 20.5
	Lighting.TimeOfDay = "20:30:00"
	Lighting.Ambient = Color3.fromRGB(46, 46, 54)
	Lighting.OutdoorAmbient = Color3.fromRGB(30, 32, 44)
	Lighting.Brightness = 1.2
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.25
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35
	Lighting.FogEnd = 220
	Lighting.FogStart = 60
	Lighting.FogColor = Color3.fromRGB(24, 26, 36)
	Lighting.ExposureCompensation = 0.15

	local existingAtmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if existingAtmo then
		existingAtmo:Destroy()
	end
	local atmo = Instance.new("Atmosphere")
	atmo.Density = 0.35
	atmo.Offset = 0.1
	atmo.Color = Color3.fromRGB(30, 32, 44)
	atmo.Decay = Color3.fromRGB(20, 22, 32)
	atmo.Glare = 0
	atmo.Haze = 1.2
	atmo.Parent = Lighting

	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("BloomEffect") then
			child.Intensity = 0.35
			child.Size = 18
			child.Threshold = 1.4
		end
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

	for _, evidence in ipairs(caseDef.evidence) do
		if not presentEvidence[evidence.id] then
			log:warn("missing authored interactable for case evidence", {
				evidenceId = evidence.id,
				name = evidence.name,
			})
		end
	end
end

function OfficeRoom.start()
	clearDefaultGround()

	local office = workspace:FindFirstChild(Config.Environment.OfficeModelName)
	if not office then
		log:warn(`Workspace.{Config.Environment.OfficeModelName} not found; run Rojo sync to load the authored environment`)
	end

	applyEveningLighting()
	validateInteractables()
	log:info("environment ready", { office = office ~= nil })
end

return OfficeRoom
