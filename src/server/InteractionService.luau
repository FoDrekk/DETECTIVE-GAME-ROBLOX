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
	  * no scripted scene is playing for the player (Phase 5.1)

	Each interaction kind has a handler with the shared contract:
	    handler(player, descriptor) -> boolean   -- true if accepted

	Phase 2A enablement:
	  * Examine — fully implemented (discovers evidence)
	  * Read    — implemented (discovers evidence, presents readable content)
	  * PickUp  — foundation only (validated, acknowledged, no inventory)
	  * Talk    — implemented (Phase 2G): starts a ConversationService
	              conversation with the interactable's suspect
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))
local Interactable = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Interactable"))

local EvidenceService = require(script.Parent:WaitForChild("EvidenceService"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local ObjectiveService = require(script.Parent:WaitForChild("ObjectiveService"))
local ConversationService = require(script.Parent:WaitForChild("ConversationService"))
local CutsceneService = require(script.Parent:WaitForChild("CutsceneService"))

local log = Logger.scoped("InteractionService")

local InteractionService = {}

export type Descriptor = Interactable.Descriptor
export type InteractionHandler = (player: Player, descriptor: Descriptor) -> boolean

-- Fired with (player, Types.ObservationPayload) when a non-evidence
-- interactable with authored flavour text is examined. Presentation only:
-- it carries no case/story state and changes nothing.
local observationEvent: BindableEvent = Instance.new("BindableEvent")

function InteractionService.onObservation(): BindableEvent
	return observationEvent
end

--[[
	Publish an observation to the client. Kept as a named, public function
	(rather than firing the BindableEvent inline) so it is directly
	observable in tests, the same way `StoryEvents.publish` is -- a live
	BindableEvent listener from inside the test harness is unreliable because
	delivery is deferred.
]]
function InteractionService.emitObservation(player: Player, payload: Types.ObservationPayload)
	observationEvent:Fire(player, payload)
end

--[[
	Present authored flavour text for a non-evidence interactable (Phase 2O).
	Purely a client notification: it discovers nothing, advances no objective,
	and touches no reasoning/evidence/timeline state. It only ever runs for an
	interactable that authored `ObservationText` and carries no `EvidenceId`,
	so a real clue can never be shadowed by flavour text.
]]
local function presentObservation(player: Player, descriptor: Descriptor)
	if descriptor.evidenceId or not descriptor.observation then
		return
	end
	InteractionService.emitObservation(player, {
		title = descriptor.label,
		body = descriptor.observation,
	} :: Types.ObservationPayload)
end

--------------------------------------------------------------------------
-- Handlers
--------------------------------------------------------------------------

local function discover(descriptor: Descriptor, player: Player)
	if descriptor.evidenceId then
		local ok, reason = EvidenceService.discover(player, descriptor.evidenceId)
		if not ok and reason == "already-discovered" then
			-- Looking at a clue again re-opens its readout instead of doing
			-- nothing.
			EvidenceService.review(player, descriptor.evidenceId)
		end
	end
end

-- Discover evidence if one is attached; otherwise present any authored
-- observation. Always acknowledge the interaction.
local function examineHandler(player: Player, descriptor: Descriptor): boolean
	if descriptor.evidenceId then
		discover(descriptor, player)
	else
		presentObservation(player, descriptor)
	end
	return true
end

-- Read behaves like examine but is intended for readable documents.
local function readHandler(player: Player, descriptor: Descriptor): boolean
	if descriptor.evidenceId then
		discover(descriptor, player)
	else
		presentObservation(player, descriptor)
	end
	return true
end

-- Phase 2A foundation: validate and acknowledge, no inventory yet.
local function pickUpHandler(_player: Player, _descriptor: Descriptor): boolean
	return true
end

-- Start a conversation with the interactable's suspect. Rejects a Talk-kind
-- interactable with no SuspectId, and rejects (via ConversationService) if
-- the player already has an active conversation.
local function talkHandler(player: Player, descriptor: Descriptor): boolean
	if not descriptor.suspectId then
		return false
	end
	local started = ConversationService.begin(player, descriptor.suspectId)
	return started
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
	-- Phase 5.1: nothing in the world can be used while a scene plays.
	if CutsceneService.isPlaying(player) then
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
