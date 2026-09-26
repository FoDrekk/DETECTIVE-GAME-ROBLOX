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

	M9 -- the investigator draws the conclusions. A contradiction authored
	with `claim` never unlocks by itself: the player pairs the two facts in
	the case file (claimContradiction), or shows the evidence to the person
	who said the other thing (ConversationService.onPresented tells us which
	contradiction that presentation claims). A deduction
	authored with a `question` becomes an open question once its facts are
	known, and unlocks only when the player picks the right answer
	(answerDeduction). Everything is still checked here, against case data,
	from the player's own facts; a miss says nothing beyond "that doesn't
	hold", counts as a mistake, and briefly locks out the next try so the
	answer can't simply be brute-forced by clicking.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local CaseService = require(script.Parent:WaitForChild("CaseService"))
local EvidenceService = require(script.Parent:WaitForChild("EvidenceService"))
local ConversationService = require(script.Parent:WaitForChild("ConversationService"))
local StoryEvents = require(script.Parent:WaitForChild("StoryEvents"))

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local log = Logger.scoped("ReasoningService")

local ReasoningService = {}

local reasoningUpdatedEvent: BindableEvent = Instance.new("BindableEvent")
local feedbackEvent: BindableEvent = Instance.new("BindableEvent")

function ReasoningService.onUpdated(): BindableEvent
	return reasoningUpdatedEvent
end

-- M9: fired (player, Types.ReasoningFeedbackPayload) after every claim or
-- answer, so the case file can say how it went.
function ReasoningService.onFeedback(): BindableEvent
	return feedbackEvent
end

-- M9: when each player may next try a connection after a miss (os.clock
-- seconds). Not case state: a replay or a rejoin starts fresh.
local lockedUntil: { [Player]: number } = {}

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
	local payload: Types.ReasoningPayload = {
		statements = {},
		contradictions = {},
		deductions = {},
		relatedEvidence = {},
		evidence = {},
		openQuestions = {},
	}
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

	-- M9: the evidence this player can pair against a statement.
	for _, evidence in ipairs(caseDef.evidence) do
		local discovered = data.caseState.discovered[evidence.id]
		if discovered then
			table.insert(payload.evidence, {
				id = discovered.id,
				name = discovered.name,
				details = discovered.details or discovered.description,
			})
		end
	end

	-- M9: questions whose facts are all known and that are still open.
	for _, deduction in ipairs(caseDef.deductions) do
		local question = deduction.question
		if question and not data.caseState.unlockedDeductions[deduction.id] then
			local basedOn = {}
			local ready = true
			for _, fact in ipairs(deduction.requiredFacts) do
				local summary = if isFactKnown(player, fact) then factSummary(player, fact) else nil
				if not summary then
					ready = false
					break
				end
				table.insert(basedOn, summary)
			end
			if ready then
				local options = {}
				for _, option in ipairs(question.options) do
					table.insert(options, { id = option.id, text = option.text })
				end
				table.insert(payload.openQuestions, {
					id = deduction.id,
					prompt = question.prompt,
					options = options,
					basedOn = basedOn,
				})
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
			not contradiction.claim
			and not data.caseState.unlockedContradictions[contradiction.id]
			and isFactKnown(player, contradiction.left)
			and isFactKnown(player, contradiction.right)
		then
			data.caseState.unlockedContradictions[contradiction.id] = true
			StoryEvents.publish("ContradictionUnlocked", player, { contradictionId = contradiction.id })
			log:info("contradiction unlocked", { player = player.Name, contradictionId = contradiction.id })
		end
	end

	for _, deduction in ipairs(caseDeductions(data.caseState.caseId)) do
		if not deduction.question and not data.caseState.unlockedDeductions[deduction.id] then
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

--------------------------------------------------------------------------
-- M9: connections the investigator makes
--------------------------------------------------------------------------

local function sameFact(a: Types.FactReference, b: Types.FactReference): boolean
	return a.kind == b.kind and a.id == b.id
end

-- A client-supplied fact reference, checked for shape only.
local function readFact(value: any): Types.FactReference?
	if type(value) ~= "table" then
		return nil
	end
	local kind, id = value.kind, value.id
	if (kind ~= "Evidence" and kind ~= "Statement") or type(id) ~= "string" or #id == 0 or #id > 64 then
		return nil
	end
	return { kind = kind, id = id }
end

local function unlockContradiction(player: Player, data: Types.PlayerData, contradiction: Types.ContradictionDefinition)
	data.caseState.unlockedContradictions[contradiction.id] = true
	StoryEvents.publish("ContradictionUnlocked", player, { contradictionId = contradiction.id })
	log:info("contradiction claimed", { player = player.Name, contradictionId = contradiction.id })
end

local function miss(player: Player, data: Types.PlayerData)
	data.caseState.reasoningMistakes += 1
	lockedUntil[player] = os.clock() + Config.Reasoning.MissCooldown
end

