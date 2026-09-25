--!strict
--[[
	Tests for ServerScriptService.Server.ObjectiveService.
	Covers requirement progress from evidence/interaction, completion exactly
	once, that replaying the same interaction adds no progress, (Phase 2F)
	data-driven multi-objective sequencing via `prerequisites` and the
	`target` requirement gate, (Phase 2J) the contradiction/deduction
	requirement gates driven by ReasoningService's StoryEvents, and (Phase 2K)
	that no objective remains active once every one is complete -- the
	condition `ObjectivePayload.allComplete` is computed from. The wire
	payload's `allComplete` field itself is verified via the real Studio
	walkthrough, not here: `ObjectiveService.onUpdated()`'s BindableEvent
	fires deferred, so capturing a fired payload from inside this harness is
	unreliable (see Phase 2H's notes) -- `getActiveObjectiveId` is the exact
	synchronous condition `allComplete` is derived from
	(`getActiveObjective(data) == nil`), so testing it here is equivalent.

	Each case uses a unique mock UserId for isolation. The sequencing tests
	register a small synthetic case purely for this test run (CaseRegistry.
	register), so CASE-001's real story data is never touched or duplicated.
]]
return function(t)
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Server = ServerScriptService:WaitForChild("Server")
	local ObjectiveService = require(Server:WaitForChild("ObjectiveService"))
	local PlayerDataService = require(Server:WaitForChild("PlayerDataService"))
	local EvidenceService = require(Server:WaitForChild("EvidenceService"))
	local ConversationService = require(Server:WaitForChild("ConversationService"))
	local ReasoningService = require(Server:WaitForChild("ReasoningService"))
	local TimelineService = require(Server:WaitForChild("TimelineService"))
	local StoryEvents = require(Server:WaitForChild("StoryEvents"))
	local CaseRegistry = require(game:GetService("ServerStorage"):WaitForChild("Config"):WaitForChild("CaseRegistry"))
	local expect = t.expect

	local function makePlayer(): any
		local id = t.nextUserId()
		local player = { UserId = id, Name = `OBJ{id}` }
		PlayerDataService.initialize(player, "CASE-001")
		return player
	end

	-- Swaps StoryEvents.publish for a spy for the duration of fn (see Phase
	-- 2F/2H/2I's precedent for why: BindableEvents fire deferred, so a live
	-- event listener from inside this harness is unreliable).
	local function withPublishSpy(fn: (calls: { { kind: string, player: any, data: any } }) -> ())
		local calls = {}
		local original = StoryEvents.publish
		StoryEvents.publish = function(kind, player, data)
			table.insert(calls, { kind = kind, player = player, data = data })
		end
		local ok, err = pcall(fn, calls)
		StoryEvents.publish = original
		if not ok then
			error(err, 0)
		end
	end

	local function progressOf(player: any): { [string]: boolean }
		return ObjectiveService.getProgress(player, "OBJ-001")
	end

	-- A fresh player has no requirement progress.
	t.test("starts with no progress", function()
		local player = makePlayer()
		local progress = progressOf(player)
		expect.falsy(progress["REQ-001"])
		expect.falsy(progress["REQ-002"])
		expect.falsy(progress["REQ-003"])
	end)

	-- Examining with EV-001 advances the phone requirement only.
	t.test("advances the phone requirement", function()
		local player = makePlayer()
		ObjectiveService.recordInteraction(player, "Examine", "EV-001")
		local progress = progressOf(player)
		expect.truthy(progress["REQ-001"])
		expect.falsy(progress["REQ-002"])
		expect.falsy(progress["REQ-003"])
	end)

	-- Reading EV-003 advances the document requirement (kind-specific).
	t.test("advances the document requirement on Read", function()
		local player = makePlayer()
		ObjectiveService.recordInteraction(player, "Read", "EV-003")
		expect.truthy(progressOf(player)["REQ-003"])
	end)

	-- A mismatched kind does not satisfy the Read requirement.
	t.test("does not satisfy a kind-specific requirement with the wrong kind", function()
		local player = makePlayer()
		ObjectiveService.recordInteraction(player, "Examine", "EV-003")
		expect.falsy(progressOf(player)["REQ-003"])
	end)

	-- Completing all requirements completes the objective.
	t.test("completes once all requirements are met", function()
		local player = makePlayer()
		ObjectiveService.recordInteraction(player, "Examine", "EV-001")
		ObjectiveService.recordInteraction(player, "Examine", "EV-002")
		ObjectiveService.recordInteraction(player, "Read", "EV-003")
		local progress = progressOf(player)
		expect.truthy(progress["REQ-001"])
		expect.truthy(progress["REQ-002"])
		expect.truthy(progress["REQ-003"])
	end)

	-- Replaying the same interaction reports no new progress.
	t.test("replaying an interaction adds no progress", function()
		local player = makePlayer()
		ObjectiveService.recordInteraction(player, "Examine", "EV-001")
		local advanced = ObjectiveService.recordInteraction(player, "Examine", "EV-001")
		expect.falsy(advanced)
	end)

	-- Completion state is recorded exactly once.
	t.test("records completion exactly once", function()
		local player = makePlayer()
		ObjectiveService.recordInteraction(player, "Examine", "EV-001")
		ObjectiveService.recordInteraction(player, "Examine", "EV-002")
		ObjectiveService.recordInteraction(player, "Read", "EV-003")
		local data = PlayerDataService.get(player)
		expect.truthy(data and data.caseState.completedObjectives["OBJ-001"])
	end)

	-- An interaction with no evidence id advances nothing.
	t.test("evidence-less interactions advance no evidence requirement", function()
		local player = makePlayer()
		local advanced = ObjectiveService.recordInteraction(player, "Examine", nil)
		expect.falsy(advanced)
	end)

	-- An unrelated evidence id advances nothing.
	t.test("unrelated evidence advances nothing", function()
		local player = makePlayer()
		local advanced = ObjectiveService.recordInteraction(player, "Examine", "EV-999")
		expect.falsy(advanced)
	end)

	-- CASE-001's first objective still has no prerequisites, so it must
	-- remain the active objective from the start (Phase 2E behavior, now
	-- derived from the data-driven active-objective lookup instead of a
	-- hardcoded objectives[1]).
	t.test("OBJ-001 remains active with no prerequisites (regression)", function()
		local player = makePlayer()
		expect.equal(ObjectiveService.getActiveObjectiveId(player), "OBJ-001")
	end)

	-- -----------------------------------------------------------------
	-- OBJ-002 (Phase 2I): CASE-001's real second objective, gated behind
	-- OBJ-001 via `prerequisites`, requiring a real Talk+target interaction
	-- with SUS-002's spawned NPC. Exercises the exact same mechanism the
	-- CASE-TEST-SEQ fixture below already proves generically -- this proves
	-- it against CASE-001's own real data instead.
	-- -----------------------------------------------------------------

	t.test("OBJ-002 is locked while OBJ-001 is incomplete", function()
		local player = makePlayer()
		local advanced = ObjectiveService.recordInteraction(player, "Talk", nil, "SUS-002")
		expect.falsy(advanced)
		local data = PlayerDataService.get(player)
		expect.falsy(data and data.caseState.completedObjectives["OBJ-002"])
	end)

	t.test("completing OBJ-001 activates OBJ-002", function()
		local player = makePlayer()
		ObjectiveService.recordInteraction(player, "Examine", "EV-001")
		ObjectiveService.recordInteraction(player, "Examine", "EV-002")
		ObjectiveService.recordInteraction(player, "Read", "EV-003")
		local data = PlayerDataService.get(player)
		expect.truthy(data and data.caseState.completedObjectives["OBJ-001"])
		expect.equal(ObjectiveService.getActiveObjectiveId(player), "OBJ-002")
	end)

	t.test("talking to Mara (SUS-001) does not satisfy OBJ-002's target", function()
		local player = makePlayer()
		ObjectiveService.recordInteraction(player, "Examine", "EV-001")
		ObjectiveService.recordInteraction(player, "Examine", "EV-002")
		ObjectiveService.recordInteraction(player, "Read", "EV-003")
		local advanced = ObjectiveService.recordInteraction(player, "Talk", nil, "SUS-001")
		expect.falsy(advanced)
		local data = PlayerDataService.get(player)
		expect.falsy(data and data.caseState.completedObjectives["OBJ-002"])
	end)

	t.test("talking to Victor (SUS-002) completes OBJ-002 once OBJ-001 is done", function()
		local player = makePlayer()
		ObjectiveService.recordInteraction(player, "Examine", "EV-001")
		ObjectiveService.recordInteraction(player, "Examine", "EV-002")
		ObjectiveService.recordInteraction(player, "Read", "EV-003")
		local advanced = ObjectiveService.recordInteraction(player, "Talk", nil, "SUS-002")
		expect.truthy(advanced)
		local data = PlayerDataService.get(player)
		expect.truthy(data and data.caseState.completedObjectives["OBJ-002"])
	end)

	-- -----------------------------------------------------------------
	-- Multi-objective sequencing (Phase 2F). Synthetic case, registered
	-- once for this test run only.
	-- -----------------------------------------------------------------

	CaseRegistry.register({
		id = "CASE-TEST-SEQ",
		title = "Sequencing Fixture",
		description = "Synthetic case for objective sequencing tests only.",
		suspects = {},
		locations = {},
		evidence = {},
		timeline = {},
		conversations = {},
		statements = {},
		objectives = {
			{
				id = "OBJ-A",
				title = "First",
				description = "First objective; no prerequisites.",
				requiredEvidence = {},
				requiredInteractions = { "Examine" },
				requirements = {
					{ id = "A-REQ-1", label = "Do the first thing", interaction = "Examine", target = "Fixture" },
				},
			},
			{
				id = "OBJ-B",
				title = "Second",
				description = "Second objective; requires OBJ-A.",
				requiredEvidence = {},
				requiredInteractions = { "Read" },
				requirements = {
					{ id = "B-REQ-1", label = "Do the second thing", interaction = "Read" },
				},
				prerequisites = { "OBJ-A" },
			},
			{
				-- Phase 2G: demonstrates that a conversation target can be
				-- expressed with the existing ObjectiveRequirement schema
				-- (interaction = "Talk", target = <interactable Name>) --
				-- proving the capability without touching CASE-001's real
				-- OBJ-001 or inventing a new storyline objective for it.
				id = "OBJ-C",
				title = "Third",
				description = "Third objective; requires OBJ-B. Talk requirement.",
				requiredEvidence = {},
				requiredInteractions = { "Talk" },
				requirements = {
					{ id = "C-REQ-1", label = "Talk to the suspect", interaction = "Talk", target = "SuspectFixture" },
				},
				prerequisites = { "OBJ-B" },
			},
		},
	})

	local function makeSeqPlayer(): any
		local id = t.nextUserId()
		local player = { UserId = id, Name = `SEQ{id}` }
		PlayerDataService.initialize(player, "CASE-TEST-SEQ")
		return player
	end

	-- OBJ-B's requirement is never even evaluated while OBJ-A is incomplete.
	t.test("a locked objective's requirement does not advance", function()
		local player = makeSeqPlayer()
		local advanced = ObjectiveService.recordInteraction(player, "Read", nil, nil)
		expect.falsy(advanced)
	end)

	-- The `target` gate only matches the exact authored instance name.
	t.test("target requirement rejects a non-matching instance name", function()
		local player = makeSeqPlayer()
		local advanced = ObjectiveService.recordInteraction(player, "Examine", nil, "WrongName")
		expect.falsy(advanced)
		local data = PlayerDataService.get(player)
		expect.falsy(data and data.caseState.completedObjectives["OBJ-A"])
	end)

	-- Completing OBJ-A (matching kind + target) unlocks OBJ-B, which can then
	-- advance and complete on a later interaction.
	t.test("completing OBJ-A unlocks OBJ-B", function()
		local player = makeSeqPlayer()
		ObjectiveService.recordInteraction(player, "Examine", nil, "Fixture")
		local data = PlayerDataService.get(player)
		expect.truthy(data and data.caseState.completedObjectives["OBJ-A"])

		local advanced = ObjectiveService.recordInteraction(player, "Read", nil, nil)
		expect.truthy(advanced)
		expect.truthy(data and data.caseState.completedObjectives["OBJ-B"])
	end)

	-- getActiveObjectiveId reports OBJ-A as active for a fresh sequencing
	-- player (no prerequisites, not yet completed).
	t.test("OBJ-A is the active objective for a fresh player", function()
		local player = makeSeqPlayer()
		expect.equal(ObjectiveService.getActiveObjectiveId(player), "OBJ-A")
	end)

	-- Once OBJ-A completes, OBJ-B becomes the active objective immediately
	-- (no further interaction required to unlock it).
	t.test("OBJ-B becomes the active objective once OBJ-A is complete", function()
		local player = makeSeqPlayer()
		ObjectiveService.recordInteraction(player, "Examine", nil, "Fixture")
		expect.equal(ObjectiveService.getActiveObjectiveId(player), "OBJ-B")
	end)

	-- Duplicate completion is idempotent: replaying the interaction that
	-- already completed OBJ-A reports no further advancement.
	t.test("duplicate completion of OBJ-A advances nothing further", function()
		local player = makeSeqPlayer()
		local advancedFirst = ObjectiveService.recordInteraction(player, "Examine", nil, "Fixture")
		expect.truthy(advancedFirst)
		local data = PlayerDataService.get(player)
		expect.truthy(data and data.caseState.completedObjectives["OBJ-A"])

		local advancedSecond = ObjectiveService.recordInteraction(player, "Examine", nil, "Fixture")
		expect.falsy(advancedSecond)
	end)

	-- Phase 2G: a Talk interaction with a target advances an objective
	-- requirement through the existing, unmodified ObjectiveRequirement
	-- schema -- the same mechanism InteractionService's talkHandler drives
	-- when a player talks to a suspect NPC.
	t.test("a Talk interaction with a target advances OBJ-C once unlocked", function()
		local player = makeSeqPlayer()
		ObjectiveService.recordInteraction(player, "Examine", nil, "Fixture") -- completes OBJ-A
		ObjectiveService.recordInteraction(player, "Read", nil, nil) -- completes OBJ-B
		expect.equal(ObjectiveService.getActiveObjectiveId(player), "OBJ-C")

		-- Wrong target name does not satisfy it.
		local wrongTarget = ObjectiveService.recordInteraction(player, "Talk", nil, "SomeoneElse")
		expect.falsy(wrongTarget)

		local advanced = ObjectiveService.recordInteraction(player, "Talk", nil, "SuspectFixture")
		expect.truthy(advanced)
		local data = PlayerDataService.get(player)
		expect.truthy(data and data.caseState.completedObjectives["OBJ-C"])
	end)

	----------------------------------------------------------------------
	-- Contradiction/deduction requirement gates (Phase 2J). Synthetic
	-- fixture, registered once for this test run only -- proves the
	-- mechanism generically before the real CASE-001 integration test below.
	-- No prerequisites on either fixture objective, so both are active
	-- immediately for a fresh player, letting the contradiction and
	-- deduction gates be tested independently.
	----------------------------------------------------------------------

	CaseRegistry.register({
		id = "CASE-TEST-OBJ-REASONING",
		title = "Objective Reasoning Fixture",
		description = "Synthetic case for contradiction/deduction requirement tests only.",
		suspects = {},
		locations = {},
		evidence = {
			{ id = "EV-FIX-A", name = "Fixture A", description = "", location = "", importance = "Low" },
			{ id = "EV-FIX-B", name = "Fixture B", description = "", location = "", importance = "Low" },
		},
		timeline = {},
		objectives = {
			{
				id = "OBJ-FIX-CONTRA",
				title = "Contradiction Fixture Objective",
				description = "",
				requiredEvidence = {},
				requiredInteractions = {},
				requirements = {
					{ id = "FIX-REQ-CONTRA", label = "Contradiction gate", contradiction = "CONTRA-FIX" },
				},
			},
			{
				id = "OBJ-FIX-DEDUCE",
				title = "Deduction Fixture Objective",
				description = "",
				requiredEvidence = {},
				requiredInteractions = {},
				requirements = {
					{ id = "FIX-REQ-DEDUCE", label = "Deduction gate", deduction = "DEDUCE-FIX" },
				},
			},
		},
		conversations = {},
		statements = {},
		contradictions = {
			{
				id = "CONTRA-FIX",
				label = "Fixture Contradiction",
				left = { kind = "Evidence", id = "EV-FIX-A" },
				right = { kind = "Evidence", id = "EV-FIX-B" },
			},
		},
		deductions = {
			{
				id = "DEDUCE-FIX",
				label = "Fixture Deduction",
				requiredFacts = { { kind = "Evidence", id = "EV-FIX-A" } },
			},
		},
	})

	local function makeReasoningObjPlayer(): any
		local id = t.nextUserId()
		local player = { UserId = id, Name = `OBJREASON{id}` }
		PlayerDataService.initialize(player, "CASE-TEST-OBJ-REASONING")
		return player
	end

	t.test("a contradiction-gated requirement stays locked before the contradiction unlocks", function()
		local player = makeReasoningObjPlayer()
		local progress = ObjectiveService.getProgress(player, "OBJ-FIX-CONTRA")
		expect.falsy(progress["FIX-REQ-CONTRA"])
	end)

	t.test("recordFact rejects an unknown fact kind", function()
		local player = makeReasoningObjPlayer()
		local advanced = (ObjectiveService :: any).recordFact(player, "NotAKind", "CONTRA-FIX")
		expect.falsy(advanced)
	end)

	t.test("a contradiction-gated requirement satisfies once the contradiction is actually unlocked", function()
		local player = makeReasoningObjPlayer()
		EvidenceService.discover(player, "EV-FIX-A")
		EvidenceService.discover(player, "EV-FIX-B")
		ReasoningService.evaluate(player) -- genuinely unlocks CONTRA-FIX, not a poked flag

		local data = PlayerDataService.get(player)
		expect.truthy(data.caseState.unlockedContradictions["CONTRA-FIX"])
		-- Unlocking the fact alone does not retroactively scan objectives
		-- (no polling): recordFact is the trigger, mirroring the real
		-- ContradictionUnlocked -> ObjectiveService StoryEvents subscription.
		expect.falsy(data.caseState.completedObjectives["OBJ-FIX-CONTRA"])

		local advanced = ObjectiveService.recordFact(player, "Contradiction", "CONTRA-FIX")
		expect.truthy(advanced)
		expect.truthy(data.caseState.completedObjectives["OBJ-FIX-CONTRA"])
	end)

	t.test("an unrelated contradiction id does not complete the objective", function()
		local player = makeReasoningObjPlayer()
		local advanced = ObjectiveService.recordFact(player, "Contradiction", "CONTRA-DOES-NOT-EXIST")
		expect.falsy(advanced)
		local data = PlayerDataService.get(player)
		expect.falsy(data.caseState.completedObjectives["OBJ-FIX-CONTRA"])
	end)

	t.test("duplicate recordFact calls do not double-complete or double-publish", function()
		local player = makeReasoningObjPlayer()
		EvidenceService.discover(player, "EV-FIX-A")
		EvidenceService.discover(player, "EV-FIX-B")
		ReasoningService.evaluate(player)

		withPublishSpy(function(calls)
			ObjectiveService.recordFact(player, "Contradiction", "CONTRA-FIX")
			ObjectiveService.recordFact(player, "Contradiction", "CONTRA-FIX") -- duplicate

			local completions = 0
			for _, call in ipairs(calls) do
				if call.kind == "ObjectiveCompleted" and call.data.objectiveId == "OBJ-FIX-CONTRA" then
					completions += 1
				end
			end
			expect.equal(completions, 1)
		end)
	end)

	t.test("a deduction-gated requirement stays locked before the deduction unlocks", function()
		local player = makeReasoningObjPlayer()
		local progress = ObjectiveService.getProgress(player, "OBJ-FIX-DEDUCE")
		expect.falsy(progress["FIX-REQ-DEDUCE"])
	end)

	t.test("a deduction-gated requirement satisfies once the deduction is actually unlocked", function()
		local player = makeReasoningObjPlayer()
		EvidenceService.discover(player, "EV-FIX-A")
		ReasoningService.evaluate(player) -- genuinely unlocks DEDUCE-FIX

		local data = PlayerDataService.get(player)
		expect.truthy(data.caseState.unlockedDeductions["DEDUCE-FIX"])
		expect.falsy(data.caseState.completedObjectives["OBJ-FIX-DEDUCE"])

		local advanced = ObjectiveService.recordFact(player, "Deduction", "DEDUCE-FIX")
		expect.truthy(advanced)
		expect.truthy(data.caseState.completedObjectives["OBJ-FIX-DEDUCE"])
	end)

	t.test("recordFact for a player with no data is safe and reports no advancement", function()
		local stranger = { UserId = -999999999, Name = "Stranger" }
		local advanced = ObjectiveService.recordFact(stranger, "Contradiction", "CONTRA-FIX")
		expect.falsy(advanced)
	end)

	----------------------------------------------------------------------
	-- Real CASE-001 integration (Phase 2J): OBJ-001 -> OBJ-002 -> Victor's
	-- statement -> EV-004 -> CONTRA-001 -> OBJ-003, using production data,
	-- not the synthetic fixture above.
	----------------------------------------------------------------------

	t.test("OBJ-003 is locked while OBJ-002 is incomplete", function()
		local player = makePlayer()
		ObjectiveService.recordInteraction(player, "Examine", "EV-001")
		ObjectiveService.recordInteraction(player, "Examine", "EV-002")
		ObjectiveService.recordInteraction(player, "Read", "EV-003")
		local data = PlayerDataService.get(player)
		expect.truthy(data.caseState.completedObjectives["OBJ-001"])
		expect.falsy(data.caseState.completedObjectives["OBJ-002"])
		expect.equal(ObjectiveService.getActiveObjectiveId(player), "OBJ-002")
	end)

	t.test(
		"real CASE-001 path: OBJ-001 -> OBJ-002 -> Victor statement -> EV-004 -> CONTRA-001 -> OBJ-003",
		function()
			local player = makePlayer()
			local data = PlayerDataService.get(player)

			-- OBJ-001: survey the scene.
			ObjectiveService.recordInteraction(player, "Examine", "EV-001")
			ObjectiveService.recordInteraction(player, "Examine", "EV-002")
			ObjectiveService.recordInteraction(player, "Read", "EV-003")
			expect.truthy(data.caseState.completedObjectives["OBJ-001"])

			-- OBJ-002: talk to Victor (mirrors InteractionService's real call
			-- order -- begin() first, then the interaction is recorded).
			ConversationService.begin(player, "SUS-002")
			ObjectiveService.recordInteraction(player, "Talk", nil, "SUS-002")
			expect.truthy(data.caseState.completedObjectives["OBJ-002"])
			expect.equal(ObjectiveService.getActiveObjectiveId(player), "OBJ-003")
			expect.falsy(data.caseState.completedObjectives["OBJ-003"])

			ConversationService.advance(player) -- -> alibi node, unlocks STMT-SUS-002-ALIBI
			expect.truthy(ConversationService.isStatementUnlocked(player, "STMT-SUS-002-ALIBI"))
			ConversationService.advance(player) -- -> closing node
			ConversationService.advance(player) -- -> completes

			-- Discover the keycard log; CONTRA-001 needs both this and the
			-- statement above.
			EvidenceService.discover(player, "EV-004")
			ReasoningService.evaluate(player)
			expect.truthy(data.caseState.unlockedContradictions["CONTRA-001"])

			-- Unlocking the contradiction alone does not complete OBJ-003
			-- (no polling) -- the StoryEvents subscription is what triggers
			-- re-evaluation in production; simulated here exactly as the
			-- Phase 2H/2I precedent does for deferred BindableEvent delivery.
			expect.falsy(data.caseState.completedObjectives["OBJ-003"])

			ObjectiveService.recordFact(player, "Contradiction", "CONTRA-001")
			expect.truthy(data.caseState.completedObjectives["OBJ-003"])
		end
	)

	t.test("OBJ-003 completes immediately if CONTRA-001 was already unlocked before OBJ-002 finished", function()
		-- Edge case B from the Phase 2J spec: the contradiction fact can
		-- become known before the objective gated on it is even active.
		-- Discover EV-004 first, then only unlock the statement (and
		-- therefore CONTRA-001) once OBJ-002 completes.
		local player = makePlayer()
		local data = PlayerDataService.get(player)

		ObjectiveService.recordInteraction(player, "Examine", "EV-001")
		ObjectiveService.recordInteraction(player, "Examine", "EV-002")
		ObjectiveService.recordInteraction(player, "Read", "EV-003")

		EvidenceService.discover(player, "EV-004") -- known before Victor is ever talked to
		ReasoningService.evaluate(player)
		expect.falsy(data.caseState.unlockedContradictions["CONTRA-001"]) -- statement still missing

		ConversationService.begin(player, "SUS-002")
		ObjectiveService.recordInteraction(player, "Talk", nil, "SUS-002") -- completes OBJ-002, activates OBJ-003
		ConversationService.advance(player) -- unlocks STMT-SUS-002-ALIBI
		ReasoningService.evaluate(player) -- now both facts are known
		expect.truthy(data.caseState.unlockedContradictions["CONTRA-001"])

		-- requirementSatisfied reads live unlockedContradictions state, not
		-- a one-shot event payload, so this still requires the StoryEvents
		-- subscription's recordFact call to trigger re-evaluation -- but
		-- once triggered, it must succeed regardless of this ordering.
		expect.falsy(data.caseState.completedObjectives["OBJ-003"])
		ObjectiveService.recordFact(player, "Contradiction", "CONTRA-001")
		expect.truthy(data.caseState.completedObjectives["OBJ-003"])
	end)

	t.test("OBJ-001 and OBJ-002 requirements are unaffected by the new requirement fields (regression)", function()
		local player = makePlayer()
		local advanced = ObjectiveService.recordInteraction(player, "Examine", "EV-001")
		expect.truthy(advanced)
		local progress = ObjectiveService.getProgress(player, "OBJ-001")
		expect.truthy(progress["REQ-001"])
		expect.falsy(progress["REQ-002"])
		expect.falsy(progress["REQ-003"])
	end)

	----------------------------------------------------------------------
	-- "All objectives complete" condition (Phase 2K). `allComplete` on the
	-- wire payload is `getActiveObjective(data) == nil` -- exactly what
	-- `getActiveObjectiveId` already reports synchronously, so verifying it
	-- here verifies the same logic without depending on deferred
	-- BindableEvent delivery. See the file header for why.
	----------------------------------------------------------------------

	t.test("an active objective remains after only OBJ-001 completes", function()
		local player = makePlayer()
		ObjectiveService.recordInteraction(player, "Examine", "EV-001")
		ObjectiveService.recordInteraction(player, "Examine", "EV-002")
		ObjectiveService.recordInteraction(player, "Read", "EV-003")
		expect.equal(ObjectiveService.getActiveObjectiveId(player), "OBJ-002")
	end)

	t.test("an active objective remains after only OBJ-002 completes", function()
		local player = makePlayer()
		ObjectiveService.recordInteraction(player, "Examine", "EV-001")
		ObjectiveService.recordInteraction(player, "Examine", "EV-002")
		ObjectiveService.recordInteraction(player, "Read", "EV-003")
		ConversationService.begin(player, "SUS-002")
		ObjectiveService.recordInteraction(player, "Talk", nil, "SUS-002")
		expect.equal(ObjectiveService.getActiveObjectiveId(player), "OBJ-003")
	end)

	t.test("an active objective remains after only OBJ-003 completes", function()
		local player = makePlayer()
		local data = PlayerDataService.get(player)

		ObjectiveService.recordInteraction(player, "Examine", "EV-001")
		ObjectiveService.recordInteraction(player, "Examine", "EV-002")
		ObjectiveService.recordInteraction(player, "Read", "EV-003")
		ConversationService.begin(player, "SUS-002")
		ObjectiveService.recordInteraction(player, "Talk", nil, "SUS-002")
		ConversationService.advance(player) -- unlocks STMT-SUS-002-ALIBI
		expect.truthy(ObjectiveService.getActiveObjectiveId(player)) -- OBJ-003 still open

		EvidenceService.discover(player, "EV-004")
		ReasoningService.evaluate(player)
		ObjectiveService.recordFact(player, "Contradiction", "CONTRA-001")

		expect.truthy(data.caseState.completedObjectives["OBJ-003"])
		expect.equal(ObjectiveService.getActiveObjectiveId(player), "OBJ-004")
	end)

	-- Phase 2M: DEDUCT-001/OBJ-004 requires Mara's statement too -- nothing
	-- above this test ever speaks to her, so OBJ-004 only completes once
	-- that's added on top of the OBJ-003 chain. M5: OBJ-005 (reconstruct the
	-- timeline) is now the final objective, so OBJ-004 completing advances to
	-- OBJ-005 rather than ending the chain.
	t.test("OBJ-004 completing advances to OBJ-005 (reconstruct the timeline)", function()
		local player = makePlayer()
		local data = PlayerDataService.get(player)

		ObjectiveService.recordInteraction(player, "Examine", "EV-001")
		ObjectiveService.recordInteraction(player, "Examine", "EV-002")
		ObjectiveService.recordInteraction(player, "Read", "EV-003")
		ConversationService.begin(player, "SUS-002")
		ObjectiveService.recordInteraction(player, "Talk", nil, "SUS-002")
		ConversationService.advance(player) -- unlocks STMT-SUS-002-ALIBI
		EvidenceService.discover(player, "EV-004")
		ReasoningService.evaluate(player)
		ObjectiveService.recordFact(player, "Contradiction", "CONTRA-001")
		expect.equal(ObjectiveService.getActiveObjectiveId(player), "OBJ-004") -- OBJ-004 still open

		-- Victor's conversation is still active (only advanced once above) --
		-- leave it before starting Mara's, or begin() is a silent no-op.
		ConversationService.leave(player)
		ConversationService.begin(player, "SUS-001")
		ConversationService.advance(player) -- unlocks STMT-SUS-001-ALIBI
		ReasoningService.evaluate(player)
		ObjectiveService.recordFact(player, "Deduction", "DEDUCT-001")

		expect.truthy(data.caseState.completedObjectives["OBJ-004"])
		expect.equal(ObjectiveService.getActiveObjectiveId(player), "OBJ-005")
	end)

	-- M5: the timeline objective completes once the player has established the
	-- sequence, and only then is there no active objective left.
	t.test("no active objective remains once OBJ-005 (reconstruct timeline) completes", function()
		local player = makePlayer()
		local data = PlayerDataService.get(player)

		ObjectiveService.recordInteraction(player, "Examine", "EV-001")
		ObjectiveService.recordInteraction(player, "Examine", "EV-002")
		ObjectiveService.recordInteraction(player, "Read", "EV-003")
		ConversationService.begin(player, "SUS-002")
		ObjectiveService.recordInteraction(player, "Talk", nil, "SUS-002")
		ConversationService.advance(player)
		EvidenceService.discover(player, "EV-004")
		ReasoningService.evaluate(player)
		ObjectiveService.recordFact(player, "Contradiction", "CONTRA-001")
		ConversationService.leave(player)
		ConversationService.begin(player, "SUS-001")
		ConversationService.advance(player)
		ReasoningService.evaluate(player)
		ObjectiveService.recordFact(player, "Deduction", "DEDUCT-001")
		expect.equal(ObjectiveService.getActiveObjectiveId(player), "OBJ-005")

		-- Establishing the timeline completes it (via the direct objective
		-- progression the real game uses). Only EV-004 was discovered here, so
		-- the timeline is a single event.
		expect.truthy(TimelineService.submitSequence(player, { "TIMELINE-004" }))
		expect.truthy(data.caseState.completedObjectives["OBJ-005"])
		expect.falsy(ObjectiveService.getActiveObjectiveId(player))
	end)

	t.test("no active objective remains only once every fixture objective (OBJ-A/B/C) is complete", function()
		local player = makeSeqPlayer()
		expect.truthy(ObjectiveService.getActiveObjectiveId(player)) -- OBJ-A

		ObjectiveService.recordInteraction(player, "Examine", nil, "Fixture") -- completes OBJ-A
		expect.equal(ObjectiveService.getActiveObjectiveId(player), "OBJ-B")

		ObjectiveService.recordInteraction(player, "Read", nil, nil) -- completes OBJ-B
		expect.equal(ObjectiveService.getActiveObjectiveId(player), "OBJ-C")

		ObjectiveService.recordInteraction(player, "Talk", nil, "SuspectFixture") -- completes OBJ-C
		expect.falsy(ObjectiveService.getActiveObjectiveId(player))
	end)
end
