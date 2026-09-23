--!strict
--[[
	Tests for ReplicatedStorage.Shared.Interactable.
	Covers the shared descriptor contract, enabled-kind gating, optional
	evidence ids, and the world interactables in the authored office.
]]
return function(t)
	local CollectionService = game:GetService("CollectionService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Interactable = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Interactable"))
	local expect = t.expect

	local function makeTagged(attributes: { [string]: any }): Instance
		local part = Instance.new("Part")
		part.Name = "UnitTestInteractable"
		part.Anchored = true
		for name, value in pairs(attributes) do
			part:SetAttribute(name, value)
		end
		CollectionService:AddTag(part, Interactable.TAG)
		return part
	end

	-- A well-formed interactable describes with kind, label and evidence id.
	t.test("describes a well-formed interactable", function()
		local inst = makeTagged({
			InteractionKind = "Examine",
			PromptLabel = "Examine Thing",
			EvidenceId = "EV-TEST",
		})
		local d = Interactable.describe(inst)
		expect.truthy(d)
		expect.equal(d and d.kind, "Examine")
		expect.equal(d and d.label, "Examine Thing")
		expect.equal(d and d.evidenceId, "EV-TEST")
		inst:Destroy()
	end)

	-- A missing prompt label falls back to the kind name.
	t.test("falls back to kind when no label is set", function()
		local inst = makeTagged({ InteractionKind = "Read" })
		local d = Interactable.describe(inst)
		expect.truthy(d)
		expect.equal(d and d.label, "Read")
		inst:Destroy()
	end)

	-- Evidence id is optional and absent when not authored.
	t.test("omits an absent evidence id", function()
		local inst = makeTagged({ InteractionKind = "PickUp" })
		local d = Interactable.describe(inst)
		expect.truthy(d)
		expect.falsy(d and d.evidenceId)
		inst:Destroy()
	end)

	-- An unsupported interaction kind is rejected.
	t.test("rejects an unsupported kind", function()
		local inst = makeTagged({ InteractionKind = "Explode" })
		expect.falsy(Interactable.describe(inst))
		inst:Destroy()
	end)

	-- An instance with no interaction kind is not describable.
	t.test("rejects an instance with no kind", function()
		local inst = makeTagged({ PromptLabel = "Nothing" })
		expect.falsy(Interactable.describe(inst))
		inst:Destroy()
	end)

	-- An empty-string kind is treated as absent.
	t.test("rejects an empty kind", function()
		local inst = makeTagged({ InteractionKind = "" })
		expect.falsy(Interactable.describe(inst))
		inst:Destroy()
	end)

	-- SuspectId is optional and read the same way as EvidenceId (Phase 2F
	-- preparation for future NPC interactables; no NPC behavior yet).
	t.test("describes an optional suspect id", function()
		local inst = makeTagged({ InteractionKind = "Talk", SuspectId = "SUS-001" })
		local d = Interactable.describe(inst)
		expect.truthy(d)
		expect.equal(d and d.suspectId, "SUS-001")
		inst:Destroy()
	end)

	-- Suspect id is optional and absent when not authored.
	t.test("omits an absent suspect id", function()
		local inst = makeTagged({ InteractionKind = "Talk" })
		local d = Interactable.describe(inst)
		expect.truthy(d)
		expect.falsy(d and d.suspectId)
		inst:Destroy()
	end)

	-- isKind accepts enabled kinds and rejects unknown ones.
	t.test("isKind gates on enabled kinds", function()
		expect.truthy(Interactable.isKind("Examine"))
		expect.truthy(Interactable.isKind("Read"))
		expect.truthy(Interactable.isKind("PickUp"))
		expect.truthy(Interactable.isKind("Talk"))
		expect.falsy(Interactable.isKind("Unlock"))
	end)

	-- Every tagged instance in the authored world produces a valid descriptor.
	t.test("all world interactables are well-formed", function()
		local tagged = Interactable.getAll()
		expect.truthy(#tagged > 0)
		for _, inst in ipairs(tagged) do
			expect.truthy(Interactable.describe(inst))
		end
	end)

	-- The authored world exposes exactly the evidence the active case needs.
	t.test("world exposes the case evidence ids", function()
		local found: { [string]: boolean } = {}
		for _, inst in ipairs(Interactable.getAll()) do
			local d = Interactable.describe(inst)
			if d and d.evidenceId then
				found[d.evidenceId] = true
			end
		end
		expect.truthy(found["EV-001"])
		expect.truthy(found["EV-002"])
		expect.truthy(found["EV-003"])
		expect.truthy(found["EV-004"])
	end)
end
