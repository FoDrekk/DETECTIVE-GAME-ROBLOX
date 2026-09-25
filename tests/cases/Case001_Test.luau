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
	local CaseRegistry = require(game:GetService("ServerStorage"):WaitForChild("Config"):WaitForChild("CaseRegistry"))
	local expect = t.expect

	local caseDef = CaseRegistry.get("CASE-001") :: any

	local function makePlayer(): any
		local id = t.nextUserId()
		local player = { UserId = id, Name = `C1-{id}` }
		PlayerDataService.initialize(player, "CASE-001")
		return player
	end

	local function sync(player: any)
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
			local ok, reason = ConversationService.choose(player, question)
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

	t.test("the night guard is not accusable", function()
		for _, accusation in ipairs(caseDef.accusations) do
			expect.falsy(accusation.suspectId == "SUS-003")
		end
	end)

	------------------------------------------------------------------
	-- The investigation, end to end
	------------------------------------------------------------------

	t.test("the whole case can be solved: guard, scene, suspects, lies, confrontation, timeline, verdict", function()
		local player = makePlayer()
		expect.equal(active(player), "OBJ-000")

		-- Sam points at the badge log and the cameras.
		talk(player, "SUS-003", { "found", "anyone", "badges", "cameras" }, "bye")
		expect.equal(active(player), "OBJ-001")
		expect.truthy(knowsStatement(player, "STMT-SUS-003-CAMERAS"))

		searchOffice(player)
		expect.equal(active(player), "OBJ-002")

		-- The pantry machine: somebody else was drinking coffee.
		inspect(player, "EV-005")
		expect.truthy(unlocked(player, "Deductions", "DEDUCT-003"))
		expect.truthy(unlocked(player, "Deductions", "DEDUCT-002"))

		-- Victor: the alibi and the footage line.
		talk(player, "SUS-002", { "left", "confirm", "dissolve" }, "bye")
		-- Mara: her account (the call question needs the alibi first).
		talk(player, "SUS-001", { "sorry", "where", "dissolve" }, "bye")
		expect.equal(active(player), "OBJ-003")
		-- Her account already breaks against the phone -- the red herring.
		expect.truthy(unlocked(player, "Contradictions", "CONTRA-003"))

		-- The badge log breaks Victor's alibi.
		inspect(player, "EV-004")
		expect.truthy(unlocked(player, "Contradictions", "CONTRA-001"))
		expect.equal(active(player), "OBJ-004")

		-- The monitor note breaks his "pull the footage".
		inspect(player, "EV-007")
		expect.truthy(unlocked(player, "Contradictions", "CONTRA-004"))

		-- Mara, gently: the truth about the call, and the lead.
		talk(player, "SUS-001", { "call", "gentle" }, "bye")
		expect.truthy(knowsStatement(player, "STMT-SUS-001-ADMISSION"))
		expect.truthy(unlocked(player, "Deductions", "DEDUCT-001"))
		expect.equal(active(player), "OBJ-005")

		-- Victor, cornered by the badge log, revises his story...
		talk(player, "SUS-002", { "badge" }, nil)
		expect.truthy(knowsStatement(player, "STMT-SUS-002-REVISED"))
		-- ...which breaks against the phone.
		expect.truthy(unlocked(player, "Contradictions", "CONTRA-002"))
		-- The confrontation.
		talk(player, "SUS-002", { "confront" }, nil)
		expect.truthy(knowsStatement(player, "STMT-SUS-002-BREAK"))
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

		expect.truthy(AccusationService.accuse(player, "ACC-001"))
		local resolution = AccusationService.getResolution(player) :: any
		expect.truthy(resolution.supported)
		local verdict = AccusationService.getVerdict(player) :: any
		expect.truthy(verdict.correct)
		expect.equal(verdict.culpritName, "Victor Lane")
	end)

	------------------------------------------------------------------
	-- Choices depend on what the investigator knows
	------------------------------------------------------------------

	t.test("Victor can't be confronted with the badge log before it is found", function()
		local player = makePlayer()
		ConversationService.begin(player, "SUS-002")
		untilChoice(player)
		expect.falsy(choiceIds(player).badge)
		ConversationService.choose(player, "left")
		untilChoice(player)
		expect.falsy(choiceIds(player).badge) -- alibi known, log not found
		ConversationService.leave(player)
		EvidenceService.discover(player, "EV-004")
		ConversationService.begin(player, "SUS-002")
		untilChoice(player)
		expect.truthy(choiceIds(player).badge)
		expect.falsy(choiceIds(player).confront)
	end)

	t.test("the confrontation is only on offer once his revised story has broken", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-004")
		talk(player, "SUS-002", { "left", "badge" }, nil)
		sync(player)
		expect.falsy(unlocked(player, "Contradictions", "CONTRA-002")) -- phone not found yet
		ConversationService.begin(player, "SUS-002")
		untilChoice(player)
		expect.falsy(choiceIds(player).confront)
		ConversationService.leave(player)
		inspect(player, "EV-001")
		ConversationService.begin(player, "SUS-002")
		untilChoice(player)
		expect.truthy(choiceIds(player).confront)
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

	t.test("Sam greets you differently the second time", function()
		local player = makePlayer()
		ConversationService.begin(player, "SUS-003")
		expect.equal(ConversationService.getCurrentPayload(player).nodeId, "SAM-OPEN")
		ConversationService.leave(player)
		ConversationService.begin(player, "SUS-003")
		expect.equal(ConversationService.getCurrentPayload(player).nodeId, "SAM-AGAIN")
	end)

	------------------------------------------------------------------
	-- Consequences with Mara
	------------------------------------------------------------------

	local function readyForTheCall(player: any)
		inspect(player, "EV-001")
		talk(player, "SUS-001", { "where" }, "bye")
		expect.truthy(unlocked(player, "Contradictions", "CONTRA-003"))
	end

	t.test("accusing Mara of lying makes her shut the conversation down", function()
		local player = makePlayer()
		readyForTheCall(player)
		talk(player, "SUS-001", { "call", "harsh" }, nil)
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
		talk(player, "SUS-001", { "call", "gentle" }, "bye")
		expect.truthy(knowsStatement(player, "STMT-SUS-001-ADMISSION"))
		expect.truthy(knowsStatement(player, "STMT-SUS-001-VICTOR"))
		-- Afterwards she greets you with what's on her mind.
		ConversationService.begin(player, "SUS-001")
		expect.equal(ConversationService.getCurrentPayload(player).nodeId, "MARA-AFTER")
		untilChoice(player)
		expect.falsy(choiceIds(player).call)
	end)

	t.test("walking away mid-admission never loses the lead", function()
		local player = makePlayer()
		readyForTheCall(player)
		ConversationService.begin(player, "SUS-001")
		untilChoice(player)
		ConversationService.choose(player, "call")
		untilChoice(player)
		ConversationService.choose(player, "gentle")
		ConversationService.advance(player) -- ADMIT-2
		ConversationService.leave(player)
		expect.falsy(knowsStatement(player, "STMT-SUS-001-VICTOR"))
		ConversationService.begin(player, "SUS-001")
		untilChoice(player)
		expect.truthy(choiceIds(player).call)
	end)

	t.test("accusing Mara is a wrong verdict that still tells the truth", function()
		local player = makePlayer()
		local data = PlayerDataService.get(player) :: any
		for _, objective in ipairs(caseDef.objectives) do
			data.caseState.completedObjectives[objective.id] = true
		end
		expect.truthy(AccusationService.accuse(player, "ACC-002"))
		local verdict = AccusationService.getVerdict(player) :: any
		expect.falsy(verdict.correct)
		expect.equal(verdict.culpritName, "Victor Lane")
	end)
end
