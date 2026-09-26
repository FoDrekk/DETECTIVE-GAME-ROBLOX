--!strict
--[[
	Tests for service failure handling and observability.
	Verifies that recoverable failures are reported through their reason codes
	(observable contract) rather than silently swallowed or thrown.
]]
return function(t)
	local ServerScriptService = game:GetService("ServerScriptService")
	local Server = ServerScriptService:WaitForChild("Server")
	local EvidenceService = require(Server:WaitForChild("EvidenceService"))
	local PlayerDataService = require(Server:WaitForChild("PlayerDataService"))
	local expect = t.expect

	local function makePlayer(): any
		local id = t.nextUserId()
		local player = { UserId = id, Name = `LOG{id}` }
		PlayerDataService.initialize(player, "CASE-TEST-LEGACY")
		return player
	end

	-- Unknown evidence is a recoverable failure: no throw, explicit reason.
	t.test("unknown evidence returns a reason, not an error", function()
		local player = makePlayer()
		local ok, reason = EvidenceService.discover(player, "EV-UNKNOWN")
		expect.falsy(ok)
		expect.equal(reason, "unknown-evidence")
	end)

	-- A player without data is a recoverable failure with an explicit reason.
	t.test("missing player data returns a reason, not an error", function()
		local stranger = { UserId = 888888888, Name = "NoData" }
		local ok, reason = EvidenceService.discover(stranger, "EV-001")
		expect.falsy(ok)
		expect.equal(reason, "no-player-data")
	end)

	-- require() on an uninitialised player fails loudly (fatal contract).
	t.test("require on missing data fails loudly", function()
		local stranger = { UserId = 888888889, Name = "NoData2" }
		expect.throws(function()
			PlayerDataService.require(stranger)
		end)
	end)

	-- get() on an uninitialised player is a safe nil (non-fatal contract).
	t.test("get on missing data returns nil", function()
		local stranger = { UserId = 888888890, Name = "NoData3" }
		expect.falsy(PlayerDataService.get(stranger))
	end)
end
