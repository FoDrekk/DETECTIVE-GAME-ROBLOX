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
local StoryEvents = require(script.Parent:WaitForChild("StoryEvents"))
local ObjectiveService = require(script.Parent:WaitForChild("ObjectiveService"))

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
local function chronological(player: Player): { Types.TimelineEventProgress }
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

-- The discovered events in the case's authored challenge order (M5): the
-- explicit `timelineChallengeOrder` when authored, falling back to the
-- `timeline` array order. Both are fixed by the case, never shuffled at
-- random, so the puzzle is deterministic and reproducible.
local function challengeOrder(player: Player): { Types.TimelineEventProgress }
	local data = PlayerDataService.get(player)
	if not data then
		return {}
	end
	local state = data.caseState
	local caseDef = CaseService.getCase(state.caseId)
	if not caseDef then
		return {}
	end

	local progressList = {}
	local emitted: { [string]: boolean } = {}

	local function emit(event: Types.TimelineEventDefinition)
		if state.discoveredTimeline[event.id] and not emitted[event.id] then
			emitted[event.id] = true
			table.insert(progressList, toProgress(event, state.discovered))
		end
	end

	local byId: { [string]: Types.TimelineEventDefinition } = {}
	for _, event in ipairs(caseDef.timeline) do
		byId[event.id] = event
	end

	if caseDef.timelineChallengeOrder then
		for _, eventId in ipairs(caseDef.timelineChallengeOrder) do
			local event = byId[eventId]
			if event then
				emit(event)
			end
		end
	end
	-- Any discovered event not named in the challenge order (or when none is
	-- authored) follows in authored order, so nothing is ever omitted.
	for _, event in ipairs(caseDef.timeline) do
		emit(event)
	end

	return progressList
end

-- Whether this player has reconstructed the timeline.
function TimelineService.isEstablished(player: Player): boolean
	local data = PlayerDataService.get(player)
	return data ~= nil and data.caseState.timelineEstablished == true
end

-- The events as the client should currently see them: canonical chronological
-- order once established, authored challenge order until then.
function TimelineService.getDiscovered(player: Player): { Types.TimelineEventProgress }
	if TimelineService.isEstablished(player) then
		return chronological(player)
	end
	return challengeOrder(player)
end

-- The discovered events in canonical chronological order, regardless of
-- whether the player has reconstructed the puzzle yet (Phase 2P). For the
-- in-progress timeline view, use `getDiscovered` -- the puzzle order is the
-- point while it's unsolved. This is for the case's own closing record (the
-- accusation may open, M9, well before OBJ-006), which restates what
-- actually happened, in the order it happened, never the shuffled one.
function TimelineService.getChronological(player: Player): { Types.TimelineEventProgress }
	return chronological(player)
end

--[[
	Validate and record the player's reconstruction of the timeline (M5).

	The player submits an ordered list of discovered event ids. It is accepted
	only when it contains exactly the player's discovered events (no missing,
	no duplicates, nothing undiscovered) AND that order matches the canonical
	chronological order (by timeMinutes, then id). This is the whole mechanic:
	the player must reconstruct the sequence themselves -- the server never
	accepts a client's claim of correctness, only the order it computes and
	compares.

	Idempotent and permanent: once established the ordering is solved and stays
	solved; a later call is a safe no-op returning false.
]]
function TimelineService.submitSequence(player: Player, orderedIds: { string }): boolean
	local data = PlayerDataService.get(player)
	if not data then
		return false
	end
	if data.caseState.timelineEstablished then
		return false
	end

	-- A submission must be a non-empty list of strings.
	if type(orderedIds) ~= "table" or #orderedIds == 0 then
		return false
	end

	-- The discovered events, and their canonical order.
	local canonical = chronological(player)
	if #canonical == 0 then
		return false
	end

	local canonicalById: { [string]: number } = {}
	for index, event in ipairs(canonical) do
		canonicalById[event.id] = index
	end

	-- The submission must cover every discovered event exactly once.
	if #orderedIds ~= #canonical then
		return false
	end
	local seen: { [string]: boolean } = {}
	for _, id in ipairs(orderedIds) do
		if type(id) ~= "string" or seen[id] or not canonicalById[id] then
			return false
		end
		seen[id] = true
	end

	-- ... in the canonical order.
	for index, id in ipairs(orderedIds) do
		if canonicalById[id] ~= index then
			log:debug("timeline reconstruction rejected: wrong order", {
				player = player.Name,
				position = index,
			})
			return false
		end
	end

	data.caseState.timelineEstablished = true
	log:info("timeline established", { player = player.Name, events = #canonical })
	-- Notify objective progression directly and synchronously (the same
	-- pattern InteractionService uses for evidence/interaction requirements),
	-- so an objective gated on `timelineEstablished` is satisfied the instant
	-- the sequence is accepted -- deterministic and testable, not dependent on
	-- deferred event delivery. The StoryEvent is published too, for any other
	-- observer.
	ObjectiveService.recordFact(player, "Timeline", "")
	StoryEvents.publish("TimelineEstablished", player, {})
	TimelineService.sendCurrent(player)
	return true
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
		established = TimelineService.isEstablished(player),
	}
	timelineUpdatedEvent:Fire(player, payload)
end

function TimelineService.start()
	log:debug("started")
end

return TimelineService
