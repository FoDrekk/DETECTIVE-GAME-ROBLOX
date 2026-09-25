--!strict
--[[
	Tests for ServerStorage.Config.CaseRegistry.
	Covers loading, lookup by id, and lookup of an unknown id.
]]
return function(t)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local CaseRegistry = require(game:GetService("ServerStorage"):WaitForChild("Config"):WaitForChild("CaseRegistry"))
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
		expect.truthy(ids["EV-004"])
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

	-- Phase 2I: both suspects are playable NPCs as of this phase.
	t.test("both suspects have an npcPlacement", function()
		local caseDef = CaseRegistry.get("CASE-001")
		local byId = {}
		for _, suspect in ipairs(caseDef.suspects) do
			byId[suspect.id] = suspect
		end
		expect.truthy(byId["SUS-001"].npcPlacement)
		expect.truthy(byId["SUS-002"].npcPlacement)
	end)

	-- CASE-001 declares one conversation/statement per playable suspect.
	t.test("declares both suspects' conversations and statements", function()
		local caseDef = CaseRegistry.get("CASE-001")
		expect.equal(#caseDef.conversations, 2)
		local suspectIds = {}
		for _, conversation in ipairs(caseDef.conversations) do
			suspectIds[conversation.suspectId] = true
		end
		expect.truthy(suspectIds["SUS-001"])
		expect.truthy(suspectIds["SUS-002"])

		expect.equal(#caseDef.statements, 2)
		local statementIds = {}
		for _, statement in ipairs(caseDef.statements) do
			statementIds[statement.id] = statement
		end
		expect.truthy(statementIds["STMT-SUS-001-ALIBI"])
		expect.equal(statementIds["STMT-SUS-001-ALIBI"].suspectId, "SUS-001")
		expect.truthy(statementIds["STMT-SUS-002-ALIBI"])
		expect.equal(statementIds["STMT-SUS-002-ALIBI"].suspectId, "SUS-002")
	end)

	-- Phase 2I: CASE-001 declares exactly one contradiction, referencing real
	-- facts by id rather than duplicating their content.
	t.test("declares exactly one contradiction, referencing real facts", function()
		local caseDef = CaseRegistry.get("CASE-001")
		expect.equal(#caseDef.contradictions, 1)
		local contradiction = caseDef.contradictions[1]
		expect.equal(contradiction.id, "CONTRA-001")
		expect.equal(contradiction.left.kind, "Statement")
		expect.equal(contradiction.left.id, "STMT-SUS-002-ALIBI")
		expect.equal(contradiction.right.kind, "Evidence")
		expect.equal(contradiction.right.id, "EV-004")
	end)

	-- CASE-001 declares two deductions (opportunity via DEDUCT-001, motive via
	-- DEDUCT-002), referencing real facts by id.
	t.test("declares its deductions, referencing real facts", function()
		local caseDef = CaseRegistry.get("CASE-001")
		expect.equal(#caseDef.deductions, 2)
		local deduction = caseDef.deductions[1]
		expect.equal(deduction.id, "DEDUCT-001")
		expect.equal(#deduction.requiredFacts, 3)
		expect.equal(deduction.requiredFacts[1].kind, "Statement")
		expect.equal(deduction.requiredFacts[1].id, "STMT-SUS-001-ALIBI")
		expect.equal(deduction.requiredFacts[2].kind, "Statement")
		expect.equal(deduction.requiredFacts[2].id, "STMT-SUS-002-ALIBI")
		expect.equal(deduction.requiredFacts[3].kind, "Evidence")
		expect.equal(deduction.requiredFacts[3].id, "EV-004")

		local motive = caseDef.deductions[2]
		expect.equal(motive.id, "DEDUCT-002")
		expect.equal(#motive.requiredFacts, 2)
		expect.equal(motive.requiredFacts[1].id, "EV-002")
		expect.equal(motive.requiredFacts[2].id, "EV-003")
	end)

	-- M3: LOC-001 authors a nameplate placement, with its own sign text
	-- (deliberately not `location.name`, which stays the room's own name).
	t.test("declares a sign placement for the office location", function()
		local caseDef = CaseRegistry.get("CASE-001")
		local location = caseDef.locations[1]
		expect.equal(location.name, "Office")
		local placement = location.signPlacement
		expect.truthy(placement)
		expect.truthy(#placement.text > 0)
		expect.truthy(typeof(placement.position) == "Vector3")
	end)

	-- M2: the case has an answer, and it names a suspect the player can accuse.
	t.test("declares a solution naming an accusable suspect", function()
		local caseDef = CaseRegistry.get("CASE-001")
		local solution = caseDef.solution
		expect.truthy(solution)
		expect.truthy(#solution.reveal > 0)
		local accusable = false
		for _, accusation in ipairs(caseDef.accusations or {}) do
			if accusation.suspectId == solution.culpritSuspectId then
				accusable = true
			end
		end
		expect.truthy(accusable)
	end)

	-- Case definitions contain the solution, so they must never replicate.
	t.test("case data lives in ServerStorage, not ReplicatedStorage", function()
		expect.falsy(ReplicatedStorage:FindFirstChild("Config"))
		expect.truthy(game:GetService("ServerStorage"):FindFirstChild("Config"))
	end)

	-- Every timeline event is revealed by a real evidence item, and every
	-- evidence item with a timestamp belongs to a timeline event.
	t.test("timeline events and timestamped evidence reference each other", function()
		local caseDef = CaseRegistry.get("CASE-001")
		local evidenceById = {}
		for _, ev in ipairs(caseDef.evidence) do
			evidenceById[ev.id] = ev
			if ev.timestamp then
				expect.truthy(ev.timelineEventId)
			end
		end
		for _, event in ipairs(caseDef.timeline) do
			for _, sourceId in ipairs(event.sourceEvidenceIds) do
				local source = evidenceById[sourceId]
				expect.truthy(source)
				expect.equal(source.timelineEventId, event.id)
				expect.equal(source.timestamp, event.timestamp)
			end
		end
	end)

	-- Phase 2N: CASE-001 declares one accusation per suspect, and every
	-- accusation's `supportedBy` (when present) names real, authored
	-- contradiction/deduction ids -- never invented ones.
	t.test("declares one accusation per suspect, referencing real facts", function()
		local caseDef = CaseRegistry.get("CASE-001")
		expect.truthy(caseDef.accusations)
		expect.equal(#caseDef.accusations, 2)

		local accusationIds = {}
		local suspectIds = {}
		for _, accusation in ipairs(caseDef.accusations) do
			accusationIds[accusation.id] = true
			suspectIds[accusation.suspectId] = true
		end
		expect.truthy(accusationIds["ACC-001"])
		expect.truthy(accusationIds["ACC-002"])
		expect.truthy(suspectIds["SUS-001"])
		expect.truthy(suspectIds["SUS-002"])

		local contradictionIds = {}
		for _, contradiction in ipairs(caseDef.contradictions) do
			contradictionIds[contradiction.id] = true
		end
		local deductionIds = {}
		for _, deduction in ipairs(caseDef.deductions) do
			deductionIds[deduction.id] = true
		end
		for _, accusation in ipairs(caseDef.accusations) do
			local supportedBy = accusation.supportedBy
			if supportedBy then
				for _, id in ipairs(supportedBy.contradictions or {}) do
					expect.truthy(contradictionIds[id])
				end
				for _, id in ipairs(supportedBy.deductions or {}) do
					expect.truthy(deductionIds[id])
				end
			end
		end
	end)

	-- M5: the authored timeline challenge order must reference real timeline
	-- events, cover each event exactly once, and be a real puzzle (i.e. not
	-- already in chronological order).
	t.test("timeline challenge order is valid and non-chronological", function()
		local caseDef = CaseRegistry.get("CASE-001")
		local byId = {}
		for _, event in ipairs(caseDef.timeline) do
			byId[event.id] = event
		end

		local challenge = caseDef.timelineChallengeOrder
		expect.truthy(challenge)
		expect.equal(#challenge, #caseDef.timeline)

		local seen = {}
		for index, id in ipairs(challenge) do
			expect.truthy(byId[id])
			expect.falsy(seen[id])
			seen[id] = true
			-- Not already in canonical position.
			expect.falsy(challenge[index] == caseDef.timeline[index].id)
		end
	end)
end
