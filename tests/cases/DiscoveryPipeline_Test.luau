--!strict
--[[
	Integration tests for the authoritative discovery pipeline:
	    evidence -> timeline -> objective
	Verifies the systems agree end-to-end for a single player, and that a
	repeat discovery produces no extra evidence, timeline or objective change.
]]
return function(t)
	local ServerScriptService = game:GetService("ServerScriptService")
	local Server = ServerScriptService:WaitForChild("Server")
	local EvidenceService = require(Server:WaitForChild("EvidenceService"))
	local TimelineService = require(Server:WaitForChild("TimelineService"))
	local ObjectiveService = require(Server:WaitForChild("ObjectiveService"))
	local PlayerDataService = require(Server:WaitForChild("PlayerDataService"))
	local expect = t.expect

	local nextUserId = 950000
	local function makePlayer(): any
		nextUserId += 1
		local player = { UserId = nextUserId, Name = `PIPE{nextUserId}` }
		PlayerDataService.initialize(player, "CASE-001")
		return player
	end

	-- Discovering all three clues reveals all three timeline events in order.
	t.test("full case reveals three timeline events in order", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-001")
		EvidenceService.discover(player, "EV-002")
		EvidenceService.discover(player, "EV-003")
		local events = TimelineService.getDiscovered(player)
		expect.equal(#events, 3)
		expect.equal(events[1].timestamp, "11:42 PM")
		expect.equal(events[2].timestamp, "11:47 PM")
		expect.equal(events[3].timestamp, "12:00 AM")
	end)

	-- The full examine/read sequence completes OBJ-001.
	t.test("full interaction sequence completes OBJ-001", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-001")
		ObjectiveService.recordInteraction(player, "Examine", "EV-001")
		EvidenceService.discover(player, "EV-002")
		ObjectiveService.recordInteraction(player, "Examine", "EV-002")
		EvidenceService.discover(player, "EV-003")
		ObjectiveService.recordInteraction(player, "Read", "EV-003")
		local data = PlayerDataService.get(player)
		expect.truthy(data and data.caseState.completedObjectives["OBJ-001"])
	end)

	-- Each discovery reveals exactly one timeline event.
	t.test("each discovery reveals exactly one event", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-001")
		expect.equal(#TimelineService.getDiscovered(player), 1)
		EvidenceService.discover(player, "EV-002")
		expect.equal(#TimelineService.getDiscovered(player), 2)
		EvidenceService.discover(player, "EV-003")
		expect.equal(#TimelineService.getDiscovered(player), 3)
	end)

	-- Repeating the whole discovery sequence changes nothing further.
	t.test("repeat discovery is a full no-op", function()
		local player = makePlayer()
		for _ = 1, 2 do
			EvidenceService.discover(player, "EV-001")
			EvidenceService.discover(player, "EV-002")
			EvidenceService.discover(player, "EV-003")
			ObjectiveService.recordInteraction(player, "Examine", "EV-001")
			ObjectiveService.recordInteraction(player, "Examine", "EV-002")
			ObjectiveService.recordInteraction(player, "Read", "EV-003")
		end
		local state = EvidenceService.getState(player)
		local discoveredCount = 0
		for _ in pairs(state) do
			discoveredCount += 1
		end
		expect.equal(discoveredCount, 3)
		expect.equal(#TimelineService.getDiscovered(player), 3)
	end)
end
