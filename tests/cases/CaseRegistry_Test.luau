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

	-- register() adds a case directly, without a Config file, and does not
	-- disturb the file-backed CASE-001.
	t.test("register adds a case without a Config file", function()
		CaseRegistry.register({
			id = "CASE-REGISTRY-TEST",
			title = "Registry Test",
			description = "",
			suspects = {},
			locations = {},
			evidence = {},
			timeline = {},
			objectives = {},
			conversations = {},
			statements = {},
		})
		expect.truthy(CaseRegistry.get("CASE-REGISTRY-TEST"))
		expect.truthy(CaseRegistry.get("CASE-001"))
	end)

	-- Phase 2G audit: exactly one suspect is a playable NPC this phase.
	t.test("only SUS-001 has an npcPlacement", function()
		local caseDef = CaseRegistry.get("CASE-001")
		local byId = {}
		for _, suspect in ipairs(caseDef.suspects) do
			byId[suspect.id] = suspect
		end
		expect.truthy(byId["SUS-001"].npcPlacement)
		expect.falsy(byId["SUS-002"].npcPlacement)
	end)

	-- CASE-001 declares exactly the one conversation/statement Phase 2G ships.
	t.test("declares SUS-001's conversation and statement", function()
		local caseDef = CaseRegistry.get("CASE-001")
		expect.equal(#caseDef.conversations, 1)
		expect.equal(caseDef.conversations[1].suspectId, "SUS-001")
		expect.equal(#caseDef.statements, 1)
		expect.equal(caseDef.statements[1].id, "STMT-SUS-001-ALIBI")
		expect.equal(caseDef.statements[1].suspectId, "SUS-001")
	end)
end