local function coolingDown(player: Player): boolean
	local untilClock = lockedUntil[player]
	return untilClock ~= nil and os.clock() < untilClock
end

local function feedback(player: Player, result: Types.ReasoningFeedbackPayload)
	feedbackEvent:Fire(player, result)
end

--[[
	The investigator says two facts don't add up. `a` and `b` are fact
	references ({ kind, id }) in either order. Only facts this player already
	knows can be paired; the pair must be an authored contradiction to hold.
	Returns the result string (see Types.ReasoningFeedbackPayload).
]]
function ReasoningService.claimContradiction(player: Player, a: any, b: any): string
	local data = PlayerDataService.get(player)
	local left, right = readFact(a), readFact(b)
	local result: string
	local label: string? = nil
	if not data or not left or not right or sameFact(left, right) then
		result = "invalid"
	elseif not isFactKnown(player, left) or not isFactKnown(player, right) then
		result = "invalid"
	elseif coolingDown(player) then
		result = "cooldown"
	else
		result = "no-conflict"
		for _, contradiction in ipairs(caseContradictions(data.caseState.caseId)) do
			local matches = (sameFact(contradiction.left, left) and sameFact(contradiction.right, right))
				or (sameFact(contradiction.left, right) and sameFact(contradiction.right, left))
			if matches then
				label = contradiction.label
				if data.caseState.unlockedContradictions[contradiction.id] then
					result = "already"
				else
					unlockContradiction(player, data, contradiction)
					result = "claimed"
				end
				break
			end
		end
		if result == "no-conflict" then
			miss(player, data)
			log:info("claim did not hold", { player = player.Name, left = left.id, right = right.id })
		end
	end
	feedback(player, { kind = "Claim", result = result :: any, label = label })
	if result == "claimed" then
		ReasoningService.sendCurrent(player)
	end
	return result
end

--[[
	The investigator answers an open question. Only a question whose facts
	are all known (so it is on this player's screen) can be answered.
]]
function ReasoningService.answerDeduction(player: Player, deductionId: any, optionId: any): string
	local data = PlayerDataService.get(player)
	local result: string = "invalid"
	local label: string? = nil
	if data and type(deductionId) == "string" and type(optionId) == "string" then
		for _, deduction in ipairs(caseDeductions(data.caseState.caseId)) do
			local question = deduction.question
			if deduction.id == deductionId and question then
				local ready = true
				for _, fact in ipairs(deduction.requiredFacts) do
					if not isFactKnown(player, fact) then
						ready = false
						break
					end
				end
				if data.caseState.unlockedDeductions[deduction.id] then
					result = "already"
					label = deduction.label
				elseif not ready then
					result = "invalid"
				elseif coolingDown(player) then
					result = "cooldown"
				elseif optionId == question.answer then
					data.caseState.unlockedDeductions[deduction.id] = true
					StoryEvents.publish("DeductionUnlocked", player, { deductionId = deduction.id })
					log:info("deduction answered", { player = player.Name, deductionId = deduction.id })
					result = "correct"
					label = deduction.label
				else
					miss(player, data)
					result = "wrong"
				end
				break
			end
		end
	end
	feedback(player, { kind = "Answer", result = result :: any, label = label })
	if result == "correct" or result == "wrong" then
		-- A correct answer closes the question; either way the case file is
		-- re-sent so it matches the server.
		ReasoningService.sendCurrent(player)
	end
	return result
end

-- Evidence shown in a conversation (ConversationService). A presentation
-- that landed may claim a contradiction. One that didn't is not a mistake:
-- showing people things is how an investigator explores.
local function onEvidencePresented(player: Player, info: { landed: boolean, claims: string? })
	local data = PlayerDataService.get(player)
	if not data or not info.landed then
		return
	end
	local claims = info.claims
	if type(claims) ~= "string" or data.caseState.unlockedContradictions[claims] then
		return
	end
	for _, contradiction in ipairs(caseContradictions(data.caseState.caseId)) do
		if contradiction.id == claims then
			if isFactKnown(player, contradiction.left) and isFactKnown(player, contradiction.right) then
				unlockContradiction(player, data, contradiction)
				ReasoningService.sendCurrent(player)
			else
				log:warn("presentation claims a contradiction whose facts are not both known", {
					player = player.Name,
					contradictionId = claims,
				})
			end
			return
		end
	end
	log:warn("presentation claims an unknown contradiction", { player = player.Name, contradictionId = claims })
end

function ReasoningService.start()
	StoryEvents.on("EvidenceDiscovered", function(player: Player, _data: { [string]: any })
		ReasoningService.evaluate(player)
	end)
	StoryEvents.on("StatementUnlocked", function(player: Player, _data: { [string]: any })
		ReasoningService.evaluate(player)
	end)
	ConversationService.onPresented(onEvidencePresented)
	game:GetService("Players").PlayerRemoving:Connect(function(player: Player)
		lockedUntil[player] = nil
	end)
	log:debug("started")
end

return ReasoningService
