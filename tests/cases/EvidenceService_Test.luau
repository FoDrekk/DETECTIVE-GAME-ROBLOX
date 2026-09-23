--!strict
--[[
	Tests for ServerScriptService.Server.EvidenceService.
	Covers discovery, duplicate rejection, unknown id rejection, and the
	client-facing payload shape (no hidden data leaked).

	The services key per-player state by UserId, so each case uses a unique
	mock UserId to stay isolated without touching production code.
]]
return function(t)
	local ServerScriptService = game:GetService("ServerScriptService")
	local Server = ServerScriptService:WaitForChild("Server")
	local EvidenceService = require(Server:WaitForChild("EvidenceService"))
	local PlayerDataService = require(Server:WaitForChild("PlayerDataService"))
	local expect = t.expect

	local function makePlayer(): any
		local id = t.nextUserId()
		local player = { UserId = id, Name = `Test{id}` }
		PlayerDataService.initialize(player, "CASE-001")
		return player
	end

	-- First discovery of known evidence succeeds.
	t.test("discovers known evidence", function()
		local player = makePlayer()
		local ok = EvidenceService.discover(player, "EV-001")
		expect.truthy(ok)
	end)

	-- A discovered id is recorded as discovered.
	t.test("records the discovery", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-001")
		expect.truthy(EvidenceService.isDiscovered(player, "EV-001"))
	end)

	-- Re-discovering the same id is rejected.
	t.test("rejects a duplicate discovery", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-001")
		local ok, reason = EvidenceService.discover(player, "EV-001")
		expect.falsy(ok)
		expect.equal(reason, "already-discovered")
	end)

	-- An unknown evidence id is rejected without recording anything.
	t.test("rejects an unknown evidence id", function()
		local player = makePlayer()
		local ok, reason = EvidenceService.discover(player, "EV-999")
		expect.falsy(ok)
		expect.equal(reason, "unknown-evidence")
		expect.falsy(EvidenceService.isDiscovered(player, "EV-999"))
	end)

	-- A player without initialised data is rejected.
	t.test("rejects a player with no data", function()
		local stranger = { UserId = 999999999, Name = "Stranger" }
		local ok, reason = EvidenceService.discover(stranger, "EV-001")
		expect.falsy(ok)
		expect.equal(reason, "no-player-data")
	end)

	-- Discovered evidence carries the authored case fields.
	t.test("carries authored fields into discovered state", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-001")
		local state = EvidenceService.getState(player)
		local ev = state["EV-001"]
		expect.truthy(ev)
		expect.equal(ev.name, "Phone")
		expect.equal(ev.location, "Daniel's Workspace")
		expect.equal(ev.timestamp, "11:47 PM")
		expect.equal(ev.discovered, true)
	end)

	-- getState only ever contains discovered evidence.
	t.test("state contains only discovered evidence", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-002")
		local state = EvidenceService.getState(player)
		expect.truthy(state["EV-002"])
		expect.falsy(state["EV-001"])
		expect.falsy(state["EV-003"])
	end)

	-- Phase 2I: EV-004 (the keycard log) discovers through the same generic
	-- pipeline as EV-001/002/003, with no special-casing anywhere.
	t.test("discovers the keycard log (EV-004)", function()
		local player = makePlayer()
		local ok = EvidenceService.discover(player, "EV-004")
		expect.truthy(ok)
		local state = EvidenceService.getState(player)
		expect.truthy(state["EV-004"])
		expect.equal(state["EV-004"].name, "Keycard Log")
	end)

	-- Duplicate discovery of EV-004 remains safe, same as any other evidence.
	t.test("rejects a duplicate discovery of EV-004", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-004")
		local ok, reason = EvidenceService.discover(player, "EV-004")
		expect.falsy(ok)
		expect.equal(reason, "already-discovered")
	end)
end
