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
local StoryEvents = require(script.Parent:WaitForChild("StoryEvents"))

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
	evidenceId: string?,
	targetName: string?
): boolean
	if requirement.evidence and requirement.evidence ~= evidenceId then
		return false
	end
	if requirement.interaction and requirement.interaction ~= kind then
		return false
	end
	if requirement.target and requirement.target ~= targetName then
		return false
	end
	-- A requirement with no constraint at all cannot be satisfied by interaction.
	if not requirement.evidence and not requirement.interaction and not requirement.target then
		return false
	end
	return true
end

-- Has every objective this one depends on already been completed? An
-- objective with no prerequisites is available from the start (subject to
-- its authored position). Referencing an unknown objective id fails safe:
-- that prerequisite can never be satisfied (see CaseService's boot-time
-- validation, which warns about this misconfiguration).
local function prerequisitesMet(objective: Types.ObjectiveDefinition, data: Types.PlayerData): boolean
	local prereqs = objective.prerequisites
	if not prereqs or #prereqs == 0 then
		return true
	end
	for _, prerequisiteId in ipairs(prereqs) do
		if not data.caseState.completedObjectives[prerequisiteId] then
			return false
		end
	end
	return true
end

-- The single active objective: the first not-yet-completed objective (in
-- authored order) whose prerequisites are satisfied. Returns nil once every
-- objective is complete. This replaces a hardcoded "objectives[1]" and is
-- the one place that decides what a player is currently working toward.
local function getActiveObjective(data: Types.PlayerData): Types.ObjectiveDefinition?
	for _, objective in ipairs(caseObjectives(data.caseState.caseId)) do
		if not data.caseState.completedObjectives[objective.id] and prerequisitesMet(objective, data) then
			return objective
		end
	end
	return nil
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

-- Fire the current active objective's state to a player (used on join/sync,
-- and whenever completing an objective unlocks the next one). No-op once
-- every objective is complete: there is nothing active left to present.
function ObjectiveService.sendCurrent(player: Player)
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	local objective = getActiveObjective(data)
	if not objective then
		return
	end
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
	targetName  : the interacted instance's Name, for requirements gated on a
	              specific named interactable rather than evidence/kind alone

	Only objectives that are unlocked (prerequisites met) and not yet
	complete are evaluated, so progress can never be credited to a locked
	objective. Returns true if any requirement advanced.
]]
function ObjectiveService.recordInteraction(
	player: Player,
	kind: Types.InteractionKind,
	evidenceId: string?,
	targetName: string?
): boolean
	local data = PlayerDataService.get(player)
	if not data then
		return false
	end

	local objectives = caseObjectives(data.caseState.caseId)
	if #objectives == 0 then
		return false
	end

	local activeBefore = getActiveObjective(data)
	local activeBeforeId = activeBefore and activeBefore.id

	local advanced = false
	for _, objective in ipairs(objectives) do
		if not data.caseState.completedObjectives[objective.id] and prerequisitesMet(objective, data) then
			local progress = ensureProgress(data, objective.id)
			local objectiveAdvanced = false
			for _, requirement in ipairs(objective.requirements) do
				if not progress[requirement.id] and requirementSatisfied(requirement, kind, evidenceId, targetName) then
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
					StoryEvents.publish("ObjectiveCompleted", player, { objectiveId = objective.id })
				end
				objectiveUpdatedEvent:Fire(player, payload, justCompleted)
			end
		end
	end

	if advanced then
		local activeAfter = getActiveObjective(data)
		if activeAfter and (activeAfter :: Types.ObjectiveDefinition).id ~= activeBeforeId then
			-- Completion unlocked a different active objective; push its
			-- initial state now instead of waiting for the next interaction.
			ObjectiveService.sendCurrent(player)
		end
	end

	return advanced
end

-- The id of the player's current active objective (see getActiveObjective),
-- or nil once every objective is complete. A synchronous read of the same
-- decision sendCurrent broadcasts, for callers (including tests) that need
-- the answer without listening for an event.
function ObjectiveService.getActiveObjectiveId(player: Player): string?
	local data = PlayerDataService.get(player)
	if not data then
		return nil
	end
	local objective = getActiveObjective(data)
	return objective and objective.id
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
