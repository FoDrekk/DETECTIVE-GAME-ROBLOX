--!strict
--[[
	Tests for Phase 2O investigation feedback:
	  * InteractionService's flavour observation path (non-evidence
	    interactables with authored ObservationText)
	  * spoiler safety of observations and related-evidence cross-refs
	  * EvidenceService/ReasoningService relatedEvidenceIds resolution

	Observation feedback must create no evidence, timeline, objective or
	reasoning state. relatedEvidenceIds must resolve only to authored,
	already-discovered evidence.

	Each case uses a unique mock UserId for isolation.
]]
return function(t)
	local CollectionService = game:GetService("CollectionService")
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Server = ServerScriptService:WaitForChild("Server")
	local InteractionService = require(Server:WaitForChild("InteractionService"))
	local EvidenceService = require(Server:WaitForChild("EvidenceService"))
	local ReasoningService = require(Server:WaitForChild("ReasoningService"))
	local ObjectiveService = require(Server:WaitForChild("ObjectiveService"))
	local PlayerDataService = require(Server:WaitForChild("PlayerDataService"))
	local Interactable = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Interactable"))
	local CaseRegistry = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CaseRegistry"))
	local expect = t.expect

	local function makePlayer(): any
		local id = t.nextUserId()
		local player = { UserId = id, Name = `OBS{id}` }
		PlayerDataService.initialize(player, "CASE-001")
		return player
	end

	local function withCharacterAt(player: any, position: Vector3)
		local character = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Anchored = true
		root.Position = position
		root.Parent = character
		character.Parent = workspace
		player.Character = character
		return character
	end

	-- Builds an interactable part at a position, optionally with an
	-- observation and/or evidence id. Returns the part.
	local function makeInteractable(position: Vector3, observation: string?, evidenceId: string?): Part
		local part = Instance.new("Part")
		part.Name = "ObsProbe"
		part.Anchored = true
		part.Size = Vector3.new(2, 2, 2)
		part.Position = position
		part:SetAttribute("InteractionKind", "Examine")
		part:SetAttribute("PromptLabel", "Examine Probe")
		if observation then
			part:SetAttribute("ObservationText", observation)
		end
		if evidenceId then
			part:SetAttribute("EvidenceId", evidenceId)
		end
		CollectionService:AddTag(part, Interactable.TAG)
		part.Parent = workspace
		return part
	end

	-- Captures observations fired for `player` during fn by spying on
	-- InteractionService.emitObservation (BindableEvent delivery is deferred
	-- and unreliable to observe live from inside this harness -- see
	-- Phase 2F's StoryEvents_Test notes and the existing StoryEvents spy).
	local function captureObservations(player: any, fn: () -> ()): { any }
		local captured = {}
		local original = InteractionService.emitObservation
		InteractionService.emitObservation = function(p, payload)
			if p == player then
				table.insert(captured, payload)
			end
		end
		local ok, err = pcall(fn)
		InteractionService.emitObservation = original
		if not ok then
			error(err, 0)
		end
		return captured
	end

	------------------------------------------------------------------
	-- Observation feedback
	------------------------------------------------------------------

	t.test("examining a non-evidence interactable with ObservationText fires an observation", function()
		local player = makePlayer()
		withCharacterAt(player, Vector3.new(200, 0, 200))
		local part = makeInteractable(Vector3.new(201, 0, 200), "A cold cup of coffee.")

		local obs = captureObservations(player, function()
			InteractionService.handleRequest(player, part, "Examine")
		end)

		expect.equal(#obs, 1)
		expect.equal(obs[1].body, "A cold cup of coffee.")
		expect.equal(obs[1].title, "Examine Probe")
		part:Destroy()
	end)

	-- Flavour text creates no story state of any kind.
	t.test("an observation creates no evidence, objective or reasoning state", function()
		local player = makePlayer()
		withCharacterAt(player, Vector3.new(210, 0, 210))
		local part = makeInteractable(Vector3.new(211, 0, 210), "Just a pen.")

		captureObservations(player, function()
			InteractionService.handleRequest(player, part, "Examine")
		end)

		local data = PlayerDataService.get(player)
		expect.equal(next(data.caseState.discovered), nil)
		expect.equal(next(data.caseState.discoveredTimeline), nil)
		expect.equal(next(data.caseState.completedObjectives), nil)
		expect.equal(next(data.caseState.unlockedContradictions), nil)
		expect.equal(next(data.caseState.unlockedDeductions), nil)
		expect.equal(ObjectiveService.getActiveObjectiveId(player), "OBJ-001")
		part:Destroy()
	end)

	-- A non-evidence interactable with no ObservationText fires nothing (no
	-- silent success, but also no fabricated content).
	t.test("a non-evidence interactable without ObservationText fires no observation", function()
		local player = makePlayer()
		withCharacterAt(player, Vector3.new(220, 0, 220))
		local part = makeInteractable(Vector3.new(221, 0, 220), nil, nil)

		local obs = captureObservations(player, function()
			InteractionService.handleRequest(player, part, "Examine")
		end)

		expect.equal(#obs, 0)
		part:Destroy()
	end)

	-- An evidence-carrying interactable must never emit flavour text, even if
	-- it (incorrectly) authors ObservationText -- evidence takes precedence.
	t.test("evidence discovery is never shadowed by observation text", function()
		local player = makePlayer()
		withCharacterAt(player, Vector3.new(230, 0, 230))
		local part = makeInteractable(Vector3.new(231, 0, 230), "Should never show.", "EV-001")

		local obs = captureObservations(player, function()
			InteractionService.handleRequest(player, part, "Examine")
		end)

		expect.equal(#obs, 0)
		expect.truthy(EvidenceService.isDiscovered(player, "EV-001"))
		part:Destroy()
	end)

	------------------------------------------------------------------
	-- CASE-001 authored observations
	------------------------------------------------------------------

	-- Every authored observation targets a real, non-evidence interactable
	-- name and never mentions a hidden case id.
	t.test("CASE-001 observations are authored and spoiler-free", function()
		local caseDef = CaseRegistry.get("CASE-001")
		expect.truthy(caseDef.observations)
		expect.equal(#caseDef.observations, 7)
		for _, observation in ipairs(caseDef.observations) do
			expect.truthy(type(observation.instanceName) == "string" and #observation.instanceName > 0)
			expect.truthy(type(observation.text) == "string" and #observation.text > 0)
			-- No hidden ids or role spoilers in flavour text. Plain-text
			-- search (not a Lua pattern) to avoid `-` being a quantifier.
			expect.falsy(string.find(observation.text, "EV-", 1, true))
			expect.falsy(string.find(observation.text, "SUS-", 1, true))
			expect.falsy(string.find(observation.text, "CONTRA-", 1, true))
			expect.falsy(string.find(observation.text, "DEDUCT-", 1, true))
		end
	end)

	------------------------------------------------------------------
	-- relatedEvidenceIds
	------------------------------------------------------------------

	-- CASE-001 only authors a relationship the facts support, and only
	-- between real evidence ids.
	t.test("CASE-001 relatedEvidenceIds reference real evidence", function()
		local caseDef = CaseRegistry.get("CASE-001")
		local ids = {}
		for _, ev in ipairs(caseDef.evidence) do
			ids[ev.id] = true
		end
		local linked = 0
		for _, ev in ipairs(caseDef.evidence) do
			if ev.relatedEvidenceIds then
				for _, relatedId in ipairs(ev.relatedEvidenceIds) do
					expect.truthy(ids[relatedId])
					expect.falsy(relatedId == ev.id)
					linked += 1
				end
			end
		end
		expect.truthy(linked > 0)
	end)

	-- Discovery order does not matter: a relationship only appears in the
	-- case-file cross-reference once BOTH sides are discovered, and an
	-- undiscovered partner is never revealed.
	t.test("related evidence is only shown once the partner is discovered", function()
		local player = makePlayer()

		-- Only EV-001 discovered: no cross-reference entry yet.
		EvidenceService.discover(player, "EV-001")
		local reasoning = ReasoningService.getPayload(player)
		expect.equal(#reasoning.relatedEvidence, 0)

		-- EV-002 discovered too: the pair now appears, both directions.
		EvidenceService.discover(player, "EV-002")
		reasoning = ReasoningService.getPayload(player)
		expect.equal(#reasoning.relatedEvidence, 2)

		local byId = {}
		for _, entry in ipairs(reasoning.relatedEvidence) do
			byId[entry.id] = entry
		end
		expect.equal(byId["EV-001"].related[1], "Laptop")
		expect.equal(byId["EV-002"].related[1], "Phone")
	end)

	-- An evidence item with no authored relationship never appears in the
	-- cross-reference (no fabricated links).
	t.test("evidence without relatedEvidenceIds is absent from the cross-reference", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-003")
		local reasoning = ReasoningService.getPayload(player)
		expect.equal(#reasoning.relatedEvidence, 0)
	end)

	-- The reasoning cross-reference is spoiler-safe: before any discovery it
	-- is empty.
	t.test("related evidence cross-reference is empty before discovery (spoiler safety)", function()
		local player = makePlayer()
		local reasoning = ReasoningService.getPayload(player)
		expect.equal(#reasoning.relatedEvidence, 0)
	end)
end
