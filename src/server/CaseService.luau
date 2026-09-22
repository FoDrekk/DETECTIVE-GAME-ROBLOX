--!strict
--[[
	CaseService
	Owns case definitions and per-player case progress. Purely data-driven:
	no gameplay rules are hardcoded here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))
local CaseRegistry = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CaseRegistry"))
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
		},
	}
	return payload
end

function CaseService.start()
	-- Eagerly validate the registry so misconfiguration surfaces at boot.
	local all = CaseRegistry.getAll()
	if next(all) == nil then
		log:error("no cases registered")
	end
end

return CaseService
