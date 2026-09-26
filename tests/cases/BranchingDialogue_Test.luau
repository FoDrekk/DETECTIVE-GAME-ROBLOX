--!strict
--[[
	Tests for ConversationService's branching contract: conditional choices,
	`once` questions, flags, entries, `choicesFrom`, statement text, the
	"choice required" guard, and the graph validator. Uses a synthetic
	fixture case so the mechanics are proven independently of CASE-001's
	story content.
]]
return function(t)
	local ServerScriptService = game:GetService("ServerScriptService")
	local Server = ServerScriptService:WaitForChild("Server")
	local ConversationService = require(Server:WaitForChild("ConversationService"))
	local PlayerDataService = require(Server:WaitForChild("PlayerDataService"))
	local EvidenceService = require(Server:WaitForChild("EvidenceService"))
	local ObjectiveService = require(Server:WaitForChild("ObjectiveService"))
	local CaseRegistry = require(game:GetService("ServerStorage"):WaitForChild("Config"):WaitForChild("CaseRegistry"))
	local expect = t.expect

	local CASE_ID = "CASE-TEST-BRANCH"

	CaseRegistry.register({
		id = CASE_ID,
		title = "Branching Fixture",
		description = "",
		suspects = {
			{ id = "WIT", name = "Witness", role = "Night Security", alibi = "Alibi text from the suspect." },
		},
		locations = {},
		evidence = {
			{ id = "EV-KEY", name = "Key", description = "", location = "Desk", importance = "Low" },
		},
		timeline = {},
		objectives = {
			{
				id = "OBJ-FIRST",
				title = "First",
				description = "",
				requiredEvidence = { "EV-KEY" },
				requiredInteractions = {},
				requirements = { { id = "R-KEY", label = "Find the key", evidence = "EV-KEY" } },
			},
			{
				id = "OBJ-TALK",
				title = "Talk",
				description = "",
				requiredEvidence = {},
				requiredInteractions = { "Talk" },
				requirements = { { id = "R-TALK", label = "Talk", interaction = "Talk", target = "WIT" } },
				prerequisites = { "OBJ-FIRST" },
			},
		},
		conversations = {
			{
				suspectId = "WIT",
				startNodeId = "HELLO",
				entries = {
					{ node = "COLD", requires = { { kind = "Flag", id = "offended" } } },
					{ node = "AGAIN", requires = { { kind = "Flag", id = "met" } } },
				},
				nodes = {
					HELLO = { id = "HELLO", speaker = "Witness", text = "Hello.", next = "HUB", setFlags = { "met" } },
					AGAIN = { id = "AGAIN", speaker = "Witness", text = "You again.", next = "HUB" },
					COLD = {
						id = "COLD",
						speaker = "Witness",
						text = "I'm not talking to you.",
						clearFlags = { "offended" },
					},
					HUB = {
						id = "HUB",
						speaker = "Witness",
						text = "What do you want?",
						choices = {
							{ id = "where", text = "Where were you?", next = "WHERE", once = true },
							{
								id = "key",
								text = "Whose key is this?",
								next = "KEY",
								requires = { { kind = "Evidence", id = "EV-KEY" } },
							},
							{
								id = "unknown",
								text = "Anything you haven't told me?",
								next = "WHERE",
								requires = { { kind = "Statement", id = "STMT-WHERE", negate = true } },
							},
							{ id = "liar", text = "You're lying.", next = "OFFENDED" },
							{ id = "bye", text = "That's all.", next = "BYE" },
						},
					},
					WHERE = {
						id = "WHERE",
						speaker = "Witness",
						text = "Rounds.",
						statementId = "STMT-WHERE",
						choicesFrom = "HUB",
					},
					KEY = { id = "KEY", speaker = "Witness", text = "Not mine.", choicesFrom = "HUB" },
					OFFENDED = { id = "OFFENDED", speaker = "Witness", text = "Get out.", setFlags = { "offended" } },
					BYE = { id = "BYE", speaker = "Witness", text = "Bye." },
				},
			},
		},
		statements = {
			{ id = "STMT-WHERE", suspectId = "WIT", label = "Rounds", text = "Says he was on his rounds." },
		},
		contradictions = {},
		deductions = {},
	} :: any)

	local function makePlayer(): any
		local id = t.nextUserId()
		local player = { UserId = id, Name = `BR{id}` }
		PlayerDataService.initialize(player, CASE_ID)
		return player
	end

	local function choiceIds(player: any): { [string]: boolean }
		local payload = ConversationService.getCurrentPayload(player)
		local ids = {}
		for _, choice in ipairs(payload.choices or {}) do
			ids[choice.id] = true
		end
		return ids
	end

	local function toHub(player: any)
		ConversationService.begin(player, "WIT")
		ConversationService.advance(player) -- HELLO/AGAIN -> HUB
	end

	t.test("the fixture graph validates clean", function()
		local problems = ConversationService.validate(CaseRegistry.get(CASE_ID) :: any)
		expect.equal(#problems, 0)
	end)

	t.test("a line with choices cannot be continued past", function()
		local player = makePlayer()
		toHub(player)
		local ok, reason = ConversationService.advance(player)
		expect.falsy(ok)
		expect.equal(reason, "choice-required")
		local payload = ConversationService.getCurrentPayload(player)
		expect.equal(payload.nodeId, "HUB")
		expect.falsy(payload.canContinue)
	end)

	t.test("an evidence-gated choice appears only once the evidence is known", function()
		local player = makePlayer()
		toHub(player)
		expect.falsy(choiceIds(player).key)
		ConversationService.leave(player)
		EvidenceService.discover(player, "EV-KEY")
		toHub(player)
		expect.truthy(choiceIds(player).key)
	end)

	t.test("choosing follows the choice and echoes what was asked", function()
		local player = makePlayer()
		toHub(player)
		local ok = ConversationService.choose(player, "where")
		expect.truthy(ok)
		local payload = ConversationService.getCurrentPayload(player)
		expect.equal(payload.nodeId, "WHERE")
		expect.truthy(ConversationService.isStatementUnlocked(player, "STMT-WHERE"))
	end)

	t.test("an unavailable or unknown choice id is rejected", function()
		local player = makePlayer()
		toHub(player)
		local ok, reason = ConversationService.choose(player, "key") -- evidence not found
		expect.falsy(ok)
		expect.equal(reason, "invalid-choice")
		ok, reason = ConversationService.choose(player, "nope")
		expect.falsy(ok)
		expect.equal(reason, "invalid-choice")
		expect.equal(ConversationService.getCurrentPayload(player).nodeId, "HUB")
	end)

	t.test("a once choice disappears after use; choicesFrom returns to the questions", function()
		local player = makePlayer()
		toHub(player)
		ConversationService.choose(player, "where")
		local ids = choiceIds(player) -- borrowed from HUB
		expect.falsy(ids.where)
		expect.truthy(ids.bye)
	end)

	t.test("a negated statement condition hides the choice once the statement is known", function()
		local player = makePlayer()
		toHub(player)
		expect.truthy(choiceIds(player).unknown)
		ConversationService.choose(player, "where")
		expect.falsy(choiceIds(player).unknown)
	end)

	t.test("statement text comes from the statement when authored", function()
		local player = makePlayer()
		toHub(player)
		ConversationService.choose(player, "where")
		local statement = ConversationService.getUnlockedStatement(player, "STMT-WHERE")
		expect.truthy(statement)
		expect.equal((statement :: any).text, "Says he was on his rounds.")
	end)

	t.test("flags change where the next conversation starts", function()
		local player = makePlayer()
		toHub(player)
		ConversationService.choose(player, "bye")
		ConversationService.advance(player) -- ends
		ConversationService.begin(player, "WIT")
		expect.equal(ConversationService.getCurrentPayload(player).nodeId, "AGAIN")
	end)

	t.test("pressing too hard is remembered, then cleared by the cold greeting", function()
		local player = makePlayer()
		toHub(player)
		ConversationService.choose(player, "liar")
		ConversationService.advance(player) -- OFFENDED ends
		expect.falsy(ConversationService.isTalking(player))
		ConversationService.begin(player, "WIT")
		expect.equal(ConversationService.getCurrentPayload(player).nodeId, "COLD")
		ConversationService.advance(player) -- COLD ends, flag cleared
		ConversationService.begin(player, "WIT")
		expect.equal(ConversationService.getCurrentPayload(player).nodeId, "AGAIN")
	end)

	t.test("choose with no active conversation is rejected", function()
		local player = makePlayer()
		local ok, reason = ConversationService.choose(player, "where")
		expect.falsy(ok)
		expect.equal(reason, "no-active-conversation")
	end)

	t.test("the payload carries the suspect's role and never the choice targets", function()
		local player = makePlayer()
		toHub(player)
		local payload = ConversationService.getCurrentPayload(player) :: any
		expect.equal(payload.suspectRole, "Night Security")
		for _, choice in ipairs(payload.choices) do
			expect.equal(choice.next, nil)
			expect.equal(choice.requires, nil)
		end
	end)

	t.test("a talk objective is credited for a conversation held before it activated", function()
		local player = makePlayer()
		toHub(player) -- met WIT while OBJ-FIRST is still active
		ConversationService.leave(player)
		expect.equal(ObjectiveService.getActiveObjectiveId(player), "OBJ-FIRST")
		EvidenceService.discover(player, "EV-KEY")
		ObjectiveService.recordInteraction(player, "Examine", "EV-KEY", "Key")
		-- OBJ-TALK activates and is immediately satisfied by the earlier talk.
		expect.equal(ObjectiveService.getActiveObjectiveId(player), nil)
	end)

	t.test("evidence found before its objective is active still counts", function()
		CaseRegistry.register({
			id = "CASE-TEST-LATE-EVIDENCE",
			title = "",
			description = "",
			suspects = {},
			locations = {},
			evidence = {
				{ id = "EV-A", name = "A", description = "", location = "", importance = "Low" },
				{ id = "EV-B", name = "B", description = "", location = "", importance = "Low" },
			},
			timeline = {},
			objectives = {
				{
					id = "O1",
					title = "",
					description = "",
					requiredEvidence = { "EV-A" },
					requiredInteractions = {},
					requirements = { { id = "RA", label = "A", evidence = "EV-A" } },
				},
				{
					id = "O2",
					title = "",
					description = "",
					requiredEvidence = { "EV-B" },
					requiredInteractions = {},
					requirements = { { id = "RB", label = "B", interaction = "Read", evidence = "EV-B" } },
					prerequisites = { "O1" },
				},
			},
			conversations = {},
			statements = {},
			contradictions = {},
			deductions = {},
		} :: any)
		local id = t.nextUserId()
		local player = { UserId = id, Name = `LATE{id}` } :: any
		PlayerDataService.initialize(player, "CASE-TEST-LATE-EVIDENCE")
		EvidenceService.discover(player, "EV-B")
		ObjectiveService.recordInteraction(player, "Read", "EV-B", "B")
		expect.equal(ObjectiveService.getActiveObjectiveId(player), "O1")
		EvidenceService.discover(player, "EV-A")
		ObjectiveService.recordInteraction(player, "Examine", "EV-A", "A")
		expect.equal(ObjectiveService.getActiveObjectiveId(player), nil)
	end)

	t.test("re-examining a discovered clue re-opens it without a new discovery", function()
		local player = makePlayer()
		expect.falsy(EvidenceService.review(player, "EV-KEY"))
		EvidenceService.discover(player, "EV-KEY")
		expect.truthy(EvidenceService.review(player, "EV-KEY"))
		local ok, reason = EvidenceService.discover(player, "EV-KEY")
		expect.falsy(ok)
		expect.equal(reason, "already-discovered")
	end)

	t.test("the validator reports dangling nodes, choices and conditions", function()
		local problems = ConversationService.validate({
			id = "BROKEN",
			title = "",
			description = "",
			suspects = {},
			locations = {},
			evidence = {},
			timeline = {},
			objectives = {},
			conversations = {
				{
					suspectId = "X",
					startNodeId = "MISSING",
					nodes = {
						A = {
							id = "A",
							speaker = "X",
							text = "",
							next = "NOWHERE",
							statementId = "STMT-NONE",
							choices = {
								{
									id = "c",
									text = "",
									next = "GONE",
									requires = { { kind = "Evidence", id = "EV-NONE" } },
								},
								{ id = "c", text = "", next = "A", requires = { { kind = "Flag", id = "never-set" } } },
							},
						},
					},
				},
			},
			statements = {},
			contradictions = {},
			deductions = {},
		} :: any)
		-- start node, next, statement, choice next, evidence, duplicate id, flag
		expect.equal(#problems, 7)
	end)
end
