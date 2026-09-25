--!strict
--[[
	Tests for ServerScriptService.Server.TimelineService.
	Covers hidden-until-discovered behavior, reveal from source evidence, the
	M5 reconstruction mechanic (challenge order, validation, permanence,
	spoiler safety) and canonical chronological ordering once established.

	Each case uses a unique mock UserId for isolation.
]]
return function(t)
	local ServerScriptService = game:GetService("ServerScriptService")
	local Server = ServerScriptService:WaitForChild("Server")
	local TimelineService = require(Server:WaitForChild("TimelineService"))
	local EvidenceService = require(Server:WaitForChild("EvidenceService"))
	local PlayerDataService = require(Server:WaitForChild("PlayerDataService"))
	local expect = t.expect

	local function makePlayer(): any
		local id = t.nextUserId()
		local player = { UserId = id, Name = `TL{id}` }
		PlayerDataService.initialize(player, "CASE-001")
		return player
	end

	-- Discovers all four evidence items (so all four events are revealed).
	local function discoverAll(player: any)
		EvidenceService.discover(player, "EV-001")
		EvidenceService.discover(player, "EV-002")
		EvidenceService.discover(player, "EV-003")
		EvidenceService.discover(player, "EV-004")
	end

	local CANONICAL = { "TIMELINE-001", "TIMELINE-002", "TIMELINE-004", "TIMELINE-003" }

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

	-- M2: the keycard log (EV-004) reveals Victor's 11:52 PM exit.
	t.test("reveals EV-004's timeline event", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-004")
		local events = TimelineService.getDiscovered(player)
		expect.equal(#events, 1)
		expect.equal(events[1].id, "TIMELINE-004")
		expect.equal(events[1].timestamp, "11:52 PM")
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

	------------------------------------------------------------------
	-- M5: reconstruction mechanic
	------------------------------------------------------------------

	-- Before reconstruction, events are delivered in the authored challenge
	-- order, which is deliberately NOT chronological.
	t.test("presents events in the authored challenge order until established", function()
		local player = makePlayer()
		discoverAll(player)
		expect.falsy(TimelineService.isEstablished(player))
		local events = TimelineService.getDiscovered(player)
		expect.equal(#events, 4)
		expect.deepEqual(
			{ events[1].id, events[2].id, events[3].id, events[4].id },
			{ "TIMELINE-004", "TIMELINE-001", "TIMELINE-003", "TIMELINE-002" }
		)
	end)

	-- Once established, the server sends canonical chronological order.
	t.test("presents canonical chronological order once established", function()
		local player = makePlayer()
		discoverAll(player)
		expect.truthy(TimelineService.submitSequence(player, CANONICAL))
		expect.truthy(TimelineService.isEstablished(player))
		local events = TimelineService.getDiscovered(player)
		expect.deepEqual(
			{ events[1].id, events[2].id, events[3].id, events[4].id },
			CANONICAL
		)
		expect.equal(events[1].timestamp, "11:42 PM")
		expect.equal(events[4].timestamp, "12:00 AM")
	end)

	-- A wrong order is rejected and does not establish anything.
	t.test("rejects an incorrect order", function()
		local player = makePlayer()
		discoverAll(player)
		-- Swap the last two of the canonical order -> wrong.
		local wrong = { "TIMELINE-001", "TIMELINE-002", "TIMELINE-003", "TIMELINE-004" }
		expect.falsy(TimelineService.submitSequence(player, wrong))
		expect.falsy(TimelineService.isEstablished(player))
	end)

	-- A submission that omits, duplicates, or invents an event is rejected.
	t.test("rejects incomplete, duplicated or unknown submissions", function()
		local player = makePlayer()
		discoverAll(player)
		expect.falsy(TimelineService.submitSequence(player, { "TIMELINE-001", "TIMELINE-002", "TIMELINE-004" }))
		expect.falsy(TimelineService.submitSequence(player, { "TIMELINE-001", "TIMELINE-001", "TIMELINE-004", "TIMELINE-003" }))
		expect.falsy(TimelineService.submitSequence(player, { "TIMELINE-001", "TIMELINE-002", "TIMELINE-004", "TIMELINE-999" }))
		expect.falsy(TimelineService.isEstablished(player))
	end)

	-- The submission can only contain events the player has actually discovered.
	t.test("rejects an order containing an undiscovered event", function()
		local player = makePlayer()
		-- Only three discovered; the fourth is still hidden.
		EvidenceService.discover(player, "EV-001")
		EvidenceService.discover(player, "EV-002")
		EvidenceService.discover(player, "EV-004")
		expect.falsy(TimelineService.submitSequence(player, CANONICAL))
		expect.falsy(TimelineService.isEstablished(player))
	end)

	-- An empty or malformed submission is rejected.
	t.test("rejects an empty or malformed submission", function()
		local player = makePlayer()
		discoverAll(player)
		expect.falsy(TimelineService.submitSequence(player, {}))
		expect.falsy(TimelineService.submitSequence(player, nil :: any))
		expect.falsy(TimelineService.isEstablished(player))
	end)

	-- Establishing is permanent and idempotent: a second call is a safe no-op.
	t.test("establishing the timeline is permanent and idempotent", function()
		local player = makePlayer()
		discoverAll(player)
		expect.truthy(TimelineService.submitSequence(player, CANONICAL))
		expect.falsy(TimelineService.submitSequence(player, CANONICAL))
		expect.truthy(TimelineService.isEstablished(player))
	end)

	-- A partially-discovered timeline can still be established correctly.
	t.test("a partially discovered timeline can be established", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-002") -- 11:42
		EvidenceService.discover(player, "EV-001") -- 11:47
		expect.truthy(TimelineService.submitSequence(player, { "TIMELINE-001", "TIMELINE-002" }))
		expect.truthy(TimelineService.isEstablished(player))
	end)

	-- State is per-player: one player establishing does not establish another.
	t.test("timeline state does not leak across players", function()
		local playerA = makePlayer()
		local playerB = makePlayer()
		discoverAll(playerA)
		discoverAll(playerB)
		expect.truthy(TimelineService.submitSequence(playerA, CANONICAL))
		expect.truthy(TimelineService.isEstablished(playerA))
		expect.falsy(TimelineService.isEstablished(playerB))
	end)

	-- Player data clear wipes the established flag.
	t.test("player data clear wipes the established timeline", function()
		local player = makePlayer()
		discoverAll(player)
		expect.truthy(TimelineService.submitSequence(player, CANONICAL))
		PlayerDataService.clear(player)
		expect.falsy(TimelineService.isEstablished(player))
	end)

	-- A data-less player can never be established.
	t.test("a player with no case data cannot establish a timeline", function()
		local stranger = { UserId = t.nextUserId(), Name = "TLStranger" }
		expect.falsy(TimelineService.submitSequence(stranger, CANONICAL))
		expect.falsy(TimelineService.isEstablished(stranger))
	end)
end
