--!strict
--[[
	ReasoningService
	Authoritative evaluation of investigation reasoning: contradictions and
	deductions derived from already-discovered evidence and already-unlocked
	statements (Phase 2H).

	This service does not discover evidence or unlock statements itself --
	EvidenceService and ConversationService own those, and already publish
	StoryEvents ("EvidenceDiscovered", "StatementUnlocked") whenever a
	relevant fact changes. ReasoningService only subscribes to those events
	and re-evaluates the case's authored contradictions/deductions against
	the player's current facts -- deterministic and config-driven, never
	inferred from text, never fuzzy-matched.

	Deterministic distinction the whole system is built around:
	  Contradiction -- two independently discovered/unlocked facts conflict.
	  Deduction     -- a conclusion unlocked once a defined set of facts are
	                   all known (the facts need not conflict with anything).

	Evaluation only runs in reaction to a relevant StoryEvent (evidence
	discovered or a statement unlocked) -- never on a timer, never per frame,
	never a full-case scan on every tick.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local CaseService = require(script.Parent:WaitForChild("CaseService"))
local EvidenceService = require(script.Parent:WaitForChild("EvidenceService"))
local ConversationService = require(script.Parent:WaitForChild("ConversationService"))
local StoryEvents = require(script.Parent:WaitForChild("StoryEvents"))

local log = Logger.scoped("ReasoningService")

local ReasoningService = {}

local reasoningUpdatedEvent: BindableEvent = Instance.new("BindableEvent")

function ReasoningService.onUpdated(): BindableEvent
	return reasoningUpdatedEvent
end

--------------------------------------------------------------------------
-- Fact resolution -- always through the fact's owning service (never a
-- duplicate evidence/statement contract).
--------------------------------------------------------------------------

local function isFactKnown(player: Player, fact: Types.FactReference): boolean
	if fact.kind == "Evidence" then
		return EvidenceService.isDiscovered(player, fact.id)
	elseif fact.kind == "Statement" then
		return ConversationService.isStatementUnlocked(player, fact.id)
	end
	return false
end

-- A short display name for an already-known fact. Only ever called once
-- isFactKnown has confirmed the fact is unlocked for this player, so this
-- can never leak a hidden evidence name or statement label.
local function factSummary(player: Player, fact: Types.FactReference): string?
	if fact.kind == "Evidence" then
		local ev = EvidenceService.getState(player)[fact.id]
		return ev and ev.name
	elseif fact.kind == "Statement" then
		local statement = ConversationService.getUnlockedStatement(player, fact.id)
		return statement and statement.label
	end
	return nil
end

--------------------------------------------------------------------------
-- Data lookups (always through CaseService; never a raw case table)
--------------------------------------------------------------------------

local function caseContradictions(caseId: string): { Types.ContradictionDefinition }
	local caseDef = CaseService.getCase(caseId)
	if not caseDef then
		return {}
	end
	return caseDef.contradictions
end

local function caseDeductions(caseId: string): { Types.DeductionDefinition }
	local caseDef = CaseService.getCase(caseId)
	if not caseDef then
		return {}
	end
	return caseDef.deductions
end

--------------------------------------------------------------------------
-- Payload building (spoiler-safe: only ever built for already-unlocked
-- contradictions/deductions, and fails safe -- omits, never errors -- if a
-- referenced fact can't be resolved).
--------------------------------------------------------------------------

local function buildContradictionPayload(
	player: Player,
	contradiction: Types.ContradictionDefinition
): Types.ContradictionPayload?
	local leftSummary = factSummary(player, contradiction.left)
	local rightSummary = factSummary(player, contradiction.right)
	if not leftSummary or not rightSummary then
		return nil
	end
	return {
		id = contradiction.id,
		label = contradiction.label,
		reason = contradiction.reason,
		leftSummary = leftSummary,
		rightSummary = rightSummary,
	}
end

local function buildDeductionPayload(player: Player, deduction: Types.DeductionDefinition): Types.DeductionPayload?
	local basedOn = {}
	for _, fact in ipairs(deduction.requiredFacts) do
		local summary = factSummary(player, fact)
		if not summary then
			return nil
		end
		table.insert(basedOn, summary)
	end
	return {
		id = deduction.id,
		label = deduction.label,
		basedOn = basedOn,
	}
end

--------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------

-- The player's complete currently-authorized reasoning state: every
-- unlocked statement, contradiction and deduction. Never includes anything
-- locked -- this is the only shape ever sent to a client.
function ReasoningService.getPayload(player: Player): Types.ReasoningPayload
	local data = PlayerDataService.get(player)
	local payload: Types.ReasoningPayload = { statements = {}, contradictions = {}, deductions = {}, relatedEvidence = {} }
	if not data then
		return payload
	end

	local caseDef = CaseService.getCase(data.caseState.caseId)
	if not caseDef then
		return payload
	end

	for _, statement in ipairs(caseDef.statements) do
		local unlocked = ConversationService.getUnlockedStatement(player, statement.id)
		if unlocked then
			table.insert(payload.statements, unlocked)
		end
	end

	for _, contradiction in ipairs(caseDef.contradictions) do
		if data.caseState.unlockedContradictions[contradiction.id] then
			local built = buildContradictionPayload(player, contradiction)
			if built then
				table.insert(payload.contradictions, built)
			end
		end
	end

	for _, deduction in ipairs(caseDef.deductions) do
		if data.caseState.unlockedDeductions[deduction.id] then
			local built = buildDeductionPayload(player, deduction)
			if built then
				table.insert(payload.deductions, built)
			end
		end
	end

	-- Phase 2O: cross-reference section for discovered evidence that authors
	-- relatedEvidenceIds, listing only already-discovered related names
	-- (spoiler-safe: an undiscovered related item never appears).
	for _, evidence in ipairs(caseDef.evidence) do
		local discovered = data.caseState.discovered[evidence.id]
		if discovered and evidence.relatedEvidenceIds and #evidence.relatedEvidenceIds > 0 then
			local relatedNames = {}
			for _, relatedId in ipairs(evidence.relatedEvidenceIds) do
				local relatedEvidence = data.caseState.discovered[relatedId]
				if relatedEvidence then
					table.insert(relatedNames, relatedEvidence.name)
				end
			end
			if #relatedNames > 0 then
				table.insert(payload.relatedEvidence, {
					id = discovered.id,
					name = discovered.name,
					related = relatedNames,
				})
			end
		end
	end

	return payload
end

function ReasoningService.sendCurrent(player: Player)
	reasoningUpdatedEvent:Fire(player, ReasoningService.getPayload(player))
end

-- Re-evaluate every authored contradiction/deduction against the player's
-- current facts, then always push the current payload. Idempotent: a
-- contradiction/deduction unlocks at most once (guarded by the unlockedX
-- check), so replaying the same event never publishes a second StoryEvent.
-- Called only in reaction to a relevant StoryEvent -- never polled, never a
-- per-frame scan.
--
-- sendCurrent runs unconditionally, not just when a contradiction/deduction
-- unlocks here: the payload also carries unlocked statements, which can
-- change on this same call (triggered by StatementUnlocked) with zero
-- contradictions/deductions involved -- CASE-001 today has none of either,
-- so gating this on "a contradiction/deduction changed" silently dropped
-- every statement update.
function ReasoningService.evaluate(player: Player)
	local data = PlayerDataService.get(player)
	if not data then
		return
	end

	for _, contradiction in ipairs(caseContradictions(data.caseState.caseId)) do
		if
			not data.caseState.unlockedContradictions[contradiction.id]
			and isFactKnown(player, contradiction.left)
			and isFactKnown(player, contradiction.right)
		then
			data.caseState.unlockedContradictions[contradiction.id] = true
			StoryEvents.publish("ContradictionUnlocked", player, { contradictionId = contradiction.id })
			log:info("contradiction unlocked", { player = player.Name, contradictionId = contradiction.id })
		end
	end

	for _, deduction in ipairs(caseDeductions(data.caseState.caseId)) do
		if not data.caseState.unlockedDeductions[deduction.id] then
			local allKnown = true
			for _, fact in ipairs(deduction.requiredFacts) do
				if not isFactKnown(player, fact) then
					allKnown = false
					break
				end
			end
			if allKnown then
				data.caseState.unlockedDeductions[deduction.id] = true
				StoryEvents.publish("DeductionUnlocked", player, { deductionId = deduction.id })
				log:info("deduction unlocked", { player = player.Name, deductionId = deduction.id })
			end
		end
	end

	ReasoningService.sendCurrent(player)
end

function ReasoningService.start()
	StoryEvents.on("EvidenceDiscovered", function(player: Player, _data: { [string]: any })
		ReasoningService.evaluate(player)
	end)
	StoryEvents.on("StatementUnlocked", function(player: Player, _data: { [string]: any })
		ReasoningService.evaluate(player)
	end)
	log:debug("started")
end

return ReasoningService
