--!strict
--[[
	AccusationService
	Server-authoritative, data-driven player accusation (Phase 2N).

	Once every objective in the active case is complete, the player may
	formally accuse a suspect. An accusation is a commitment: it is recorded
	once, is permanent, and is the only thing that authorizes the
	Investigation -> CaseClosed transition (GameStateService.requestConclude
	delegates its gameplay authorization here).

	This service does not discover evidence, unlock statements, or evaluate
	reasoning itself. It resolves everything through the services that own
	those facts (ObjectiveService for completion, ReasoningService's persisted
	unlockedContradictions/unlockedDeductions for support), and never invents
	story content: an accusation's `supportedBy` names only contradiction/
	deduction ids already authored in case data.

	The client supplies nothing but which accusation id it wants to make. The
	server decides whether the player is even eligible (all objectives
	complete) and whether the choice is consistent with the facts the player
	actually unlocked -- "supported" is never a claim that an accusation is
	the truth, only that the evidence this player gathered is consistent with
	it, exactly as the case data defines.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local CaseService = require(script.Parent:WaitForChild("CaseService"))
local ObjectiveService = require(script.Parent:WaitForChild("ObjectiveService"))
local StoryEvents = require(script.Parent:WaitForChild("StoryEvents"))

local log = Logger.scoped("AccusationService")

local AccusationService = {}

local accusationUpdatedEvent: BindableEvent = Instance.new("BindableEvent")

function AccusationService.onUpdated(): BindableEvent
	return accusationUpdatedEvent
end

----------------------------------------------------------------------
-- Data lookups (always through CaseService; never a raw case table)
----------------------------------------------------------------------

local function caseAccusations(caseId: string): { Types.AccusationDefinition }
	local caseDef = CaseService.getCase(caseId)
	if not caseDef or not caseDef.accusations then
		return {}
	end
	return caseDef.accusations
end

local function findAccusation(caseId: string, accusationId: string): Types.AccusationDefinition?
	for _, accusation in ipairs(caseAccusations(caseId)) do
		if accusation.id == accusationId then
			return accusation
		end
	end
	return nil
end

----------------------------------------------------------------------
-- Support resolution (read-only; never a copy of any fact)
----------------------------------------------------------------------

-- Is this accusation consistent with the facts the player actually
-- unlocked? True only when `supportedBy` is authored AND every referenced
-- contradiction/deduction has been unlocked by this player. An accusation
-- with no `supportedBy` (or one naming a fact the player never unlocked) is
-- reported unsupported -- honestly, never as an error.
local function isSupported(data: Types.PlayerData, accusation: Types.AccusationDefinition): (boolean, { string })
	local basedOn: { string } = {}
	local supportedBy = accusation.supportedBy
	if not supportedBy then
		return false, basedOn
	end

	local caseDef = CaseService.getCase(data.caseState.caseId)
	if not caseDef then
		return false, basedOn
	end

	local contradictions = supportedBy.contradictions or {}
	for _, contradictionId in ipairs(contradictions) do
		if not data.caseState.unlockedContradictions[contradictionId] then
			return false, basedOn
		end
		for _, contradiction in ipairs(caseDef.contradictions) do
			if contradiction.id == contradictionId then
				table.insert(basedOn, contradiction.label)
			end
		end
	end

	local deductions = supportedBy.deductions or {}
	for _, deductionId in ipairs(deductions) do
		if not data.caseState.unlockedDeductions[deductionId] then
			return false, basedOn
		end
		for _, deduction in ipairs(caseDef.deductions) do
			if deduction.id == deductionId then
				table.insert(basedOn, deduction.label)
			end
		end
	end

	-- An accusation that names no fact at all can never be "supported" by
	-- evidence the player gathered -- it is selectable, and reported as such.
	if #basedOn == 0 then
		return false, basedOn
	end
	return true, basedOn
end

local function buildOption(caseId: string, accusation: Types.AccusationDefinition): Types.AccusationOption
	local suspect = CaseService.getSuspect(caseId, accusation.suspectId)
	return {
		id = accusation.id,
		suspectId = accusation.suspectId,
		suspectName = suspect and suspect.name or accusation.suspectId,
		suspectRole = suspect and suspect.role,
		label = accusation.label,
	}
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

-- Has this player already made an accusation?
function AccusationService.hasAccusation(player: Player): boolean
	local data = PlayerDataService.get(player)
	return data ~= nil and data.caseState.accusationId ~= nil
end

-- The spoiler-safe accusation picker state. Only ever lists the case's
-- authored accusations (suspect ids/names the player can already see in the
-- world); never reveals which option is supported. `selected` is present
-- only once this player has already accused someone.
function AccusationService.getPayload(player: Player): Types.AccusationPayload
	local data = PlayerDataService.get(player)
	local payload: Types.AccusationPayload = { options = {} }
	if not data then
		return payload
	end

	for _, accusation in ipairs(caseAccusations(data.caseState.caseId)) do
		table.insert(payload.options, buildOption(data.caseState.caseId, accusation))
	end

	local selectedId = data.caseState.accusationId
	if selectedId then
		local accusation = findAccusation(data.caseState.caseId, selectedId)
		if accusation then
			payload.selected = buildOption(data.caseState.caseId, accusation)
		end
	end

	return payload
end

-- The player's own formal accusation, resolved into a factual statement
-- about whether the evidence they gathered is consistent with it. Returns
-- nil if they have not accused anyone. Never claims who committed anything.
function AccusationService.getResolution(player: Player): Types.AccusationResolution?
	local data = PlayerDataService.get(player)
	if not data then
		return nil
	end
	local accusationId = data.caseState.accusationId
	if not accusationId then
		return nil
	end
	local accusation = findAccusation(data.caseState.caseId, accusationId)
	if not accusation then
		return nil
	end

	local option = buildOption(data.caseState.caseId, accusation)
	local supported, basedOn = isSupported(data, accusation)
	return {
		id = accusation.id,
		suspectId = option.suspectId,
		suspectName = option.suspectName,
		label = option.label,
		supported = supported,
		basedOn = basedOn,
	}
end

--[[
	Make a formal accusation. Server-authoritative and idempotent:

	  * rejects unless the player exists, the accusation id is authored, and
	    every objective in the case is already complete;
	  * an already-recorded accusation is permanent -- repeating the same
	    choice is a safe no-op (returns false), and a different choice is
	    rejected. Nothing is ever re-published for an existing accusation.

	Returns true only when this call recorded the accusation for the first
	time. The client never supplies or influences eligibility.
]]
function AccusationService.accuse(player: Player, accusationId: string): boolean
	local data = PlayerDataService.get(player)
	if not data then
		return false
	end
	if type(accusationId) ~= "string" or accusationId == "" then
		return false
	end
	if data.caseState.accusationId then
		-- Already committed: permanent, and never re-published.
		return false
	end
	if ObjectiveService.getActiveObjectiveId(player) ~= nil then
		-- An accusation is only meaningful once there is nothing left to
		-- investigate. Never trust any client-side claim of completion.
		return false
	end

	local accusation = findAccusation(data.caseState.caseId, accusationId)
	if not accusation then
		return false
	end

	data.caseState.accusationId = accusationId
	log:info("accusation made", {
		player = player.Name,
		accusationId = accusationId,
		suspectId = accusation.suspectId,
	})
	StoryEvents.publish("AccusationMade", player, { accusationId = accusationId })
	AccusationService.sendCurrent(player)
	return true
end

function AccusationService.sendCurrent(player: Player)
	accusationUpdatedEvent:Fire(player, AccusationService.getPayload(player))
end

function AccusationService.start()
	log:debug("started")
end

return AccusationService
