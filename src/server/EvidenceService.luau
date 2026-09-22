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

-- Attempt to discover evidence by id. Returns (success, reason).
function EvidenceService.discover(player: Player, evidenceId: string): (boolean, string?)
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

	local payload: Types.EvidencePayload = {
		evidence = discovered,
		totalDiscovered = Util.count(data.caseState.discovered),
		totalEvidence = #caseDef.evidence,
		revealedEvent = revealedEvent,
	}

	evidenceDiscoveredEvent:Fire(player, payload)
	log:info("evidence discovered", {
		player = player.Name,
		evidenceId = evidenceId,
		total = payload.totalDiscovered,
	})
	StoryEvents.publish("EvidenceDiscovered", player, { evidenceId = evidenceId })
	return true, nil
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
