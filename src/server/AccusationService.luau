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

	M9: a case may set `accusationRules`. `opensAfter` lets the investigator
	accuse once a given objective is done, with the rest of the case still
	open, which is the risk of accusing early. `requiresCase` means an
	accusation also names a motive (a deduction the player established) and
	a proof (a contradiction the player established); the verdict is then
	graded: Solved (culprit, and both hold for them), Unproven (culprit, but
	the case named doesn't hold), or Wrong (someone else). Cases without
	rules behave exactly as before.
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

local function caseRules(caseId: string): Types.AccusationRules
	local caseDef = CaseService.getCase(caseId)
	return (caseDef and caseDef.accusationRules) or {}
end

local function labelFor(list: { any }, id: string?): string?
	if not id then
		return nil
	end
	for _, item in ipairs(list) do
		if item.id == id then
			return item.label
		end
	end
	return nil
end

-- M9: does the named motive and proof hold for this accusation?
local function caseHolds(data: Types.PlayerData, accusation: Types.AccusationDefinition): boolean
	local motive = data.caseState.accusationMotive
	local proof = data.caseState.accusationProof
	if not motive or not proof then
		return false
	end
	return table.find(accusation.motives or {}, motive) ~= nil and table.find(accusation.proofs or {}, proof) ~= nil
end

--[[
	Phase 2P: why an Unproven or Wrong verdict didn't hold, in one sentence,
	derived only from data already authored on the accusation (its `motives`/
	`proofs`) and the labels of what the player actually named. Never states
	the true motive/proof for this suspect (that would be the solution,
	handed out before or instead of finding it) -- only whether the pairing
	the player committed to is one this accusation recognises. Nil once the
	case holds (Solved) or if the case doesn't use motive/proof grading.
]]
local function explainShortfall(
	data: Types.PlayerData,
	accusation: Types.AccusationDefinition,
	caseDef: Types.CaseDefinition
): string?
	local motiveId = data.caseState.accusationMotive
	local proofId = data.caseState.accusationProof
	if not motiveId or not proofId then
		return nil
	end
	local motiveOk = table.find(accusation.motives or {}, motiveId) ~= nil
	local proofOk = table.find(accusation.proofs or {}, proofId) ~= nil
	if motiveOk and proofOk then
		return nil
	end

	local suspect = CaseService.getSuspect(data.caseState.caseId, accusation.suspectId)
	local suspectName = suspect and suspect.name or accusation.suspectId
	local motiveLabel = labelFor(caseDef.deductions, motiveId) or "the motive you named"
	local proofLabel = labelFor(caseDef.contradictions, proofId) or "the proof you named"

	if not motiveOk and not proofOk then
		return `Neither holds up against {suspectName}: "{motiveLabel}" isn't why, `
			.. `and "{proofLabel}" doesn't place them there.`
	elseif not motiveOk then
		return `"{motiveLabel}" isn't why {suspectName} would have done it.`
	end
	return `"{proofLabel}" doesn't put {suspectName} there.`
end

-- P7: the Solved epilogue for how far this player actually pushed -- the
-- first authored variant whose facts they have all established, else the
-- plain `solvedEpilogue`. Reads only this player's own evidence/statements.
local function solvedEpilogueFor(data: Types.PlayerData, solution: Types.CaseSolution): string?
	for _, variant in ipairs(solution.solvedVariants or {}) do
		local allKnown = #variant.requiredFacts > 0
		for _, fact in ipairs(variant.requiredFacts) do
			local known = if fact.kind == "Evidence"
				then data.caseState.discovered[fact.id] ~= nil
				else data.caseState.unlockedStatements[fact.id] == true
			if not known then
				allKnown = false
				break
			end
		end
		if allKnown then
			return variant.epilogue
		end
	end
	return solution.solvedEpilogue
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

-- M9: may this player accuse right now? Before M9 (and for any case without
-- `accusationRules.opensAfter`) only once every objective is complete.
function AccusationService.isOpen(player: Player): boolean
	local data = PlayerDataService.get(player)
	if not data then
		return false
	end
	local opensAfter = caseRules(data.caseState.caseId).opensAfter
	if opensAfter then
		return data.caseState.completedObjectives[opensAfter] == true
	end
	return ObjectiveService.getActiveObjectiveId(player) == nil
end

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
	local payload: Types.AccusationPayload = {
		options = {},
		open = false,
		requiresCase = false,
		motives = {},
		proofs = {},
	}
	if not data then
		return payload
	end

	for _, accusation in ipairs(caseAccusations(data.caseState.caseId)) do
		table.insert(payload.options, buildOption(data.caseState.caseId, accusation))
	end
	payload.open = AccusationService.isOpen(player)

	-- M9: the motives and proofs on offer are exactly what this player has
	-- established, in case order; nothing says which fits whom.
	if caseRules(data.caseState.caseId).requiresCase then
		payload.requiresCase = true
		local caseDef = CaseService.getCase(data.caseState.caseId)
		if caseDef then
			for _, deduction in ipairs(caseDef.deductions) do
				if data.caseState.unlockedDeductions[deduction.id] then
					table.insert(payload.motives, { id = deduction.id, label = deduction.label })
				end
			end
			for _, contradiction in ipairs(caseDef.contradictions) do
				if data.caseState.unlockedContradictions[contradiction.id] then
					table.insert(payload.proofs, { id = contradiction.id, label = contradiction.label })
				end
			end
		end
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
	if caseRules(data.caseState.caseId).requiresCase then
		-- M9: the case the player actually made, not everything they found.
		local caseDef = CaseService.getCase(data.caseState.caseId)
		supported = caseHolds(data, accusation)
		basedOn = {}
		if caseDef then
			local motive = labelFor(caseDef.deductions, data.caseState.accusationMotive)
			local proof = labelFor(caseDef.contradictions, data.caseState.accusationProof)
			if motive then
				table.insert(basedOn, motive)
			end
			if proof then
				table.insert(basedOn, proof)
			end
		end
	end
	return {
		id = accusation.id,
		suspectId = option.suspectId,
		suspectName = option.suspectName,
		label = option.label,
		supported = supported,
		basedOn = basedOn,
	}
end

-- The case's true answer measured against this player's committed
-- accusation (M2). Nil until they have accused, or if the case authors no
-- solution -- the answer never leaves the server before the player commits.
function AccusationService.getVerdict(player: Player): Types.CaseVerdict?
	local data = PlayerDataService.get(player)
	if not data then
		return nil
	end
	local accusationId = data.caseState.accusationId
	if not accusationId then
		return nil
	end
	local caseDef = CaseService.getCase(data.caseState.caseId)
	local solution = caseDef and caseDef.solution
	local accusation = findAccusation(data.caseState.caseId, accusationId)
	if not solution or not accusation then
		return nil
	end
	local culprit = CaseService.getSuspect(data.caseState.caseId, solution.culpritSuspectId)
	local correct = accusation.suspectId == solution.culpritSuspectId
	local grade: "Solved" | "Unproven" | "Wrong" = "Wrong"
	local epilogue: string? = accusation.wrongEpilogue
	if correct then
		if caseRules(data.caseState.caseId).requiresCase and not caseHolds(data, accusation) then
			grade = "Unproven"
			epilogue = solution.unprovenEpilogue
		else
			grade = "Solved"
			epilogue = solvedEpilogueFor(data, solution)
		end
	end
	-- Phase 2P: only Unproven/Wrong ever need explaining; a Solved case has
	-- nothing left to account for.
	local shortfall: string? = nil
	if grade ~= "Solved" and caseRules(data.caseState.caseId).requiresCase then
		shortfall = explainShortfall(data, accusation, caseDef :: Types.CaseDefinition)
	end
	return {
		correct = correct,
		culpritName = if culprit then culprit.name else solution.culpritSuspectId,
		reveal = solution.reveal,
		grade = grade,
		epilogue = epilogue,
		shortfall = shortfall,
	}
end

--[[
	Make a formal accusation. Server-authoritative and idempotent:

	  * rejects unless the player exists, the accusation id is authored, and
	    accusing is open (every objective complete, or the case's
	    `opensAfter` objective, M9);
	  * when the case requires it (M9), rejects unless `motiveId` names a
	    deduction and `proofId` a contradiction this player has established
	    (which ones fit is judged only in the verdict);
	  * an already-recorded accusation is permanent -- repeating the same
	    choice is a safe no-op (returns false), and a different choice is
	    rejected. Nothing is ever re-published for an existing accusation.

	Returns true only when this call recorded the accusation for the first
	time. The client never supplies or influences eligibility.
]]
function AccusationService.accuse(player: Player, accusationId: string, motiveId: string?, proofId: string?): boolean
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
	if not AccusationService.isOpen(player) then
		-- Never trust any client-side claim of progress.
		return false
	end

	local accusation = findAccusation(data.caseState.caseId, accusationId)
	if not accusation then
		return false
	end

	if caseRules(data.caseState.caseId).requiresCase then
		if type(motiveId) ~= "string" or not data.caseState.unlockedDeductions[motiveId] then
			return false
		end
		if type(proofId) ~= "string" or not data.caseState.unlockedContradictions[proofId] then
			return false
		end
		data.caseState.accusationMotive = motiveId
		data.caseState.accusationProof = proofId
	end

	data.caseState.accusationId = accusationId
	log:info("accusation made", {
		player = player.Name,
		accusationId = accusationId,
		suspectId = accusation.suspectId,
		motive = data.caseState.accusationMotive,
		proof = data.caseState.accusationProof,
	})
	StoryEvents.publish("AccusationMade", player, { accusationId = accusationId })
	AccusationService.sendCurrent(player)
	return true
end

function AccusationService.sendCurrent(player: Player)
	accusationUpdatedEvent:Fire(player, AccusationService.getPayload(player))
end

function AccusationService.start()
	-- M9: whether accusing is open, and the motives and proofs on offer,
	-- change as the investigation moves; keep the client's picker current.
	local function resend(player: Player, _data: { [string]: any })
		if PlayerDataService.get(player) then
			AccusationService.sendCurrent(player)
		end
	end
	StoryEvents.on("ObjectiveCompleted", resend)
	StoryEvents.on("ContradictionUnlocked", resend)
	StoryEvents.on("DeductionUnlocked", resend)
	log:debug("started")
end

return AccusationService
