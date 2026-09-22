--!strict
--[[
	Tests for ReplicatedStorage.Config.CaseRegistry.
	Covers loading, lookup by id, and lookup of an unknown id.
]]
return function(t)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local CaseRegistry = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CaseRegistry"))
	local expect = t.expect

	-- The registry loads the authored CASE-001 definition.
	t.test("loads an authored case by id", function()
		local caseDef = CaseRegistry.get("CASE-001")
		expect.truthy(caseDef)
		expect.equal(caseDef and caseDef.id, "CASE-001")
	end)

	-- getAll returns a non-empty map keyed by case id.
	t.test("returns all cases keyed by id", function()
		local all = CaseRegistry.getAll()
		expect.truthy(all["CASE-001"])
		expect.equal(all["CASE-001"].id, "CASE-001")
	end)

	-- An unknown id resolves to nil rather than erroring.
	t.test("returns nil for an unknown case id", function()
		expect.falsy(CaseRegistry.get("CASE-999"))
	end)

	-- CASE-001 declares the canonical evidence ids.
	t.test("declares the canonical evidence ids", function()
		local caseDef = CaseRegistry.get("CASE-001")
		local ids = {}
		for _, ev in ipairs(caseDef.evidence) do
			ids[ev.id] = true
		end
		expect.truthy(ids["EV-001"])
		expect.truthy(ids["EV-002"])
		expect.truthy(ids["EV-003"])
	end)

	-- Every timeline event references evidence that exists in the same case.
	t.test("timeline sources reference declared evidence", function()
		local caseDef = CaseRegistry.get("CASE-001")
		local evidenceIds = {}
		for _, ev in ipairs(caseDef.evidence) do
			evidenceIds[ev.id] = true
		end
		for _, event in ipairs(caseDef.timeline) do
			for _, sourceId in ipairs(event.sourceEvidenceIds) do
				expect.truthy(evidenceIds[sourceId])
			end
		end
	end)

	-- Every evidence item that names a timeline event references a real event.
	t.test("evidence timeline references resolve", function()
		local caseDef = CaseRegistry.get("CASE-001")
		local eventIds = {}
		for _, event in ipairs(caseDef.timeline) do
			eventIds[event.id] = true
		end
		for _, ev in ipairs(caseDef.evidence) do
			if ev.timelineEventId then
				expect.truthy(eventIds[ev.timelineEventId])
			end
		end
	end)
end
