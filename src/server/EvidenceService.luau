--!strict
--[[
	EvidenceService
	Authoritative evidence discovery. Prevents duplicate discovery and emits
	discovery events for the client.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Util = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"))
local Signals = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signals"))
local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local CaseService = require(script.Parent:WaitForChild("CaseService"))
local StoryEvents = require(script.Parent:WaitForChild("StoryEvents"))

local TimelineService = require(script.Parent:WaitForChild("TimelineService"))
local ObjectiveService = require(script.Parent:WaitForChild("ObjectiveService"))

local log = Logger.scoped("EvidenceService")

local EvidenceService = {}

local evidenceDiscoveredEvent: BindableEvent = Instance.new("BindableEvent")

function EvidenceService.onDiscovered(): BindableEvent
	return evidenceDiscoveredEvent
end

-- Returns true if the player has already discovered this evidence id.
function EvidenceService.isDiscovered(player: Player, evidenceId: string): boolean
	local data = PlayerDataService.get(player)
	if not data then
		return false
	end
	return data.caseState.discovered[evidenceId] ~= nil
end

-- Discovery itself, shared by an examine (discover) and a conversation
-- handing evidence over (grant). `granted` only changes how the client is
-- told (EvidencePayload.granted).
local function discoverEvidence(player: Player, evidenceId: string, granted: boolean): (boolean, string?)
	local data = PlayerDataService.get(player)
	if not data then
		return false, "no-player-data"
	end

	local caseDef = CaseService.getCase(data.caseState.caseId)
	if not caseDef then
		return false, "no-case"
	end

	if data.caseState.discovered[evidenceId] then
		log:debug("duplicate discovery rejected", { player = player.Name, evidenceId = evidenceId })
		return false, "already-discovered"
	end

	local definition: Types.EvidenceDefinition? = nil
	for _, ev in ipairs(caseDef.evidence) do
		if ev.id == evidenceId then
			definition = ev
			break
		end
	end

	if not definition then
		log:warn("unknown evidence requested", {
			player = player.Name,
			evidenceId = evidenceId,
			caseId = data.caseState.caseId,
		})
		return false, "unknown-evidence"
	end

	local discovered: Types.DiscoveredEvidence = {
		id = definition.id,
		name = definition.name,
		description = definition.description,
		location = definition.location,
		importance = definition.importance,
		details = definition.details,
		timestamp = definition.timestamp,
		category = definition.category,
		timelineEventId = definition.timelineEventId,
		relatedEvidenceIds = definition.relatedEvidenceIds,
		discovered = true,
		discoveredAt = Util.timestamp(),
	}

	data.caseState.discovered[evidenceId] = discovered

	-- Discovery order: evidence -> timeline. The timeline reveal is a fact
	-- derived from this discovery; objective evaluation follows via the
	-- InteractionService pipeline once this returns.
	local revealedEvent = TimelineService.revealForEvidence(player, definition)

	-- Phase 2O: display names of this evidence's authored related items that
	-- the player has ALREADY discovered. Undiscovered related evidence is
	-- never included, so the cross-reference can't leak a hidden clue.
	local related: { string } = {}
	if definition.relatedEvidenceIds then
		for _, relatedId in ipairs(definition.relatedEvidenceIds) do
			local relatedEvidence = data.caseState.discovered[relatedId]
			if relatedEvidence then
				table.insert(related, relatedEvidence.name)
			end
		end
	end

	-- Phase 5.4: the clues this one hands over with it. Named on the readout
	-- (only the ones newly added), then granted once the readout is sent.
	local handedOver: { string } = {}
	local alsoAdded: { string } = {}
	for _, otherId in ipairs(definition.grantsEvidence or {}) do
		if otherId ~= evidenceId and not data.caseState.discovered[otherId] then
			for _, other in ipairs(caseDef.evidence) do
				if other.id == otherId then
					table.insert(handedOver, otherId)
					table.insert(alsoAdded, other.name)
					break
				end
			end
		end
	end

	local payload: Types.EvidencePayload = {
		evidence = discovered,
		-- Counts the ones about to be handed over with it, so the readout's
		-- "x / y" is what the Case File will say a moment later.
		totalDiscovered = Util.count(data.caseState.discovered) + #handedOver,
		totalEvidence = #caseDef.evidence,
		revealedEvent = revealedEvent,
		related = if #related > 0 then related else nil,
		granted = if granted then true else nil,
		alsoAdded = if #alsoAdded > 0 then alsoAdded else nil,
	}

	evidenceDiscoveredEvent:Fire(player, payload)
	log:info("evidence discovered", {
		player = player.Name,
		evidenceId = evidenceId,
		total = payload.totalDiscovered,
		granted = if granted then true else nil,
	})
	StoryEvents.publish("EvidenceDiscovered", player, { evidenceId = evidenceId })

	-- The primary is recorded and announced first, so a chain can never loop
	-- back to it (it is already discovered by the time the others are asked).
	for _, otherId in ipairs(handedOver) do
		EvidenceService.grant(player, otherId)
	end
	return true, nil
end

-- Attempt to discover evidence by id. Returns (success, reason).
function EvidenceService.discover(player: Player, evidenceId: string): (boolean, string?)
	return discoverEvidence(player, evidenceId, false)
end

--[[
	Phase 5.1: evidence handed over in a conversation (a dialogue node's
	`grantsEvidence`), rather than found by examining an object. The same
	discovery -- timeline reveal, StoryEvent, reasoning -- plus the objective
	evaluation an examine gets from InteractionService afterwards, since no
	interaction is involved here.

	Idempotent like discover: already-discovered evidence is left alone
	("already-discovered", and no readout is re-sent), which is what lets a
	case offer more than one route to the same clue.
]]
function EvidenceService.grant(player: Player, evidenceId: string): (boolean, string?)
	local ok, reason = discoverEvidence(player, evidenceId, true)
	if ok then
		ObjectiveService.recordEvidence(player, evidenceId)
	end
	return ok, reason
end

--[[
	Re-open an already-discovered clue's readout (the player examined it
	again). Not a discovery: no state changes, no timeline reveal, no
	StoryEvent -- the same payload shape, flagged `revisited`, so the client
	can show it quietly. Returns false for evidence not yet discovered.
]]
function EvidenceService.review(player: Player, evidenceId: string): boolean
	local data = PlayerDataService.get(player)
	local caseDef = data and CaseService.getCase(data.caseState.caseId)
	local discovered = data and data.caseState.discovered[evidenceId]
	if not data or not caseDef or not discovered then
		return false
	end
	local related: { string } = {}
	for _, relatedId in ipairs(discovered.relatedEvidenceIds or {}) do
		local relatedEvidence = data.caseState.discovered[relatedId]
		if relatedEvidence then
			table.insert(related, relatedEvidence.name)
		end
	end
	local payload: Types.EvidencePayload = {
		evidence = discovered,
		totalDiscovered = Util.count(data.caseState.discovered),
		totalEvidence = #caseDef.evidence,
		related = if #related > 0 then related else nil,
		revisited = true,
	}
	evidenceDiscoveredEvent:Fire(player, payload)
	return true
end

function EvidenceService.getState(player: Player): Types.EvidenceState
	local data = PlayerDataService.get(player)
	if not data then
		return {}
	end
	return data.caseState.discovered
end

function EvidenceService.start()
	log:debug("started")
end

return EvidenceService
