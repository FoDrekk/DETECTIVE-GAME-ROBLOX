--!strict
--[[
	TimelineService
	Authoritative, data-driven case timeline.

	Events are authored in case data (CaseDefinition.timeline) and stay hidden
	until at least one of their `sourceEvidenceIds` has been discovered. This
	service owns reveal state; it never interprets facts and never invents
	events or conclusions.

	Discovery order is enforced upstream (EvidenceService):
	    evidence discovery -> TimelineService.revealForEvidence -> objective
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Signals = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signals"))
local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local CaseService = require(script.Parent:WaitForChild("CaseService"))

local log = Logger.scoped("TimelineService")

local TimelineService = {}

local timelineUpdatedEvent: BindableEvent = Instance.new("BindableEvent")

function TimelineService.onUpdated(): BindableEvent
	return timelineUpdatedEvent
end

local function caseTimeline(caseId: string): { Types.TimelineEventDefinition }
	local caseDef = CaseService.getCase(caseId)
	if not caseDef then
		return {}
	end
	return caseDef.timeline
end

-- Build the client-facing view of an event. `sources` are display names of the
-- revealing evidence the player has actually discovered.
local function toProgress(
	event: Types.TimelineEventDefinition,
	discovered: Types.EvidenceState
): Types.TimelineEventProgress
	local sources = {}
	for _, evidenceId in ipairs(event.sourceEvidenceIds) do
		local evidence = discovered[evidenceId]
		if evidence then
			table.insert(sources, evidence.name)
		end
	end
	return {
		id = event.id,
		timestamp = event.timestamp,
		title = event.title,
		description = event.description,
		sources = sources,
	}
end

-- Reveal any timeline event whose source evidence was just discovered.
-- Returns the newly revealed event (nil if none), so callers can attach it to
-- the discovery payload. Never reveals an already-revealed event twice.
function TimelineService.revealForEvidence(
	player: Player,
	evidence: Types.EvidenceDefinition
): Types.TimelineEventProgress?
	local data = PlayerDataService.get(player)
	if not data then
		return nil
	end

	local eventId = evidence.timelineEventId
	if not eventId then
		return nil
	end

	local state = data.caseState
	if state.discoveredTimeline[eventId] then
		return nil
	end

	local event: Types.TimelineEventDefinition? = nil
	for _, candidate in ipairs(caseTimeline(state.caseId)) do
		if candidate.id == eventId then
			event = candidate
			break
		end
	end
	if not event then
		log:warn("evidence references an unknown timeline event", {
			player = player.Name,
			evidenceId = evidence.id,
			eventId = eventId,
		})
		return nil
	end

	-- Only reveal when a source evidence item is actually discovered. This
	-- keeps the timeline strictly downstream of evidence.
	local revealed = false
	for _, sourceId in ipairs(event.sourceEvidenceIds) do
		if state.discovered[sourceId] then
			revealed = true
			break
		end
	end
	if not revealed then
		return nil
	end

	state.discoveredTimeline[eventId] = true
	log:info("timeline event revealed", {
		player = player.Name,
		eventId = eventId,
		timestamp = event.timestamp,
	})
	-- Broadcast the full discovered timeline; it is idempotent and keeps the
	-- client view consistent without partial-update bookkeeping.
	TimelineService.sendCurrent(player)
	return toProgress(event, state.discovered)
end

-- Chronological list of discovered events (deterministic by timeMinutes, then
-- by id so equal timestamps never flicker in order).
function TimelineService.getDiscovered(player: Player): { Types.TimelineEventProgress }
	local data = PlayerDataService.get(player)
	if not data then
		return {}
	end

	local state = data.caseState
	local revealed: { Types.TimelineEventDefinition } = {}
	for _, event in ipairs(caseTimeline(state.caseId)) do
		if state.discoveredTimeline[event.id] then
			table.insert(revealed, event)
		end
	end

	table.sort(revealed, function(a, b)
		if a.timeMinutes == b.timeMinutes then
			return a.id < b.id
		end
		return a.timeMinutes < b.timeMinutes
	end)

	local progressList = {}
	for _, event in ipairs(revealed) do
		table.insert(progressList, toProgress(event, state.discovered))
	end
	return progressList
end

-- Send the full discovered timeline to a player (join/sync and explicit request).
function TimelineService.sendCurrent(player: Player)
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	local payload: Types.TimelinePayload = {
		events = TimelineService.getDiscovered(player),
		totalEvents = #caseTimeline(data.caseState.caseId),
	}
	timelineUpdatedEvent:Fire(player, payload)
end

function TimelineService.start()
	log:debug("started")
end

return TimelineService
