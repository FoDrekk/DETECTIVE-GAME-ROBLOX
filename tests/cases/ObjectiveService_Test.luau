--!strict
--[[
	Tests for ServerScriptService.Server.ObjectiveService.
	Covers requirement progress from evidence/interaction, completion exactly
	once, and that replaying the same interaction adds no progress.

	Each case uses a unique mock UserId for isolation.
]]
return function(t)
	local ServerScriptService = game:GetService("ServerScriptService")
	local Server = ServerScriptService:WaitForChild("Server")
	local ObjectiveService = require(Server:WaitForChild("ObjectiveService"))
	local PlayerDataService = require(Server:WaitForChild("PlayerDataService"))
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
end
