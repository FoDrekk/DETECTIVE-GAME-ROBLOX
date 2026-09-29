--!strict
--[[
	Phase 5.1: evidence handed over in a conversation
	(DialogueNodeDefinition.grantsEvidence -> EvidenceService.grant).

	Proves, on a synthetic fixture case (no CASE-001 story content):
	  * reaching a granting line discovers the evidence server-side, with the
	    same consequences as examining it (timeline, StoryEvent, objectives --
	    including an objective whose requirement names an interaction kind);
	  * it is idempotent, so the same evidence can have more than one route
	    (found first by examining, or granted twice) without double counting;
	  * questions that need the evidence are offered on the granting line;
	  * the graph validator and OfficeRoom-style checks treat it correctly.

	The client-facing notice (DialoguePayload.grantedEvidence, and
	EvidencePayload.granted) is checked end to end in the engine playthrough
	(tools/headless/entry_engine.luau), where real remotes carry it.
]]
return function(t)
	local ServerScriptService = game:GetService("ServerScriptService")
	local Server = ServerScriptService:WaitForChild("Server")
	local ConversationService = require(Server:WaitForChild("ConversationService"))
	local PlayerDataService = require(Server:WaitForChild("PlayerDataService"))
	local EvidenceService = require(Server:WaitForChild("EvidenceService"))
	local ObjectiveService = require(Server:WaitForChild("ObjectiveService"))
	local StoryEvents = require(Server:WaitForChild("StoryEvents"))
	local CaseRegistry = require(game:GetService("ServerStorage"):WaitForChild("Config"):WaitForChild("CaseRegistry"))
	local expect = t.expect

	local CASE_ID = "CASE-TEST-GRANT"

	local fixture = {
		id = CASE_ID,
		title = "Grant Fixture",
		description = "",
		suspects = {
			{ id = "WIT", name = "Witness", role = "Neighbour", alibi = "Home." },
		},
		locations = {},
		evidence = {
			{
				id = "EV-NOTE",
				name = "Note",
				description = "A folded note.",
				location = "Pocket",
				importance = "High",
				timelineEventId = "TL-NOTE",
			},
			{ id = "EV-PHOTO", name = "Photo", description = "A photo.", location = "Pocket", importance = "Low" },
		},
		timeline = {
			{
				id = "TL-NOTE",
				timestamp = "11:48 PM",
				timeMinutes = 1428,
				title = "The note",
				description = "Written, never sent.",
				sourceEvidenceIds = { "EV-NOTE" },
			},
		},
		objectives = {
			{
				id = "OBJ-NOTE",
				title = "The note",
				description = "",
				requiredEvidence = { "EV-NOTE" },
				requiredInteractions = {},
				-- An interaction kind on the requirement: a granted clue has no
				-- interaction, and must still count (evidence known implies it).
				requirements = { { id = "R-NOTE", label = "Read the note", interaction = "Read", evidence = "EV-NOTE" } },
			},
		},
		conversations = {
			{
				suspectId = "WIT",
				startNodeId = "HUB",
				nodes = {
					HUB = {
						id = "HUB",
						speaker = "Witness",
						text = "Well?",
						choices = {
							{ id = "give", text = "Can I see it?", next = "GIVE" },
							{ id = "both", text = "Anything else?", next = "BOTH" },
							{
								id = "about",
								text = "Who wrote this?",
								next = "ABOUT",
								requires = { { kind = "Evidence", id = "EV-NOTE" } },
							},
							{ id = "bye", text = "Thanks.", next = "BYE" },
						},
					},
					GIVE = {
						id = "GIVE",
						speaker = "Witness",
						text = "Here.",
						grantsEvidence = { "EV-NOTE" },
						statementId = "STMT-GAVE",
						choicesFrom = "HUB",
					},
					BOTH = {
						id = "BOTH",
						speaker = "Witness",
						text = "Take both.",
						grantsEvidence = { "EV-NOTE", "EV-PHOTO" },
						choicesFrom = "HUB",
					},
					ABOUT = { id = "ABOUT", speaker = "Witness", text = "He did.", choicesFrom = "HUB" },
					BYE = { id = "BYE", speaker = "Witness", text = "Bye." },
				},
			},
		},
		statements = {
			{ id = "STMT-GAVE", suspectId = "WIT", label = "Handed over the note", text = "Gave me his note." },
		},
		contradictions = {},
		deductions = {},
	}
	CaseRegistry.register(fixture :: any)

	local function makePlayer(): any
		local id = t.nextUserId()
		local player = { UserId = id, Name = `GR{id}` }
		PlayerDataService.initialize(player, CASE_ID)
		return player
	end

	local function choiceIds(player: any): { [string]: boolean }
		local ids = {}
		for _, choice in ipairs(ConversationService.getCurrentPayload(player).choices or {}) do
			ids[choice.id] = true
		end
		return ids
	end

	local function withPublishSpy(fn: (calls: { { kind: string, data: any } }) -> ())
		local calls = {}
		local original = StoryEvents.publish
		StoryEvents.publish = function(kind, _player, data)
			table.insert(calls, { kind = kind, data = data })
		end
		local ok, err = pcall(fn, calls)
		StoryEvents.publish = original
		if not ok then
			error(err, 0)
		end
	end

	local function count(calls: { { kind: string, data: any } }, kind: string, evidenceId: string): number
		local n = 0
		for _, call in ipairs(calls) do
			if call.kind == kind and call.data.evidenceId == evidenceId then
				n += 1
			end
		end
		return n
	end

	t.test("the fixture's conversation graph validates clean", function()
		expect.equal(#ConversationService.validate(fixture :: any), 0)
	end)

	t.test("reaching a granting line discovers the evidence, server-side", function()
		local player = makePlayer()
		expect.falsy(EvidenceService.isDiscovered(player, "EV-NOTE"))
		expect.truthy(ConversationService.begin(player, "WIT"))
		expect.truthy(ConversationService.choose(player, "give"))
		expect.truthy(EvidenceService.isDiscovered(player, "EV-NOTE"))
		-- The line's own statement is unlocked as before.
		local data = PlayerDataService.get(player) :: any
		expect.truthy(data.caseState.unlockedStatements["STMT-GAVE"])
	end)

	t.test("a granted clue reveals its timeline event, like an examined one", function()
		local player = makePlayer()
		ConversationService.begin(player, "WIT")
		ConversationService.choose(player, "give")
		local data = PlayerDataService.get(player) :: any
		expect.truthy(data.caseState.discoveredTimeline["TL-NOTE"])
	end)

	t.test("a granted clue advances objectives, even one that names an interaction", function()
		local player = makePlayer()
		ConversationService.begin(player, "WIT")
		ConversationService.choose(player, "give")
		expect.truthy(ObjectiveService.getProgress(player, "OBJ-NOTE")["R-NOTE"])
		expect.equal(ObjectiveService.getActiveObjectiveId(player), nil)
	end)

	t.test("questions that need the evidence are offered on the granting line itself", function()
		local player = makePlayer()
		ConversationService.begin(player, "WIT")
		expect.falsy(choiceIds(player).about)
		ConversationService.choose(player, "give")
		expect.truthy(choiceIds(player).about)
	end)

	t.test("the grant publishes EvidenceDiscovered once, and never again on a repeat", function()
		local player = makePlayer()
		withPublishSpy(function(calls)
			ConversationService.begin(player, "WIT")
			ConversationService.choose(player, "give")
			expect.equal(count(calls, "EvidenceDiscovered", "EV-NOTE"), 1)
			-- Asked again: the line is reached again, nothing new is handed over.
			ConversationService.choose(player, "give")
			expect.equal(count(calls, "EvidenceDiscovered", "EV-NOTE"), 1)
		end)
	end)

	t.test("evidence already found another way is not granted twice", function()
		local player = makePlayer()
		expect.truthy(EvidenceService.discover(player, "EV-NOTE"))
		withPublishSpy(function(calls)
			ConversationService.begin(player, "WIT")
			ConversationService.choose(player, "give")
			expect.equal(count(calls, "EvidenceDiscovered", "EV-NOTE"), 0)
		end)
		local data = PlayerDataService.get(player) :: any
		local found = 0
		for _ in pairs(data.caseState.discovered) do
			found += 1
		end
		expect.equal(found, 1)
	end)

	t.test("a line can hand over several, skipping what is already known", function()
		local player = makePlayer()
		ConversationService.begin(player, "WIT")
		ConversationService.choose(player, "give")
		withPublishSpy(function(calls)
			ConversationService.choose(player, "both")
			expect.equal(count(calls, "EvidenceDiscovered", "EV-NOTE"), 0)
			expect.equal(count(calls, "EvidenceDiscovered", "EV-PHOTO"), 1)
		end)
		expect.truthy(EvidenceService.isDiscovered(player, "EV-PHOTO"))
	end)

	t.test("EvidenceService.grant is idempotent and rejects unknown ids", function()
		local player = makePlayer()
		local ok, reason = EvidenceService.grant(player, "EV-PHOTO")
		expect.truthy(ok)
		expect.equal(reason, nil)
		ok, reason = EvidenceService.grant(player, "EV-PHOTO")
		expect.falsy(ok)
		expect.equal(reason, "already-discovered")
		ok, reason = EvidenceService.grant(player, "EV-NOPE")
		expect.falsy(ok)
		expect.equal(reason, "unknown-evidence")
	end)

	t.test("ObjectiveService.recordEvidence ignores bad input and players without data", function()
		expect.falsy(ObjectiveService.recordEvidence(makePlayer(), ""))
		expect.falsy(ObjectiveService.recordEvidence({ UserId = t.nextUserId(), Name = "Nobody" } :: any, "EV-NOTE"))
	end)

	t.test("the validator reports a line that grants unknown evidence", function()
		local broken = table.clone(fixture) :: any
		broken.conversations = {
			{
				suspectId = "WIT",
				startNodeId = "A",
				nodes = {
					A = { id = "A", speaker = "Witness", text = "Take it.", grantsEvidence = { "EV-NOTE", "EV-GHOST" } },
				},
			},
		}
		local problems = ConversationService.validate(broken)
		expect.equal(#problems, 1)
		expect.truthy(string.find(problems[1], "EV-GHOST", 1, true))
	end)
end
