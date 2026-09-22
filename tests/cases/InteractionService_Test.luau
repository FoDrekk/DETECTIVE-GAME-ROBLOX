--!strict
--[[
	Tests for ServerScriptService.Server.InteractionService.
	Covers that the server uses the shared interactable contract (consistency
	with the client module), that server-side validation rejects malformed
	requests, and (Phase 2G) that Talk-kind interactables route into
	ConversationService the same way Examine/Read route into EvidenceService.
]]
return function(t)
	local CollectionService = game:GetService("CollectionService")
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Server = ServerScriptService:WaitForChild("Server")
	local InteractionService = require(Server:WaitForChild("InteractionService"))
	local PlayerDataService = require(Server:WaitForChild("PlayerDataService"))
	local ConversationService = require(Server:WaitForChild("ConversationService"))
	local Interactable = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Interactable"))
	local expect = t.expect

	local function makePlayer(): any
		local id = t.nextUserId()
		local player = { UserId = id, Name = `INT{id}` }
		PlayerDataService.initialize(player, "CASE-001")
		return player
	end

	-- Talk validation needs a real distance check, unlike the kind/tag
	-- rejection tests above, so these give the mock player a minimal fake
	-- character with a HumanoidRootPart at a chosen position.
	local function withCharacterAt(player: any, position: Vector3)
		local character = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Anchored = true
		root.Position = position
		root.Parent = character
		character.Parent = workspace
		player.Character = character
	end

	-- The server descriptor matches the shared contract exactly.
	t.test("server describe matches the shared contract", function()
		local part = Instance.new("Part")
		part.Name = "ContractProbe"
		part:SetAttribute("InteractionKind", "Examine")
		part:SetAttribute("PromptLabel", "Examine Probe")
		part:SetAttribute("EvidenceId", "EV-001")
		CollectionService:AddTag(part, Interactable.TAG)

		local fromServer = InteractionService.describe(part)
		local fromShared = Interactable.describe(part)
		expect.truthy(fromServer)
		expect.deepEqual(fromServer, fromShared)
		part:Destroy()
	end)

	-- The server rejects a request whose kind does not match the authored kind.
	t.test("rejects a mismatched interaction kind", function()
		local player = makePlayer()
		local part = Instance.new("Part")
		part.Anchored = true
		part:SetAttribute("InteractionKind", "Read")
		part:SetAttribute("EvidenceId", "EV-003")
		CollectionService:AddTag(part, Interactable.TAG)
		part.Parent = workspace

		InteractionService.handleRequest(player, part, "Examine")
		expect.falsy(require(Server:WaitForChild("EvidenceService")).isDiscovered(player, "EV-003"))
		part:Destroy()
	end)

	-- The server rejects an instance that is not tagged.
	t.test("rejects an untagged instance", function()
		local player = makePlayer()
		local part = Instance.new("Part")
		part.Anchored = true
		part:SetAttribute("InteractionKind", "Examine")
		part:SetAttribute("EvidenceId", "EV-001")
		part.Parent = workspace

		InteractionService.handleRequest(player, part, "Examine")
		expect.falsy(require(Server:WaitForChild("EvidenceService")).isDiscovered(player, "EV-001"))
		part:Destroy()
	end)

	-- The server rejects an instance outside Workspace.
	t.test("rejects an instance outside workspace", function()
		local player = makePlayer()
		local part = Instance.new("Part")
		part:SetAttribute("InteractionKind", "Examine")
		part:SetAttribute("EvidenceId", "EV-001")
		CollectionService:AddTag(part, Interactable.TAG)

		InteractionService.handleRequest(player, part, "Examine")
		expect.falsy(require(Server:WaitForChild("EvidenceService")).isDiscovered(player, "EV-001"))
		part:Destroy()
	end)

	-- The server rejects an unsupported kind.
	t.test("rejects an unsupported kind", function()
		local player = makePlayer()
		local part = Instance.new("Part")
		part.Anchored = true
		part:SetAttribute("InteractionKind", "Unlock")
		part:SetAttribute("EvidenceId", "EV-001")
		CollectionService:AddTag(part, Interactable.TAG)
		part.Parent = workspace

		InteractionService.handleRequest(player, part, "Unlock")
		expect.falsy(require(Server:WaitForChild("EvidenceService")).isDiscovered(player, "EV-001"))
		part:Destroy()
	end)

	-- A well-formed Talk interactable within range starts a conversation.
	t.test("valid Talk interaction starts a conversation", function()
		local player = makePlayer()
		local part = Instance.new("Part")
		part.Anchored = true
		part.Position = Vector3.new(100, 0, 100)
		part:SetAttribute("InteractionKind", "Talk")
		part:SetAttribute("SuspectId", "SUS-001")
		CollectionService:AddTag(part, Interactable.TAG)
		part.Parent = workspace
		withCharacterAt(player, part.Position)

		InteractionService.handleRequest(player, part, "Talk")
		expect.truthy(ConversationService.isTalking(player))
		part:Destroy()
	end)

	-- A Talk interactable with no SuspectId is an invalid target: rejected.
	t.test("rejects a Talk interactable with no suspect id", function()
		local player = makePlayer()
		local part = Instance.new("Part")
		part.Anchored = true
		part.Position = Vector3.new(101, 0, 100)
		part:SetAttribute("InteractionKind", "Talk")
		CollectionService:AddTag(part, Interactable.TAG)
		part.Parent = workspace
		withCharacterAt(player, part.Position)

		InteractionService.handleRequest(player, part, "Talk")
		expect.falsy(ConversationService.isTalking(player))
		part:Destroy()
	end)

	-- A suspect id that does not exist in the case is an invalid target.
	t.test("rejects a Talk interactable with an unknown suspect id", function()
		local player = makePlayer()
		local part = Instance.new("Part")
		part.Anchored = true
		part.Position = Vector3.new(102, 0, 100)
		part:SetAttribute("InteractionKind", "Talk")
		part:SetAttribute("SuspectId", "SUS-999")
		CollectionService:AddTag(part, Interactable.TAG)
		part.Parent = workspace
		withCharacterAt(player, part.Position)

		InteractionService.handleRequest(player, part, "Talk")
		expect.falsy(ConversationService.isTalking(player))
		part:Destroy()
	end)

	-- A far Talk interaction is rejected by the existing generic distance
	-- check -- no Talk-specific distance logic exists or is needed.
	t.test("rejects a far Talk interaction", function()
		local player = makePlayer()
		local part = Instance.new("Part")
		part.Anchored = true
		part.Position = Vector3.new(200, 0, 200)
		part:SetAttribute("InteractionKind", "Talk")
		part:SetAttribute("SuspectId", "SUS-001")
		CollectionService:AddTag(part, Interactable.TAG)
		part.Parent = workspace
		withCharacterAt(player, part.Position + Vector3.new(50, 0, 0))

		InteractionService.handleRequest(player, part, "Talk")
		expect.falsy(ConversationService.isTalking(player))
		part:Destroy()
	end)

	-- The wrong interaction kind on a Talk-tagged suspect is rejected by the
	-- existing generic kind-match check.
	t.test("rejects Examine on a Talk-tagged suspect interactable", function()
		local player = makePlayer()
		local part = Instance.new("Part")
		part.Anchored = true
		part.Position = Vector3.new(103, 0, 100)
		part:SetAttribute("InteractionKind", "Talk")
		part:SetAttribute("SuspectId", "SUS-001")
		CollectionService:AddTag(part, Interactable.TAG)
		part.Parent = workspace
		withCharacterAt(player, part.Position)

		InteractionService.handleRequest(player, part, "Examine")
		expect.falsy(ConversationService.isTalking(player))
		part:Destroy()
	end)

	-- Talking to a suspect while already mid-conversation is rejected
	-- (duplicate/invalid conversation-state), and existing Examine/Read
	-- handlers are unaffected by any of this.
	t.test("a second Talk while already talking does not change the active conversation", function()
		local player = makePlayer()
		local part = Instance.new("Part")
		part.Anchored = true
		part.Position = Vector3.new(104, 0, 100)
		part:SetAttribute("InteractionKind", "Talk")
		part:SetAttribute("SuspectId", "SUS-001")
		CollectionService:AddTag(part, Interactable.TAG)
		part.Parent = workspace
		withCharacterAt(player, part.Position)

		InteractionService.handleRequest(player, part, "Talk")
		expect.truthy(ConversationService.isTalking(player))
		InteractionService.handleRequest(player, part, "Talk")
		local payload = ConversationService.getCurrentPayload(player)
		expect.equal(payload.nodeId, "SUS-001-1")
		part:Destroy()
	end)
end
