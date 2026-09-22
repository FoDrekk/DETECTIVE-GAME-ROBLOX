--!strict
--[[
	Tests for ServerScriptService.Server.InteractionService.
	Covers that the server uses the shared interactable contract (consistency
	with the client module) and that server-side validation rejects malformed
	requests.
]]
return function(t)
	local CollectionService = game:GetService("CollectionService")
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Server = ServerScriptService:WaitForChild("Server")
	local InteractionService = require(Server:WaitForChild("InteractionService"))
	local PlayerDataService = require(Server:WaitForChild("PlayerDataService"))
	local Interactable = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Interactable"))
	local expect = t.expect

	local nextUserId = 930000
	local function makePlayer(): any
		nextUserId += 1
		local player = { UserId = nextUserId, Name = `INT{nextUserId}` }
		PlayerDataService.initialize(player, "CASE-001")
		return player
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
end
