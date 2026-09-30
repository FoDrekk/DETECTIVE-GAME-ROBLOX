--!strict
--[[
	CaseService
	Owns case definitions and per-player case progress. Purely data-driven:
	no gameplay rules are hardcoded here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))
local CaseRegistry = require(game:GetService("ServerStorage"):WaitForChild("Config"):WaitForChild("CaseRegistry"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local log = Logger.scoped("CaseService")

local CaseService = {}

-- Returns the active case definition for a player.
function CaseService.getActiveCase(player: Player): Types.CaseDefinition?
	local data = PlayerDataService.get(player)
	if not data then
		return nil
	end
	return CaseRegistry.get(data.caseState.caseId)
end

-- Returns a specific case definition by id.
function CaseService.getCase(caseId: string): Types.CaseDefinition?
	return CaseRegistry.get(caseId)
end

-- Suspects and locations are authored per case (Types.SuspectDefinition,
-- Types.LocationDefinition) and read-only here; no case id is ever
-- hardcoded so any registered case can use these accessors. Server-side
-- only for now: nothing sends this data to the client yet.
function CaseService.getSuspects(caseId: string): { Types.SuspectDefinition }
	local caseDef = CaseRegistry.get(caseId)
	if not caseDef then
		return {}
	end
	return caseDef.suspects
end

function CaseService.getSuspect(caseId: string, suspectId: string): Types.SuspectDefinition?
	for _, suspect in ipairs(CaseService.getSuspects(caseId)) do
		if suspect.id == suspectId then
			return suspect
		end
	end
	return nil
end

function CaseService.getLocations(caseId: string): { Types.LocationDefinition }
	local caseDef = CaseRegistry.get(caseId)
	if not caseDef then
		return {}
	end
	return caseDef.locations
end

function CaseService.getLocation(caseId: string, locationId: string): Types.LocationDefinition?
	for _, location in ipairs(CaseService.getLocations(caseId)) do
		if location.id == locationId then
			return location
		end
	end
	return nil
end

-- Builds the client-facing case payload. Deliberately limited to briefing
-- presentation data: undiscovered evidence and timeline events must never be
-- exposed. Per-player progress is delivered separately (see EvidenceService,
-- TimelineService, ObjectiveService) and only ever contains discovered state.
function CaseService.buildClientPayload(player: Player)
	local data = PlayerDataService.require(player)
	local caseDef = CaseRegistry.get(data.caseState.caseId)
	if not caseDef then
		return nil
	end
	local payload: Types.CasePayload = {
		briefing = {
			id = caseDef.id,
			title = caseDef.title,
			description = caseDef.description,
			time = if caseDef.setting then caseDef.setting.time else nil,
			place = if caseDef.setting then caseDef.setting.place else nil,
		},
		-- Phase 5.5: only the fact that the intro stands in for the briefing;
		-- the scene itself travels when the server starts it.
		introReplacesBriefing = if caseDef.intro and caseDef.intro.replacesBriefing then true else nil,
	}
	return payload
end

-- Every objective prerequisite must reference another objective id that
-- actually exists in the same case. A dangling reference fails safe at
-- runtime (that objective can simply never unlock), but it is almost always
-- a config typo, so it is surfaced loudly at boot instead of silently.
local function validateObjectivePrerequisites(caseId: string, caseDef: Types.CaseDefinition)
	local objectiveIds: { [string]: boolean } = {}
	for _, objective in ipairs(caseDef.objectives) do
		objectiveIds[objective.id] = true
	end
	for _, objective in ipairs(caseDef.objectives) do
		if objective.prerequisites then
			for _, prerequisiteId in ipairs(objective.prerequisites) do
				if not objectiveIds[prerequisiteId] then
					log:warn("objective prerequisite references an unknown objective", {
						caseId = caseId,
						objectiveId = objective.id,
						prerequisite = prerequisiteId,
					})
				end
			end
		end
	end
end

function CaseService.start()
	-- Eagerly validate the registry so misconfiguration surfaces at boot.
	local all = CaseRegistry.getAll()
	if next(all) == nil then
		log:error("no cases registered")
	end
	for caseId, caseDef in pairs(all) do
		validateObjectivePrerequisites(caseId, caseDef)
	end
end

return CaseService
