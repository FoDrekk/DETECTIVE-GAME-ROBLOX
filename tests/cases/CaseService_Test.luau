--!strict
--[[
	Tests for ServerScriptService.Server.CaseService.
	Covers case/suspect/location access (Phase 2F) and the spoiler-safe
	client payload.

	Each case uses a unique mock UserId for isolation.
]]
return function(t)
	local ServerScriptService = game:GetService("ServerScriptService")
	local Server = ServerScriptService:WaitForChild("Server")
	local CaseService = require(Server:WaitForChild("CaseService"))
	local PlayerDataService = require(Server:WaitForChild("PlayerDataService"))
	local expect = t.expect

	local function makePlayer(): any
		local id = t.nextUserId()
		local player = { UserId = id, Name = `CASE{id}` }
		PlayerDataService.initialize(player, "CASE-001")
		return player
	end

	t.test("getCase resolves a registered case by id", function()
		local caseDef = CaseService.getCase("CASE-001")
		expect.truthy(caseDef)
		expect.equal(caseDef and caseDef.id, "CASE-001")
	end)

	t.test("getCase returns nil for an unknown case id", function()
		expect.falsy(CaseService.getCase("CASE-999"))
	end)

	t.test("getActiveCase resolves the player's current case", function()
		local player = makePlayer()
		local caseDef = CaseService.getActiveCase(player)
		expect.truthy(caseDef)
		expect.equal(caseDef and caseDef.id, "CASE-001")
	end)

	-- Suspect access (Phase 2F). Case001's authored suspects must be
	-- returned unchanged -- no invented content, no second schema.
	t.test("getSuspects returns Case001's authored suspects unchanged", function()
		local suspects = CaseService.getSuspects("CASE-001")
		expect.equal(#suspects, 2)
		local byId = {}
		for _, suspect in ipairs(suspects) do
			byId[suspect.id] = suspect
		end
		expect.truthy(byId["SUS-001"])
		expect.equal(byId["SUS-001"].name, "Mara Reyes")
		expect.truthy(byId["SUS-002"])
		expect.equal(byId["SUS-002"].name, "Victor Lane")
	end)

	t.test("getSuspect resolves a single suspect by id", function()
		local suspect = CaseService.getSuspect("CASE-001", "SUS-001")
		expect.truthy(suspect)
		expect.equal(suspect and suspect.role, "Spouse")
	end)

	t.test("getSuspect returns nil for an unknown suspect id", function()
		expect.falsy(CaseService.getSuspect("CASE-001", "SUS-999"))
	end)

	-- Location access (Phase 2F).
	t.test("getLocations returns Case001's authored locations unchanged", function()
		local locations = CaseService.getLocations("CASE-001")
		expect.equal(#locations, 1)
		expect.equal(locations[1].id, "LOC-001")
	end)

	t.test("getLocation resolves a single location by id", function()
		local location = CaseService.getLocation("CASE-001", "LOC-001")
		expect.truthy(location)
		expect.equal(location and location.name, "Office")
	end)

	t.test("getLocation returns nil for an unknown location id", function()
		expect.falsy(CaseService.getLocation("CASE-001", "LOC-999"))
	end)

	-- Accessors fail safe (empty, not error) for an unregistered case id, and
	-- never hardcode "CASE-001" internally.
	t.test("suspect/location accessors return empty for an unknown case", function()
		expect.equal(#CaseService.getSuspects("CASE-999"), 0)
		expect.equal(#CaseService.getLocations("CASE-999"), 0)
	end)

	-- Spoiler safety: the client payload must never carry evidence,
	-- timeline, objective, suspect or location facts -- only the briefing.
	t.test("buildClientPayload exposes only spoiler-safe briefing fields", function()
		local player = makePlayer()
		local payload = CaseService.buildClientPayload(player)
		expect.truthy(payload)
		expect.truthy(payload.briefing)
		expect.equal(payload.briefing.id, "CASE-001")
		expect.equal(payload.briefing.title, "THE LAST CALL")
		expect.falsy((payload :: any).evidence)
		expect.falsy((payload :: any).timeline)
		expect.falsy((payload :: any).suspects)
		expect.falsy((payload :: any).locations)
		expect.falsy((payload :: any).objectives)
	end)
end
