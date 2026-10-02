--!strict
--[[
	StoryEvents
	Minimal, generic server-side event dispatch for future story systems
	(dialogue, contradictions, deductions, etc.) to observe authoritative
	game facts without the systems that produce those facts knowing they
	exist.

	This does NOT replace the existing gameplay pipeline (Interaction ->
	Evidence -> Timeline -> Objective), which stays direct and synchronous
	for correctness. StoryEvents is a strictly additive, fire-and-forget
	observation layer: publishers never depend on subscribers, and nothing
	in the existing pipeline requires this module to function.

	Server-only by placement (src/server is not reachable from the client),
	so nothing published here can leak hidden state to a client.

	Extend `StoryEventKind` only when a system actually publishes that kind.
	This is not a place to pre-declare future story content.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))

local log = Logger.scoped("StoryEvents")

local StoryEvents = {}

export type StoryEventKind =
	"EvidenceDiscovered"
	| "ObjectiveCompleted"
	| "ConversationStarted"
	| "ConversationCompleted"
	| "StatementUnlocked"
	| "ContradictionUnlocked"
	| "DeductionUnlocked"
	| "AccusationMade"
	| "TimelineEstablished"
	| "CutsceneFinished"

local bindables: { [string]: BindableEvent } = {}

local function bindable(kind: string): BindableEvent
	local existing = bindables[kind]
	if existing then
		return existing
	end
	local event = Instance.new("BindableEvent")
	bindables[kind] = event
	return event
end

function StoryEvents.on(
	kind: StoryEventKind,
	callback: (player: Player, data: { [string]: any }) -> ()
): RBXScriptConnection
	return bindable(kind).Event:Connect(callback)
end

-- Publish a story event. Fire-and-forget: publishers never know or care
-- whether anything is listening.
function StoryEvents.publish(kind: StoryEventKind, player: Player, data: { [string]: any })
	log:debug("published", { kind = kind, player = player.Name })
	bindable(kind):Fire(player, data)
end

return StoryEvents
