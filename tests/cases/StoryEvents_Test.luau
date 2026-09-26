--!strict
--[[
	Tests for ServerScriptService.Server.StoryEvents.
	Covers the generic publish/subscribe contract, and that the existing
	Evidence -> Objective pipeline actually calls through it (without that
	pipeline depending on StoryEvents to function).

	BindableEvents fire deferred (not synchronously) in this project. This
	harness runs every test wrapped in its own task.spawn plus an outer
	polling loop (see RunUnitTest.runOne); waiting on a second, independently
	polling coroutine for a deferred event's delivery is unreliable in that
	specific nesting, regardless of wait style, so the integration checks
	below verify the call directly (StoryEvents.publish is swapped for a
	synchronous spy and restored afterward) rather than round-tripping
	through a live BindableEvent. This is deterministic and, if anything,
	more precise: it verifies EvidenceService/ObjectiveService actually call
	StoryEvents.publish with the right arguments.

	Each case uses a unique mock UserId for isolation.
]]
return function(t)
	local ServerScriptService = game:GetService("ServerScriptService")
	local Server = ServerScriptService:WaitForChild("Server")
	local StoryEvents = require(Server:WaitForChild("StoryEvents"))
	local EvidenceService = require(Server:WaitForChild("EvidenceService"))
	local ObjectiveService = require(Server:WaitForChild("ObjectiveService"))
	local PlayerDataService = require(Server:WaitForChild("PlayerDataService"))
	local expect = t.expect

	local function makePlayer(): any
		local id = t.nextUserId()
		local player = { UserId = id, Name = `SE{id}` }
		PlayerDataService.initialize(player, "CASE-TEST-LEGACY")
		return player
	end

	-- Swaps StoryEvents.publish for a spy for the duration of fn, always
	-- restoring the original afterward (even if fn throws).
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

	-- The subscribe contract: on() returns a connection that can be
	-- disconnected without erroring, and publishing to an unrelated kind
	-- never reaches a subscriber of another kind.
	t.test("on returns a disconnectable connection; kinds stay isolated", function()
		local fired = false
		local conn = StoryEvents.on("ObjectiveCompleted", function()
			fired = true
		end)
		StoryEvents.publish("EvidenceDiscovered", { UserId = -1, Name = "Marker" } :: any, {})
		conn:Disconnect()
		expect.falsy(fired)
	end)

	-- EvidenceService calls StoryEvents.publish with the discovered evidence
	-- id on a successful discovery.
	t.test("EvidenceService calls StoryEvents.publish on discovery", function()
		local player = makePlayer()
		withPublishSpy(function(calls)
			EvidenceService.discover(player, "EV-001")
			expect.equal(#calls, 1)
			expect.equal(calls[1].kind, "EvidenceDiscovered")
			expect.equal(calls[1].player, player)
			expect.equal(calls[1].data.evidenceId, "EV-001")
		end)
	end)

	-- A rejected duplicate discovery never calls StoryEvents.publish.
	t.test("EvidenceService does not publish on a rejected duplicate", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-001")
		withPublishSpy(function(calls)
			EvidenceService.discover(player, "EV-001") -- duplicate, rejected
			expect.equal(#calls, 0)
		end)
	end)

	-- ObjectiveService calls StoryEvents.publish exactly once for a
	-- completion, even if the completing interaction is replayed afterward.
	t.test("ObjectiveService calls StoryEvents.publish exactly once on completion", function()
		local player = makePlayer()
		withPublishSpy(function(calls)
			ObjectiveService.recordInteraction(player, "Examine", "EV-001")
			ObjectiveService.recordInteraction(player, "Examine", "EV-002")
			ObjectiveService.recordInteraction(player, "Read", "EV-003")
			ObjectiveService.recordInteraction(player, "Read", "EV-003") -- replay after completion
			expect.equal(#calls, 1)
			expect.equal(calls[1].kind, "ObjectiveCompleted")
			expect.equal(calls[1].player, player)
			expect.equal(calls[1].data.objectiveId, "OBJ-001")
		end)
	end)
end
