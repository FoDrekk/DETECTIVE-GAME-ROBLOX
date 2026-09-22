--!strict
--[[
	ObjectiveService
	Authoritative, data-driven objective tracking.

	Objectives and their requirements come entirely from case data
	(CaseDefinition.objectives). This service knows nothing about CASE-001
	specifically — it evaluates generic requirements against per-player
	progress and reports updates.

	Progress is driven by two observable facts:
	  * evidence discovered  (EvidenceService)
	  * interaction performed (InteractionService)

	Both are server-authoritative. The client never supplies progress state.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Signals = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signals"))
local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local CaseService = require(script.Parent:WaitForChild("CaseService"))

local log = Logger.scoped("ObjectiveService")

local ObjectiveService = {}

local objectiveUpdatedEvent: BindableEvent = Instance.new("BindableEvent")

function ObjectiveService.onUpdated(): BindableEvent
	return objectiveUpdatedEvent
end

local function caseObjectives(caseId: string): { Types.ObjectiveDefinition }
	local caseDef = CaseService.getCase(caseId)
	if not caseDef then
		return {}
	end
	return caseDef.objectives
end

local function findObjective(caseId: string, objectiveId: string): Types.ObjectiveDefinition?
	for _, objective in ipairs(caseObjectives(caseId)) do
		if objective.id == objectiveId then
			return objective
		end
	end
	return nil
end

-- Ensure the per-player progress table exists for an objective.
local function ensureProgress(data: Types.PlayerData, objectiveId: string): { [string]: boolean }
	local progress = data.caseState.objectiveProgress[objectiveId]
	if not progress then
		progress = {}
		data.caseState.objectiveProgress[objectiveId] = progress
	end
	return progress
end

-- Does an observed interaction satisfy this requirement?
local function requirementSatisfied(
	requirement: Types.ObjectiveRequirement,
	kind: Types.InteractionKind?,
	evidenceId: string?
): boolean
	if requirement.evidence and requirement.evidence ~= evidenceId then
		return false
	end
	if requirement.interaction and requirement.interaction ~= kind then
		return false
	end
	-- A requirement with neither constraint cannot be satisfied by interaction.
	if not requirement.evidence and not requirement.interaction then
		return false
	end
	return true
end

local function objectiveIsComplete(objective: Types.ObjectiveDefinition, progress: { [string]: boolean }): boolean
	for _, requirement in ipairs(objective.requirements) do
		if not progress[requirement.id] then
			return false
		end
	end
	return true
end

local function buildPayload(
	objective: Types.ObjectiveDefinition,
	progress: { [string]: boolean }
): Types.ObjectivePayload
	local requirements = {}
	for _, requirement in ipairs(objective.requirements) do
		table.insert(requirements, {
			id = requirement.id,
			label = requirement.label,
			completed = progress[requirement.id] == true,
		})
	end
	return {
		objective = {
			id = objective.id,
			title = objective.title,
			description = objective.description,
			completed = objectiveIsComplete(objective, progress),
			requirements = requirements,
		},
		allComplete = false,
	}
end

-- Fire the current objective state to a player (used on join/sync).
function ObjectiveService.sendCurrent(player: Player)
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	local objectives = caseObjectives(data.caseState.caseId)
	if #objectives == 0 then
		return
	end
	-- Phase 2A presents the first objective as the active one.
	local objective = objectives[1]
	local progress = ensureProgress(data, objective.id)
	local payload = buildPayload(objective, progress)
	payload.allComplete = objectiveIsComplete(objective, progress)
	objectiveUpdatedEvent:Fire(player, payload)
end

--[[
	Record progress for an interaction. Called only after the interaction has
	been validated by InteractionService.

	kind        : the interaction performed
	evidenceId  : the evidence tied to the interaction, if any
	interacted  : true when a valid interaction actually occurred (so evidence-less
	              requirements can still advance)

	Returns true if any requirement advanced.
]]
function ObjectiveService.recordInteraction(
	player: Player,
	kind: Types.InteractionKind,
	evidenceId: string?
): boolean
	local data = PlayerDataService.get(player)
	if not data then
		return false
	end

	local objectives = caseObjectives(data.caseState.caseId)
	if #objectives == 0 then
		return false
	end

	local advanced = false
	for _, objective in ipairs(objectives) do
		local progress = ensureProgress(data, objective.id)
		local objectiveAdvanced = false
		for _, requirement in ipairs(objective.requirements) do
			if not progress[requirement.id] and requirementSatisfied(requirement, kind, evidenceId) then
				progress[requirement.id] = true
				objectiveAdvanced = true
				advanced = true
			end
		end

		if objectiveAdvanced then
			local payload = buildPayload(objective, progress)
			payload.allComplete = objectiveIsComplete(objective, progress)
			local justCompleted = payload.objective.completed
				and not data.caseState.completedObjectives[objective.id]
			if justCompleted then
				data.caseState.completedObjectives[objective.id] = true
				log:info("objective completed", {
					player = player.Name,
					objectiveId = objective.id,
				})
			end
			objectiveUpdatedEvent:Fire(player, payload, justCompleted)
		end
	end

	return advanced
end

-- Ordered objective definitions for a player's active case.
function ObjectiveService.getObjectives(player: Player): { Types.ObjectiveDefinition }
	local data = PlayerDataService.get(player)
	if not data then
		return {}
	end
	return caseObjectives(data.caseState.caseId)
end

function ObjectiveService.getProgress(player: Player, objectiveId: string): { [string]: boolean }
	local data = PlayerDataService.get(player)
	if not data then
		return {}
	end
	local objective = findObjective(data.caseState.caseId, objectiveId)
	if not objective then
		return {}
	end
	return ensureProgress(data, objective.id)
end

function ObjectiveService.start()
	log:debug("started")
end

return ObjectiveService
