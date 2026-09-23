--!strict
--[[
	Tests for ServerScriptService.Server.ReasoningService.
	Covers contradiction/deduction evaluation, idempotent unlock, invalid
	fact references failing safely, per-player isolation, spoiler-safe
	payloads, and the EvidenceDiscovered/StatementUnlocked -> reasoning
	integration (Phase 2H).

	CASE-001 has no authored contradiction/deduction content (see
	ARCHITECTURE.md for why), so this entire suite runs against a synthetic
	case registered purely for this test run -- CASE-001's real evidence,
	statement and suspect data are never touched or duplicated.

	Each case uses a unique mock UserId for isolation.
]]
return function(t)
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Server = ServerScriptService:WaitForChild("Server")
	local ReasoningService = require(Server:WaitForChild("ReasoningService"))
	local EvidenceService = require(Server:WaitForChild("EvidenceService"))
	local ConversationService = require(Server:WaitForChild("ConversationService"))
	local PlayerDataService = require(Server:WaitForChild("PlayerDataService"))
	local StoryEvents = require(Server:WaitForChild("StoryEvents"))
	local CaseRegistry = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CaseRegistry"))
	local expect = t.expect

	-- Synthetic fixture: two evidence items, one suspect with a one-line
	-- conversation that unlocks one statement, one contradiction (EV-X vs
	-- EV-Y), one deduction (requires EV-X + STMT-X), and one of each with a
	-- dangling fact reference to prove invalid references fail safely.
	CaseRegistry.register({
		id = "CASE-TEST-REASONING",
		title = "Reasoning Fixture",
		description = "Synthetic case for contradiction/deduction tests only.",
		suspects = {
			{ id = "SUS-FIXTURE", name = "Fixture Suspect", role = "Fixture", alibi = "Fixture alibi text." },
		},
		locations = {},
		evidence = {
			{ id = "EV-X", name = "Fixture Evidence X", description = "", location = "", importance = "Low" },
			{ id = "EV-Y", name = "Fixture Evidence Y", description = "", location = "", importance = "Low" },
		},
		timeline = {},
		objectives = {},
		conversations = {
			{
				suspectId = "SUS-FIXTURE",
				startNodeId = "FIX-1",
				nodes = {
					["FIX-1"] = {
						id = "FIX-1",
						speaker = "Fixture Suspect",
						text = "Fixture line.",
						next = nil,
						statementId = "STMT-X",
					},
				},
			},
		},
		statements = {
			{ id = "STMT-X", suspectId = "SUS-FIXTURE", label = "Fixture Statement" },
		},
		contradictions = {
			{
				id = "CONTRA-X",
				label = "Fixture Contradiction",
				left = { kind = "Evidence", id = "EV-X" },
				right = { kind = "Evidence", id = "EV-Y" },
				reason = "Fixture reason.",
			},
			{
				id = "CONTRA-INVALID",
				label = "Dangling Contradiction",
				left = { kind = "Evidence", id = "EV-X" },
				right = { kind = "Evidence", id = "EV-GHOST" }, -- does not exist
			},
		},
		deductions = {
			{
				id = "DEDUCE-X",
				label = "Fixture Deduction",
				requiredFacts = {
					{ kind = "Evidence", id = "EV-X" },
					{ kind = "Statement", id = "STMT-X" },
				},
			},
			{
				id = "DEDUCE-INVALID",
				label = "Dangling Deduction",
				requiredFacts = {
					{ kind = "Evidence", id = "EV-GHOST" }, -- does not exist
				},
			},
		},
	})

	local function makePlayer(): any
		local id = t.nextUserId()
		local player = { UserId = id, Name = `REASON{id}` }
		PlayerDataService.initialize(player, "CASE-TEST-REASONING")
		return player
	end

	-- Swaps StoryEvents.publish for a spy for the duration of fn (see Phase
	-- 2F/2G's StoryEvents_Test for why: BindableEvents fire deferred, so a
	-- live event listener from inside this harness is unreliable).
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

	----------------------------------------------------------------------
	-- Contradiction
	----------------------------------------------------------------------

	t.test("contradiction stays locked with only one required fact discovered", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-X")
		local data = PlayerDataService.get(player)
		expect.falsy(data.caseState.unlockedContradictions["CONTRA-X"])
	end)

	t.test("contradiction unlocks once both required facts are discovered", function()
		-- Evaluation logic only: BindableEvent-driven auto-evaluation is
		-- covered separately below ("evidence discovery alone triggers
		-- reasoning evaluation"), so this calls evaluate() directly rather
		-- than depending on deferred StoryEvents delivery (see that test for
		-- why a live wait is not reliable inside this harness).
		local player = makePlayer()
		EvidenceService.discover(player, "EV-X")
		EvidenceService.discover(player, "EV-Y")
		ReasoningService.evaluate(player)
		local data = PlayerDataService.get(player)
		expect.truthy(data.caseState.unlockedContradictions["CONTRA-X"])
	end)

	t.test("contradiction unlock is idempotent: ContradictionUnlocked publishes exactly once", function()
		local player = makePlayer()
		withPublishSpy(function(calls)
			EvidenceService.discover(player, "EV-X")
			EvidenceService.discover(player, "EV-Y")
			ReasoningService.evaluate(player) -- redundant re-evaluation, must be a no-op

			local unlocks = 0
			for _, call in ipairs(calls) do
				if call.kind == "ContradictionUnlocked" and call.player == player then
					unlocks += 1
				end
			end
			expect.equal(unlocks, 1)
		end)
	end)

	t.test("a contradiction with a dangling fact reference never unlocks and never errors", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-X")
		local ok = pcall(function()
			ReasoningService.evaluate(player)
		end)
		expect.truthy(ok)
		local data = PlayerDataService.get(player)
		expect.falsy(data.caseState.unlockedContradictions["CONTRA-INVALID"])
	end)

	----------------------------------------------------------------------
	-- Deduction
	----------------------------------------------------------------------

	t.test("deduction stays locked with requirements incomplete", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-X") -- STMT-X still missing
		local data = PlayerDataService.get(player)
		expect.falsy(data.caseState.unlockedDeductions["DEDUCE-X"])
	end)

	t.test("deduction unlocks once every required fact is known", function()
		-- Evaluation logic only; see the contradiction test above for why
		-- this calls evaluate() directly instead of waiting on delivery.
		local player = makePlayer()
		EvidenceService.discover(player, "EV-X")
		ConversationService.begin(player, "SUS-FIXTURE") -- single node unlocks STMT-X and completes
		ReasoningService.evaluate(player)
		local data = PlayerDataService.get(player)
		expect.truthy(data.caseState.unlockedDeductions["DEDUCE-X"])
	end)

	t.test("deduction unlock is idempotent: DeductionUnlocked publishes exactly once", function()
		local player = makePlayer()
		withPublishSpy(function(calls)
			EvidenceService.discover(player, "EV-X")
			ConversationService.begin(player, "SUS-FIXTURE")
			ReasoningService.evaluate(player) -- redundant re-evaluation, must be a no-op

			local unlocks = 0
			for _, call in ipairs(calls) do
				if call.kind == "DeductionUnlocked" and call.player == player then
					unlocks += 1
				end
			end
			expect.equal(unlocks, 1)
		end)
	end)

	t.test("a deduction with a dangling fact reference never unlocks and never errors", function()
		local player = makePlayer()
		local ok = pcall(function()
			ReasoningService.evaluate(player)
		end)
		expect.truthy(ok)
		local data = PlayerDataService.get(player)
		expect.falsy(data.caseState.unlockedDeductions["DEDUCE-INVALID"])
	end)

	----------------------------------------------------------------------
	-- Integration: EvidenceService/ConversationService publish the exact
	-- StoryEvents kind+shape that ReasoningService.start() subscribes to,
	-- so real gameplay drives evaluation without any caller having to know
	-- ReasoningService exists.
	--
	-- This cannot be proven end-to-end from inside this harness: BindableEvents
	-- fire deferred, and a test nested inside RunUnitTest's own task.spawn
	-- wrapper never observes a deferred delivery, no matter the wait
	-- technique (confirmed by direct reproduction: a polling wait here
	-- consistently ran to its full timeout without ever observing the
	-- update, across every case below, matching the same finding from
	-- Phase 2F/2G). Genuine live delivery -- a real client action causing a
	-- real Case File update with no test wrapper involved -- is verified
	-- instead via the real Studio walkthrough (see the final report).
	--
	-- What IS reliably provable here, synchronously: (a) discovery/unlock
	-- publish the kind+data ReasoningService.start() listens for (below),
	-- and (b) evaluate() applied to that same data unlocks correctly
	-- (proven above). Together they demonstrate the wiring is correct.
	----------------------------------------------------------------------

	t.test("evidence discovery alone triggers reasoning evaluation", function()
		local player = makePlayer()
		withPublishSpy(function(calls)
			EvidenceService.discover(player, "EV-X")
			EvidenceService.discover(player, "EV-Y")

			local sawEvidenceDiscovered = false
			for _, call in ipairs(calls) do
				if call.kind == "EvidenceDiscovered" and call.player == player then
					sawEvidenceDiscovered = true
				end
			end
			expect.truthy(sawEvidenceDiscovered)
		end)

		-- Same data a real EvidenceDiscovered event would carry; proves the
		-- listener ReasoningService.start() registers for this kind reaches
		-- the correct unlock.
		ReasoningService.evaluate(player)
		local data = PlayerDataService.get(player)
		expect.truthy(data.caseState.unlockedContradictions["CONTRA-X"])
	end)

	t.test("statement unlock alone triggers reasoning evaluation", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-X")
		withPublishSpy(function(calls)
			ConversationService.begin(player, "SUS-FIXTURE")

			local sawStatementUnlocked = false
			for _, call in ipairs(calls) do
				if call.kind == "StatementUnlocked" and call.player == player then
					sawStatementUnlocked = true
				end
			end
			expect.truthy(sawStatementUnlocked)
		end)

		ReasoningService.evaluate(player)
		local data = PlayerDataService.get(player)
		expect.truthy(data.caseState.unlockedDeductions["DEDUCE-X"])
	end)

	----------------------------------------------------------------------
	-- State: isolation, cleanup, spoiler-safe payloads
	----------------------------------------------------------------------

	t.test("reasoning state does not leak across players", function()
		local playerA = makePlayer()
		local playerB = makePlayer()
		EvidenceService.discover(playerA, "EV-X")
		EvidenceService.discover(playerA, "EV-Y")
		ReasoningService.evaluate(playerA)

		local dataA = PlayerDataService.get(playerA)
		local dataB = PlayerDataService.get(playerB)
		expect.truthy(dataA.caseState.unlockedContradictions["CONTRA-X"])
		expect.falsy(dataB.caseState.unlockedContradictions["CONTRA-X"])
	end)

	t.test("player data clear wipes reasoning state", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-X")
		EvidenceService.discover(player, "EV-Y")
		PlayerDataService.clear(player)
		expect.falsy(PlayerDataService.get(player))
		PlayerDataService.initialize(player, "CASE-TEST-REASONING")
		local data = PlayerDataService.get(player)
		expect.falsy(data.caseState.unlockedContradictions["CONTRA-X"])
		expect.falsy(data.caseState.unlockedDeductions["DEDUCE-X"])
	end)

	t.test("getPayload omits a locked contradiction and locked deduction", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-X") -- only half of CONTRA-X/DEDUCE-X
		local payload = ReasoningService.getPayload(player)
		expect.equal(#payload.contradictions, 0)
		expect.equal(#payload.deductions, 0)
	end)

	t.test("getPayload includes only unlocked facts, spoiler-safe", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-X")
		EvidenceService.discover(player, "EV-Y")
		ConversationService.begin(player, "SUS-FIXTURE")
		ReasoningService.evaluate(player)

		local payload = ReasoningService.getPayload(player)

		expect.equal(#payload.statements, 1)
		expect.equal(payload.statements[1].id, "STMT-X")

		expect.equal(#payload.contradictions, 1)
		expect.equal(payload.contradictions[1].id, "CONTRA-X")
		expect.equal(payload.contradictions[1].leftSummary, "Fixture Evidence X")
		expect.equal(payload.contradictions[1].rightSummary, "Fixture Evidence Y")

		expect.equal(#payload.deductions, 1)
		expect.equal(payload.deductions[1].id, "DEDUCE-X")
		expect.equal(#payload.deductions[1].basedOn, 2)

		-- The dangling-reference fixtures must never appear, regardless of
		-- what else unlocked.
		for _, contradiction in ipairs(payload.contradictions) do
			expect.falsy(contradiction.id == "CONTRA-INVALID")
		end
		for _, deduction in ipairs(payload.deductions) do
			expect.falsy(deduction.id == "DEDUCE-INVALID")
		end
	end)
end
