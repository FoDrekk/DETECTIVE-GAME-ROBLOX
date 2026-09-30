--!strict
--[[
	CASE-001 ("The Last Call") story tests. Plays the investigation through
	the real services the way InteractionService and the client drive them:
	discovering clues, holding branching conversations (picking choices by
	id), reasoning, objectives, the timeline and the accusation.

	Reasoning/objective reactions travel over deferred StoryEvents in the
	engine; like the other service tests, `sync` runs that evaluation
	directly so each assertion sees a settled state.
]]
return function(t)
	local ServerScriptService = game:GetService("ServerScriptService")
	local Server = ServerScriptService:WaitForChild("Server")
	local PlayerDataService = require(Server:WaitForChild("PlayerDataService"))
	local ConversationService = require(Server:WaitForChild("ConversationService"))
	local EvidenceService = require(Server:WaitForChild("EvidenceService"))
	local ObjectiveService = require(Server:WaitForChild("ObjectiveService"))
	local ReasoningService = require(Server:WaitForChild("ReasoningService"))
	local TimelineService = require(Server:WaitForChild("TimelineService"))
	local AccusationService = require(Server:WaitForChild("AccusationService"))
	local GameStateService = require(Server:WaitForChild("GameStateService"))
	local CaseRegistry = require(game:GetService("ServerStorage"):WaitForChild("Config"):WaitForChild("CaseRegistry"))
	local expect = t.expect

	local caseDef = CaseRegistry.get("CASE-001") :: any

	-- People are named in case data; tests ask it, so a rename never needs
	-- editing them again (Phase 5.2).
	local function nameOf(suspectId: string): string
		for _, suspect in ipairs(caseDef.suspects) do
			if suspect.id == suspectId then
				return suspect.name
			end
		end
		error(`no suspect {suspectId}`)
	end
	local function firstNameOf(suspectId: string): string
		return (string.match(nameOf(suspectId), "^%S+")) :: string
	end

	local function makePlayer(): any
		local id = t.nextUserId()
		local player = { UserId = id, Name = `C1-{id}` }
		PlayerDataService.initialize(player, "CASE-001")
		return player
	end

	local function sync(player: any)
		-- Studio's BindableEvent listeners land on the next scheduler turn;
		-- settle them before asking the synchronous reasoning evaluator to read
		-- the newly unlocked statement.
		task.wait()
		ReasoningService.evaluate(player)
		ObjectiveService.recordFact(player, "Contradiction", "sync")
	end

	-- What InteractionService does for an evidence interactable.
	local function inspect(player: any, evidenceId: string, kind: string?)
		EvidenceService.discover(player, evidenceId)
		ObjectiveService.recordInteraction(player, (kind or "Examine") :: any, evidenceId, evidenceId)
		sync(player)
	end

	local function choiceIds(player: any): { [string]: boolean }
		local ids = {}
		for _, choice in ipairs(ConversationService.getCurrentPayload(player).choices or {}) do
			ids[choice.id] = true
		end
		return ids
	end

	-- Continue through plain lines until the conversation offers choices or
	-- ends. Returns whether it is still active.
	local function untilChoice(player: any): boolean
		for _ = 1, 30 do
			local payload = ConversationService.getCurrentPayload(player)
			if not payload.active then
				return false
			end
			if payload.choices then
				return true
			end
			ConversationService.advance(player)
			sync(player)
		end
		error("conversation never reached a choice")
	end

	-- Start a conversation (as a Talk interaction), ask each question in
	-- turn, then take the exit choice if one is still on offer.
	local function talk(player: any, suspectId: string, questions: { string }, exitChoice: string?)
		expect.truthy(ConversationService.begin(player, suspectId))
		ObjectiveService.recordInteraction(player, "Talk", nil, suspectId)
		sync(player)
		for _, question in ipairs(questions) do
			expect.truthy(untilChoice(player))
			-- "show:EV-001" shows a piece of evidence (M9).
			local evidenceId = string.match(question, "^show:(.+)$")
			local ok, reason
			if evidenceId then
				ok, reason = ConversationService.choose(player, "show")
				if ok then
					ok, reason = ConversationService.present(player, evidenceId)
				end
			else
				ok, reason = ConversationService.choose(player, question)
			end
			if not ok then
				error(`could not ask '{question}' of {suspectId}: {reason}`)
			end
			sync(player)
		end
		if untilChoice(player) and exitChoice then
			expect.truthy(ConversationService.choose(player, exitChoice))
			untilChoice(player)
		end
		if ConversationService.isTalking(player) then
			ConversationService.leave(player)
		end
	end

	local function knowsStatement(player: any, id: string): boolean
		return ConversationService.isStatementUnlocked(player, id)
	end

	local function unlocked(player: any, kind: "Contradictions" | "Deductions", id: string): boolean
		local data = PlayerDataService.get(player) :: any
		return data.caseState["unlocked" .. kind][id] == true
	end

	local function active(player: any): string?
		return ObjectiveService.getActiveObjectiveId(player)
	end

	local function answer(player: any, deductionId: string, optionId: string): string
		local result = ReasoningService.answerDeduction(player, deductionId, optionId)
		sync(player)
		return result
	end

	local function claim(player: any, a: any, b: any): string
		local result = ReasoningService.claimContradiction(player, a, b)
		sync(player)
		return result
	end

	local function openQuestion(player: any, deductionId: string): any
		for _, question in ipairs(ReasoningService.getPayload(player).openQuestions) do
			if question.id == deductionId then
				return question
			end
		end
		return nil
	end

	local function mistakes(player: any): number
		return (PlayerDataService.get(player) :: any).caseState.reasoningMistakes
	end

	local function nodeId(player: any): string?
		return ConversationService.getCurrentPayload(player).nodeId
	end

	local function searchOffice(player: any)
		inspect(player, "EV-001")
		inspect(player, "EV-002")
		inspect(player, "EV-003", "Read")
		inspect(player, "EV-006")
	end

	------------------------------------------------------------------
	-- Structure
	------------------------------------------------------------------

	t.test("the conversation graph validates clean", function()
		local problems = ConversationService.validate(caseDef)
		if #problems > 0 then
			error(table.concat(problems, "\n"))
		end
	end)

	t.test("every authored statement is reachable in some conversation", function()
		local said: { [string]: boolean } = {}
		for _, conversation in ipairs(caseDef.conversations) do
			for _, node in pairs(conversation.nodes) do
				if node.statementId then
					said[node.statementId] = true
				end
			end
		end
		for _, statement in ipairs(caseDef.statements) do
			if not said[statement.id] then
				error(`statement {statement.id} is never said`)
			end
		end
	end)

	-- The writing rule: short beats, never paragraphs.
	t.test("every dialogue line is a short beat", function()
		for _, conversation in ipairs(caseDef.conversations) do
			for id, node in pairs(conversation.nodes) do
				if #node.text > 130 then
					error(`{id} is {#node.text} characters: split it into beats`)
				end
				for _, choice in ipairs(node.choices or {}) do
					expect.truthy(#choice.text <= 80)
				end
			end
		end
	end)

	t.test("M9: every contradiction is the investigator's to claim, every deduction a question", function()
		for _, contradiction in ipairs(caseDef.contradictions) do
			expect.truthy(contradiction.claim)
		end
		for _, deduction in ipairs(caseDef.deductions) do
			local question = deduction.question
			expect.truthy(question)
			local found = false
			for _, option in ipairs(question.options) do
				found = found or option.id == question.answer
			end
			if not found then
				error(`{deduction.id}: the answer is not one of the options`)
			end
		end
	end)

	t.test("M9: every contradiction can be shown to the person who said it", function()
		local claimed: { [string]: boolean } = {}
		for _, conversation in ipairs(caseDef.conversations) do
			for _, node in pairs(conversation.nodes) do
				for _, choice in ipairs(node.choices or {}) do
					for _, outcome in ipairs(choice.present and choice.present.outcomes or {}) do
						if outcome.claims then
							claimed[outcome.claims] = true
						end
					end
				end
			end
		end
		for _, contradiction in ipairs(caseDef.contradictions) do
			-- Phase 5.3: two statements set side by side have no evidence to
			-- show anyone (CONTRA-005, "Nobody Told Him"); they are claimed in
			-- the case file, by design.
			local bothStatements = contradiction.left.kind == "Statement" and contradiction.right.kind == "Statement"
			if not claimed[contradiction.id] and not bothStatements then
				error(`{contradiction.id} can only be claimed in the case file`)
			end
			if bothStatements then
				expect.equal(contradiction.id, "CONTRA-005")
			end
		end
	end)

	t.test("the night guard is not accusable", function()
		for _, accusation in ipairs(caseDef.accusations) do
			expect.falsy(accusation.suspectId == "SUS-003")
		end
	end)

	------------------------------------------------------------------
	-- The investigation, end to end (M9: the investigator makes every
	-- connection)
	------------------------------------------------------------------

	t.test("the whole case can be solved: guard, scene, suspects, lies, confrontation, timeline, verdict", function()
		local player = makePlayer()
		expect.equal(active(player), "OBJ-000")

		-- Sam points at the badge log and the cameras.
		talk(player, "SUS-003", { "found", "anyone", "badges", "cameras" }, "bye")
		expect.equal(active(player), "OBJ-001")
		expect.truthy(knowsStatement(player, "STMT-SUS-003-CAMERAS"))
		-- Phase 2P: the badge log's pointer is a lead the case file can be
		-- revisited for, not just a line said once and never recorded.
		expect.truthy(knowsStatement(player, "STMT-SUS-003-BADGE"))

		searchOffice(player)
		expect.equal(active(player), "OBJ-002")
		inspect(player, "EV-005")
		-- Nothing is concluded for the investigator: two questions are open.
		expect.falsy(unlocked(player, "Deductions", "DEDUCT-002"))
		expect.falsy(unlocked(player, "Deductions", "DEDUCT-003"))
		expect.truthy(openQuestion(player, "DEDUCT-002"))
		expect.truthy(openQuestion(player, "DEDUCT-003"))
		expect.equal(answer(player, "DEDUCT-002", "dissolve"), "correct")
		expect.equal(answer(player, "DEDUCT-003", "visitor"), "correct")
		expect.falsy(openQuestion(player, "DEDUCT-002"))

		-- Victor: the alibi, the footage line, and his own note shown back
		-- to him.
		inspect(player, "EV-007")
		talk(player, "SUS-002", { "left", "confirm", "dissolve", "show:EV-007" }, "bye")
		expect.truthy(unlocked(player, "Contradictions", "CONTRA-004"))
		-- Meera: her account.
		talk(player, "SUS-001", { "sorry", "where", "dissolve" }, "bye")
		expect.equal(active(player), "OBJ-003")
		-- The phone is found, her account is known: still nothing concluded.
		expect.falsy(unlocked(player, "Contradictions", "CONTRA-003"))

		-- The badge log, set against Victor's "half ten" in the case file.
		inspect(player, "EV-004")
		expect.falsy(unlocked(player, "Contradictions", "CONTRA-001"))
		expect.equal(
			claim(player, { kind = "Evidence", id = "EV-004" }, { kind = "Statement", id = "STMT-SUS-002-ALIBI" }),
			"claimed"
		)
		expect.equal(active(player), "OBJ-004")

		-- Meera, shown the phone and asked gently: the truth, and the lead.
		talk(player, "SUS-001", { "show:EV-001", "gentle" }, "bye")
		expect.truthy(unlocked(player, "Contradictions", "CONTRA-003"))
		expect.truthy(knowsStatement(player, "STMT-SUS-001-VICTOR"))
		expect.equal(answer(player, "DEDUCT-001", "victor"), "correct")
		expect.equal(active(player), "OBJ-005")

		-- Victor, shown the badge log, revises his story; shown the phone,
		-- he breaks.
		talk(player, "SUS-002", { "show:EV-004" }, nil)
		expect.truthy(knowsStatement(player, "STMT-SUS-002-REVISED"))
		talk(player, "SUS-002", { "show:EV-001" }, nil)
		expect.truthy(unlocked(player, "Contradictions", "CONTRA-002"))
		expect.truthy(knowsStatement(player, "STMT-SUS-002-BREAK"))
		expect.equal(answer(player, "DEDUCT-004", "after"), "correct")
		expect.equal(active(player), "OBJ-006")

		-- Put the night in order.
		expect.truthy(TimelineService.submitSequence(player, {
			"TIMELINE-005",
			"TIMELINE-001",
			"TIMELINE-002",
			"TIMELINE-004",
			"TIMELINE-003",
		}))
		sync(player)
		expect.equal(active(player), nil)

		expect.truthy(AccusationService.accuse(player, "ACC-001", "DEDUCT-002", "CONTRA-002"))
		local resolution = AccusationService.getResolution(player) :: any
		expect.truthy(resolution.supported)
		local verdict = AccusationService.getVerdict(player) :: any
		expect.truthy(verdict.correct)
		expect.equal(verdict.grade, "Solved")
		expect.equal(verdict.culpritName, nameOf("SUS-002"))
		expect.truthy(verdict.epilogue)
		-- P7: Victor was pushed until he broke, so the ending says so.
		expect.truthy(string.find(verdict.epilogue, "word for word", 1, true))
		expect.equal(mistakes(player), 0)
	end)

	------------------------------------------------------------------
	-- The case file: claims and questions
	------------------------------------------------------------------

	t.test("a claim holds in either order, and only for facts the investigator has", function()
		local player = makePlayer()
		talk(player, "SUS-002", { "left" }, "bye")
		local alibi = { kind = "Statement", id = "STMT-SUS-002-ALIBI" }
		local log = { kind = "Evidence", id = "EV-004" }
		-- The log hasn't been found: not something they can pair.
		expect.equal(claim(player, alibi, log), "invalid")
		expect.equal(mistakes(player), 0)
		inspect(player, "EV-004")
		expect.equal(claim(player, log, alibi), "claimed")
		expect.equal(claim(player, alibi, log), "already")
		expect.truthy(unlocked(player, "Contradictions", "CONTRA-001"))
	end)

	t.test("a pairing that doesn't conflict says only that, counts, and locks out the next try", function()
		local player = makePlayer()
		talk(player, "SUS-002", { "left" }, "bye")
		inspect(player, "EV-002")
		inspect(player, "EV-004")
		local result = claim(
			player,
			{ kind = "Statement", id = "STMT-SUS-002-ALIBI" },
			{ kind = "Evidence", id = "EV-002" }
		)
		expect.equal(result, "no-conflict")
		expect.equal(mistakes(player), 1)
		-- Straight after a miss, even the right pairing has to wait.
		result = claim(player, { kind = "Statement", id = "STMT-SUS-002-ALIBI" }, { kind = "Evidence", id = "EV-004" })
		expect.equal(result, "cooldown")
		expect.falsy(unlocked(player, "Contradictions", "CONTRA-001"))
	end)

	t.test("malformed claims are rejected without counting", function()
		local player = makePlayer()
		inspect(player, "EV-001")
		expect.equal(claim(player, "EV-001", nil), "invalid")
		expect.equal(
			claim(player, { kind = "Evidence", id = "EV-001" }, { kind = "Evidence", id = "EV-001" }),
			"invalid"
		)
		expect.equal(
			claim(player, { kind = "Timeline", id = "EV-001" }, { kind = "Evidence", id = "EV-001" }),
			"invalid"
		)
		expect.equal(mistakes(player), 0)
	end)

	t.test("a question opens once its facts are known, never carries its answer, and a wrong answer counts", function()
		local player = makePlayer()
		inspect(player, "EV-005")
		expect.falsy(openQuestion(player, "DEDUCT-003"))
		expect.equal(answer(player, "DEDUCT-003", "visitor"), "invalid")
		inspect(player, "EV-006")
		local question = openQuestion(player, "DEDUCT-003")
		expect.truthy(question)
		expect.equal(question.answer, nil)
		expect.equal(#question.basedOn, 2)
		expect.equal(answer(player, "DEDUCT-003", "awake"), "wrong")
		expect.equal(mistakes(player), 1)
		expect.falsy(unlocked(player, "Deductions", "DEDUCT-003"))
		expect.truthy(openQuestion(player, "DEDUCT-003"))
	end)

	------------------------------------------------------------------
	-- Showing evidence
	------------------------------------------------------------------

	t.test("evidence that means nothing to someone gets a shrug, not a mistake", function()
		local player = makePlayer()
		inspect(player, "EV-002")
		talk(player, "SUS-002", { "show:EV-002" }, nil)
		expect.equal(mistakes(player), 0)
		ConversationService.begin(player, "SUS-002")
		untilChoice(player)
		ConversationService.choose(player, "show")
		ConversationService.present(player, "EV-002")
		expect.equal(nodeId(player), "VIC-SHOW-NOTHING")
		expect.equal(ConversationService.getCurrentPayload(player).presented, nil) -- a re-read drops the echo
	end)

	t.test("only found evidence can be shown, and backing out returns to the questions", function()
		local player = makePlayer()
		ConversationService.begin(player, "SUS-002")
		untilChoice(player)
		-- Nothing found yet: nothing to show.
		expect.falsy(choiceIds(player).show)
		ConversationService.leave(player)
		inspect(player, "EV-002")
		ConversationService.begin(player, "SUS-002")
		untilChoice(player)
		expect.truthy(ConversationService.choose(player, "show"))
		local waiting = ConversationService.getCurrentPayload(player)
		expect.truthy(waiting.present)
		expect.equal(#waiting.present.options, 1)
		expect.falsy(ConversationService.advance(player))
		expect.falsy(ConversationService.present(player, "EV-004")) -- not found
		expect.truthy(ConversationService.present(player, nil))
		expect.truthy(ConversationService.getCurrentPayload(player).choices)
	end)

	t.test("the badge log only corners Victor once he has told you when he left", function()
		local player = makePlayer()
		inspect(player, "EV-004")
		talk(player, "SUS-002", { "show:EV-004" }, nil)
		expect.falsy(knowsStatement(player, "STMT-SUS-002-REVISED"))
		expect.falsy(unlocked(player, "Contradictions", "CONTRA-001"))
		talk(player, "SUS-002", { "left", "show:EV-004" }, nil)
		expect.truthy(knowsStatement(player, "STMT-SUS-002-REVISED"))
		expect.truthy(unlocked(player, "Contradictions", "CONTRA-001"))
		-- Shown again, it's old news.
		ConversationService.begin(player, "SUS-002")
		untilChoice(player)
		ConversationService.choose(player, "show")
		ConversationService.present(player, "EV-004")
		expect.equal(nodeId(player), "VIC-SHOW-AGAIN")
	end)

	t.test("the phone only breaks Victor once he has a story for it to break", function()
		local player = makePlayer()
		inspect(player, "EV-001")
		talk(player, "SUS-002", { "show:EV-001" }, nil)
		expect.falsy(knowsStatement(player, "STMT-SUS-002-BREAK"))
		expect.falsy(unlocked(player, "Contradictions", "CONTRA-002"))
	end)

	t.test("asking Victor about the partnership changes once the draft is found", function()
		local player = makePlayer()
		ConversationService.begin(player, "SUS-002")
		untilChoice(player)
		expect.truthy(choiceIds(player).partner)
		expect.falsy(choiceIds(player).dissolve)
		ConversationService.leave(player)
		EvidenceService.discover(player, "EV-002")
		ConversationService.begin(player, "SUS-002")
		untilChoice(player)
		expect.falsy(choiceIds(player).partner)
		expect.truthy(choiceIds(player).dissolve)
	end)

	t.test("Sam's coffee question needs the second cup", function()
		local player = makePlayer()
		ConversationService.begin(player, "SUS-003")
		untilChoice(player)
		expect.falsy(choiceIds(player).coffee)
		ConversationService.leave(player)
		EvidenceService.discover(player, "EV-006")
		ConversationService.begin(player, "SUS-003")
		untilChoice(player)
		expect.truthy(choiceIds(player).coffee)
	end)

	t.test("Sam's badge-log question is hidden once its statement is recorded, not merely used once", function()
		local player = makePlayer()
		ConversationService.begin(player, "SUS-003")
		untilChoice(player)
		expect.truthy(choiceIds(player).badges)
		expect.truthy(ConversationService.choose(player, "badges"))
		untilChoice(player) -- SAM-BADGE-1 -> SAM-BADGE-2 (statementId here) -> SAM-BADGE-3 -> hub
		expect.truthy(knowsStatement(player, "STMT-SUS-003-BADGE"))
		expect.falsy(choiceIds(player).badges)
		ConversationService.leave(player)
		ConversationService.begin(player, "SUS-003")
		untilChoice(player)
		-- Hidden because the statement is known, exactly like every other
		-- fact-yielding question in this file -- not a one-shot `once` flag,
		-- which would hide it here even for a player who never asked.
		expect.falsy(choiceIds(player).badges)
	end)

	t.test("Sam greets you differently the second time", function()
		local player = makePlayer()
		ConversationService.begin(player, "SUS-003")
		expect.equal(ConversationService.getCurrentPayload(player).nodeId, "SAM-OPEN")
		ConversationService.leave(player)
		ConversationService.begin(player, "SUS-003")
		expect.equal(ConversationService.getCurrentPayload(player).nodeId, "SAM-AGAIN")
	end)

	------------------------------------------------------------------
	-- Consequences with Meera
	------------------------------------------------------------------

	local function readyForTheCall(player: any)
		inspect(player, "EV-001")
		talk(player, "SUS-001", { "where" }, "bye")
		expect.falsy(unlocked(player, "Contradictions", "CONTRA-003"))
	end

	t.test("accusing Meera of lying makes her shut the conversation down", function()
		local player = makePlayer()
		readyForTheCall(player)
		talk(player, "SUS-001", { "show:EV-001", "harsh" }, nil)
		expect.truthy(unlocked(player, "Contradictions", "CONTRA-003"))
		expect.falsy(ConversationService.isTalking(player))
		expect.falsy(knowsStatement(player, "STMT-SUS-001-ADMISSION"))
		-- She stays cold until the investigator apologises.
		ConversationService.begin(player, "SUS-001")
		expect.equal(ConversationService.getCurrentPayload(player).nodeId, "MARA-COLD")
		ConversationService.choose(player, "insist")
		untilChoice(player)
		expect.falsy(ConversationService.isTalking(player))
		ConversationService.begin(player, "SUS-001")
		expect.equal(ConversationService.getCurrentPayload(player).nodeId, "MARA-COLD")
		ConversationService.choose(player, "apologise")
		untilChoice(player)
		expect.truthy(knowsStatement(player, "STMT-SUS-001-ADMISSION"))
		expect.truthy(knowsStatement(player, "STMT-SUS-001-VICTOR"))
	end)

	t.test("asking gently gets the truth and the lead at once", function()
		local player = makePlayer()
		readyForTheCall(player)
		talk(player, "SUS-001", { "show:EV-001", "gentle" }, "bye")
		expect.truthy(knowsStatement(player, "STMT-SUS-001-ADMISSION"))
		expect.truthy(knowsStatement(player, "STMT-SUS-001-VICTOR"))
		-- Afterwards she greets you with what's on her mind, and the phone
		-- is old news.
		ConversationService.begin(player, "SUS-001")
		expect.equal(ConversationService.getCurrentPayload(player).nodeId, "MARA-AFTER")
		untilChoice(player)
		ConversationService.choose(player, "show")
		ConversationService.present(player, "EV-001")
		expect.equal(nodeId(player), "MARA-PHONE-KNOWN")
	end)

	t.test("walking away mid-admission never loses the lead", function()
		local player = makePlayer()
		readyForTheCall(player)
		ConversationService.begin(player, "SUS-001")
		untilChoice(player)
		ConversationService.choose(player, "show")
		ConversationService.present(player, "EV-001")
		untilChoice(player)
		ConversationService.choose(player, "gentle")
		ConversationService.advance(player) -- ADMIT-2
		ConversationService.leave(player)
		expect.falsy(knowsStatement(player, "STMT-SUS-001-VICTOR"))
		-- The phone still lands with her.
		ConversationService.begin(player, "SUS-001")
		untilChoice(player)
		ConversationService.choose(player, "show")
		ConversationService.present(player, "EV-001")
		expect.equal(nodeId(player), "MARA-CALL-0")
	end)

	------------------------------------------------------------------
	-- The accusation (M9)
	------------------------------------------------------------------

	local function establish(player: any, deductions: { string }, contradictions: { string })
		local data = PlayerDataService.get(player) :: any
		data.caseState.completedObjectives["OBJ-000"] = true
		data.caseState.completedObjectives["OBJ-001"] = true
		data.caseState.completedObjectives["OBJ-002"] = true
		for _, id in ipairs(deductions) do
			data.caseState.unlockedDeductions[id] = true
		end
		for _, id in ipairs(contradictions) do
			data.caseState.unlockedContradictions[id] = true
		end
	end

	t.test("accusing opens once both suspects have been spoken to, with the rest still open", function()
		local player = makePlayer()
		expect.falsy(AccusationService.isOpen(player))
		expect.falsy(AccusationService.accuse(player, "ACC-001", "DEDUCT-002", "CONTRA-001"))
		establish(player, { "DEDUCT-002" }, { "CONTRA-001" })
		expect.truthy(ObjectiveService.getActiveObjectiveId(player))
		expect.truthy(AccusationService.isOpen(player))
		local payload = AccusationService.getPayload(player)
		expect.truthy(payload.open)
		expect.truthy(payload.requiresCase)
		expect.equal(#payload.motives, 1)
		expect.equal(#payload.proofs, 1)
	end)

	t.test("an accusation needs a motive and a proof the investigator has established", function()
		local player = makePlayer()
		establish(player, { "DEDUCT-002" }, { "CONTRA-001" })
		expect.falsy(AccusationService.accuse(player, "ACC-001", nil, nil))
		expect.falsy(AccusationService.accuse(player, "ACC-001", "DEDUCT-001", "CONTRA-001")) -- not established
		expect.falsy(AccusationService.accuse(player, "ACC-001", "DEDUCT-002", "CONTRA-002")) -- not established
		expect.truthy(AccusationService.accuse(player, "ACC-001", "DEDUCT-002", "CONTRA-001"))
		local verdict = AccusationService.getVerdict(player) :: any
		expect.equal(verdict.grade, "Solved")
		-- Phase 2P: a case that holds has nothing left to account for.
		expect.equal(verdict.shortfall, nil)
		-- P7: solved early, Victor never broke -- the plain ending.
		expect.equal(verdict.epilogue, caseDef.solution.solvedEpilogue)
	end)

	t.test("P7: breaking Victor changes the ending, never the grade", function()
		local player = makePlayer()
		establish(player, { "DEDUCT-003" }, { "CONTRA-004" })
		local data = PlayerDataService.get(player) :: any
		data.caseState.unlockedStatements["STMT-SUS-002-BREAK"] = true
		expect.truthy(AccusationService.accuse(player, "ACC-001", "DEDUCT-003", "CONTRA-004"))
		local verdict = AccusationService.getVerdict(player) :: any
		-- The case named still doesn't hold: Unproven, with its own ending.
		expect.equal(verdict.grade, "Unproven")
		expect.equal(verdict.epilogue, caseDef.solution.unprovenEpilogue)
	end)

	t.test("the right man with a case that doesn't hold walks", function()
		local player = makePlayer()
		establish(player, { "DEDUCT-003" }, { "CONTRA-004" })
		expect.truthy(AccusationService.accuse(player, "ACC-001", "DEDUCT-003", "CONTRA-004"))
		local verdict = AccusationService.getVerdict(player) :: any
		expect.truthy(verdict.correct)
		expect.equal(verdict.grade, "Unproven")
		expect.truthy(string.find(verdict.epilogue, "walks", 1, true))
		expect.falsy((AccusationService.getResolution(player) :: any).supported)
		-- Phase 2P: the named motive/proof aren't authorized for this
		-- accusation, so the shortfall says so -- never the true pairing.
		expect.truthy(verdict.shortfall)
		expect.truthy(string.find(verdict.shortfall, nameOf("SUS-002"), 1, true))
		expect.falsy(string.find(verdict.shortfall, "Ending the Partnership", 1, true))
	end)

	t.test("accusing Meera is a wrong verdict that still tells the truth", function()
		local player = makePlayer()
		establish(player, { "DEDUCT-003" }, { "CONTRA-003" })
		expect.truthy(AccusationService.accuse(player, "ACC-002", "DEDUCT-003", "CONTRA-003"))
		local verdict = AccusationService.getVerdict(player) :: any
		expect.falsy(verdict.correct)
		expect.equal(verdict.grade, "Wrong")
		expect.equal(verdict.culpritName, nameOf("SUS-002"))
		expect.truthy(string.find(verdict.epilogue, firstNameOf("SUS-001"), 1, true))
		-- Phase 2P: ACC-002 authors no motives/proofs at all, so neither
		-- holds up against the person actually accused.
		expect.truthy(verdict.shortfall)
		expect.truthy(string.find(verdict.shortfall, nameOf("SUS-001"), 1, true))
	end)

	------------------------------------------------------------------
	-- The closing summary (Phase 2P)
	------------------------------------------------------------------

	t.test("the closing summary's timeline is chronological even accused before it's reconstructed", function()
		local player = makePlayer()
		establish(player, { "DEDUCT-002" }, { "CONTRA-001" })
		-- Discovered out of chronological order (11:52, then 11:42, then
		-- 11:47), so a sort that never ran couldn't be mistaken for one that
		-- did.
		EvidenceService.discover(player, "EV-004") -- TIMELINE-004, 11:52 PM
		EvidenceService.discover(player, "EV-002") -- TIMELINE-001, 11:42 PM
		EvidenceService.discover(player, "EV-001") -- TIMELINE-002, 11:47 PM
		expect.truthy(AccusationService.accuse(player, "ACC-001", "DEDUCT-002", "CONTRA-001"))
		-- The point of this test: genuinely the early-accusation case, with
		-- OBJ-006 (reconstruct the night) nowhere near done.
		expect.falsy(TimelineService.isEstablished(player))

		local summary = GameStateService.getClosingSummary(player)
		expect.truthy(summary)
		expect.equal(#summary.timeline, 3)
		expect.equal(summary.timeline[1].timestamp, "11:42 PM")
		expect.equal(summary.timeline[2].timestamp, "11:47 PM")
		expect.equal(summary.timeline[3].timestamp, "11:52 PM")
	end)
end
