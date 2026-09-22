--!strict
--[[
	InteractionService
	Authoritative interaction handling.

	Interactable parsing is delegated to the shared `Interactable` contract, so
	the server and client can never disagree about what an interactable means.
	This service owns validation only:

	  * the instance is tagged and a descendant of Workspace
	  * it is a well-formed, enabled interactable
	  * the requested kind matches the authored kind
	  * the player is within the configured prompt range

	Each interaction kind has a handler with the shared contract:
	    handler(player, descriptor) -> boolean   -- true if accepted

	Phase 2A enablement:
	  * Examine — fully implemented (discovers evidence)
	  * Read    — implemented (discovers evidence, presents readable content)
	  * PickUp  — foundation only (validated, acknowledged, no inventory)
	  * Talk    — foundation only (validated, acknowledged, no dialogue)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))
local Interactable = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Interactable"))

local EvidenceService = require(script.Parent:WaitForChild("EvidenceService"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local ObjectiveService = require(script.Parent:WaitForChild("ObjectiveService"))

local log = Logger.scoped("InteractionService")

local InteractionService = {}

export type Descriptor = Interactable.Descriptor
export type InteractionHandler = (player: Player, descriptor: Descriptor) -> boolean

--------------------------------------------------------------------------
-- Handlers
--------------------------------------------------------------------------

local function discover(descriptor: Descriptor, player: Player)
	if descriptor.evidenceId then
		EvidenceService.discover(player, descriptor.evidenceId)
	end
end

-- Discover evidence if one is attached; always acknowledge the interaction.
local function examineHandler(player: Player, descriptor: Descriptor): boolean
	discover(descriptor, player)
	return true
end

-- Read behaves like examine but is intended for readable documents.
local function readHandler(player: Player, descriptor: Descriptor): boolean
	discover(descriptor, player)
	return true
end

-- Phase 2A foundation: validate and acknowledge, no inventory yet.
local function pickUpHandler(_player: Player, _descriptor: Descriptor): boolean
	return true
end

-- Phase 2A foundation: validate and acknowledge, no dialogue trees yet.
local function talkHandler(_player: Player, _descriptor: Descriptor): boolean
	return true
end

local HANDLERS: { [Types.InteractionKind]: InteractionHandler } = {
	Examine = examineHandler,
	Read = readHandler,
	PickUp = pickUpHandler,
	Talk = talkHandler,
}

--------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------

-- Describe an interactable using the shared contract.
function InteractionService.describe(instance: Instance): Descriptor?
	return Interactable.describe(instance)
end

function InteractionService.getInteractables(): { Instance }
	return Interactable.getAll()
end

-- Handle an interaction request from a client.
function InteractionService.handleRequest(player: Player, instance: Instance, kind: Types.InteractionKind)
	if not instance or not instance:IsDescendantOf(workspace) then
		return
	end
	if not Interactable.isInteractable(instance) then
		return
	end

	local descriptor = Interactable.describe(instance)
	if not descriptor then
		return
	end
	if descriptor.kind ~= kind then
		return
	end

	-- Server-side distance validation.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local objectPart = Interactable.getPart(instance)
	if not root or not objectPart then
		return
	end
	local distance = (root.Position - objectPart.Position).Magnitude
	if distance > Config.Interaction.MaxPromptDistance + 4 then
		return
	end

	if not PlayerDataService.get(player) then
		return
	end

	local handler = HANDLERS[kind]
	if not handler then
		return
	end

	local accepted = handler(player, descriptor)
	if not accepted then
		return
	end

	-- Evidence discovery (inside the handler) advances objective requirements
	-- keyed by evidence; the interaction itself advances requirements keyed by
	-- kind or by the interacted instance's Name. ObjectiveService owns all
	-- progress decisions.
	ObjectiveService.recordInteraction(player, kind, descriptor.evidenceId, descriptor.instance.Name)
end

function InteractionService.start()
	log:info("started", { kinds = 4 })
end

return InteractionService
