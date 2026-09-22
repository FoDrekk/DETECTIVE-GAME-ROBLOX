--!strict
--[[
	Tests for ServerScriptService.Server.ObjectiveService.
	Covers requirement progress from evidence/interaction, completion exactly
	once, that replaying the same interaction adds no progress, and (Phase
	2F) data-driven multi-objective sequencing via `prerequisites` and the
	`target` requirement gate.

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
	local CaseRegistry = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CaseRegistry"))
	local expect = t.expect

	local nextUserId = 920000
	local function makePlayer(): any
		nextUserId += 1
		local player = { UserId = nextUserId, Name = `OBJ{nextUserId}` }
		PlayerDataService.initialize(player, "CASE-001")
		return player
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

	-- CASE-001 still has exactly one objective with no prerequisites, so it
	-- must remain the active objective from the start (Phase 2E behavior,
	-- now derived from the data-driven active-objective lookup instead of a
	-- hardcoded objectives[1]).
	t.test("OBJ-001 remains active with no prerequisites (regression)", function()
		local player = makePlayer()
		expect.equal(ObjectiveService.getActiveObjectiveId(player), "OBJ-001")
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
		},
	})

	local function makeSeqPlayer(): any
		nextUserId += 1
		local player = { UserId = nextUserId, Name = `SEQ{nextUserId}` }
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
end
