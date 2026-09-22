--!strict
--[[
	Tests for ServerScriptService.Server.TimelineService.
	Covers hidden-until-discovered behavior, reveal from source evidence,
	chronological ordering, and exactly-once reveal.

	Each case uses a unique mock UserId for isolation.
]]
return function(t)
	local ServerScriptService = game:GetService("ServerScriptService")
	local Server = ServerScriptService:WaitForChild("Server")
	local TimelineService = require(Server:WaitForChild("TimelineService"))
	local EvidenceService = require(Server:WaitForChild("EvidenceService"))
	local PlayerDataService = require(Server:WaitForChild("PlayerDataService"))
	local expect = t.expect

	local nextUserId = 910000
	local function makePlayer(): any
		nextUserId += 1
		local player = { UserId = nextUserId, Name = `TL{nextUserId}` }
		PlayerDataService.initialize(player, "CASE-001")
		return player
	end

	-- A fresh player has no discovered timeline events.
	t.test("starts empty for a fresh player", function()
		local player = makePlayer()
		expect.equal(#TimelineService.getDiscovered(player), 0)
	end)

	-- Discovering EV-002 reveals TIMELINE-001 (11:42 PM).
	t.test("reveals the event sourced from discovered evidence", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-002")
		local events = TimelineService.getDiscovered(player)
		expect.equal(#events, 1)
		expect.equal(events[1].id, "TIMELINE-001")
		expect.equal(events[1].timestamp, "11:42 PM")
	end)

	-- EV-001 reveals TIMELINE-002 (11:47 PM).
	t.test("reveals EV-001's timeline event", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-001")
		local events = TimelineService.getDiscovered(player)
		expect.equal(#events, 1)
		expect.equal(events[1].id, "TIMELINE-002")
		expect.equal(events[1].timestamp, "11:47 PM")
	end)

	-- EV-003 reveals TIMELINE-003 (12:00 AM).
	t.test("reveals EV-003's timeline event", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-003")
		local events = TimelineService.getDiscovered(player)
		expect.equal(#events, 1)
		expect.equal(events[1].id, "TIMELINE-003")
		expect.equal(events[1].timestamp, "12:00 AM")
	end)

	-- Events are ordered chronologically regardless of discovery order.
	t.test("orders events chronologically by time", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-001") -- 11:47 PM
		EvidenceService.discover(player, "EV-003") -- 12:00 AM
		EvidenceService.discover(player, "EV-002") -- 11:42 PM
		local events = TimelineService.getDiscovered(player)
		expect.equal(#events, 3)
		expect.equal(events[1].timestamp, "11:42 PM")
		expect.equal(events[2].timestamp, "11:47 PM")
		expect.equal(events[3].timestamp, "12:00 AM")
	end)

	-- Re-discovering the same evidence does not duplicate the event.
	t.test("does not duplicate a revealed event", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-001")
		EvidenceService.discover(player, "EV-001")
		expect.equal(#TimelineService.getDiscovered(player), 1)
	end)

	-- An undiscovered evidence's event stays hidden.
	t.test("keeps undiscovered events hidden", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-001")
		local events = TimelineService.getDiscovered(player)
		for _, event in ipairs(events) do
			expect.falsy(event.id == "TIMELINE-001")
		end
	end)

	-- Revealed events expose only discovered source names, never hidden ones.
	t.test("sources reference discovered evidence names", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-002")
		local events = TimelineService.getDiscovered(player)
		expect.deepEqual(events[1].sources, { "Laptop" })
	end)
end
