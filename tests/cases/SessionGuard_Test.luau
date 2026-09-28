--!strict
--[[
	Tests for ServerScriptService.Server.SessionGuard (Phase 3, R2): one
	investigator per server, since the session's phase machine is server-wide.
]]
return function(t)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Server = game:GetService("ServerScriptService"):WaitForChild("Server")
	local SessionGuard = require(Server:WaitForChild("SessionGuard"))
	local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
	local expect = t.expect

	t.test("the game is configured for a single investigator", function()
		expect.equal(Config.Game.MaxInvestigators, 1)
		expect.truthy(#Config.Game.FullServerMessage > 0)
	end)

	t.test("admits the first investigator and turns a second away", function()
		local guard = SessionGuard.new(1)
		expect.equal(guard:admit(101), "Admitted")
		expect.equal(guard:admit(202), "Full")
	end)

	-- PlayerAdded and the startup sweep can both report the same player; the
	-- second report must be ignored, not treated as a second investigator.
	t.test("a repeated report of the same investigator is a duplicate", function()
		local guard = SessionGuard.new(1)
		expect.equal(guard:admit(101), "Admitted")
		expect.equal(guard:admit(101), "Duplicate")
	end)

	t.test("the seat frees when the investigator leaves", function()
		local guard = SessionGuard.new(1)
		guard:admit(101)
		guard:release(101)
		expect.equal(guard:admit(202), "Admitted")
	end)

	-- A player who was turned away never held the seat; their leaving must not
	-- free the seat the real investigator still holds.
	t.test("a turned-away player leaving does not free the seat", function()
		local guard = SessionGuard.new(1)
		guard:admit(101)
		expect.equal(guard:admit(202), "Full")
		guard:release(202)
		expect.equal(guard:admit(303), "Full")
	end)
end
