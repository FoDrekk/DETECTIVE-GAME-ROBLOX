--!strict
--[[
	Types
	Central type definitions for Mystery Case.
	No runtime behaviour lives here.
]]

export type GamePhase =
	"MainMenu"
	| "CaseBriefing"
	| "Investigation"
	| "CaseClosed"

export type InteractionKind =
	"Examine"
	| "Read"
	| "PickUp"
	| "Talk"

export type Importance = "Low" | "Medium" | "High" | "Critical"

export type EvidenceDefinition = {
	id: string,
	name: string,
	description: string,
	location: string,
	importance: Importance,
	-- Optional, case-authored investigative detail. All fields are generic and
	-- data-driven; services never branch on specific case values.
	details: string?,
	-- Display timestamp for the clue (e.g. "11:47 PM"). Not a sort key.
	timestamp: string?,
	-- Free-form grouping label (e.g. "Communication", "Digital Activity").
	category: string?,
	-- Timeline event this evidence contributes to, if any.
	timelineEventId: string?,
	-- Other evidence ids this clue relates to (foundation only; no deductions).
	relatedEvidenceIds: { string }?,
}

export type SuspectDefinition = {
	id: string,
	name: string,
	role: string,
	alibi: string,
}

export type LocationDefinition = {
	id: string,
	name: string,
	description: string,
}

-- A single fact on the case timeline. Events are authored in case data and
-- remain hidden until one of their source evidence items is discovered.
export type TimelineEventDefinition = {
	id: string,
	-- Display timestamp (e.g. "11:42 PM").
	timestamp: string,
	-- Minutes since midnight, used for deterministic chronological ordering.
	timeMinutes: number,
	title: string,
	description: string,
	-- Evidence ids whose discovery reveals this event.
	sourceEvidenceIds: { string },
}

-- A single requirement attached to an objective.
--   evidence     : the objective advances when this evidence id is discovered.
--   interaction  : the objective advances when any interaction of this kind
--                  is performed against the named interactable (by its Name in
--                  the workspace) OR on the instance carrying this evidence id.
export type ObjectiveRequirement = {
	id: string,
	label: string,
	evidence: string?,
	interaction: InteractionKind?,
	target: string?,
}

export type ObjectiveDefinition = {
	id: string,
	title: string,
	description: string,
	-- Progress is driven by requirements; requiredEvidence/requiredInteractions
	-- are derived convenience views for services and tooling.
	requiredEvidence: { string },
	requiredInteractions: { string },
	requirements: { ObjectiveRequirement },
}

export type ObjectiveRequirementProgress = {
	id: string,
	label: string,
	completed: boolean,
}

-- Runtime objective progress sent to clients. Contains no hidden case state.
export type ObjectiveProgress = {
	id: string,
	title: string,
	description: string,
	completed: boolean,
	requirements: { ObjectiveRequirementProgress },
}

export type ObjectivePayload = {
	objective: ObjectiveProgress,
	allComplete: boolean,
}

-- Safe, spoiler-free case presentation sent to clients. Contains only the
-- briefing header. Hidden facts (evidence details, timeline events) are never
-- included here; they arrive only through discovery.
export type CaseBriefing = {
	id: string,
	title: string,
	description: string,
}

export type CasePayload = {
	briefing: CaseBriefing,
}

export type CaseDefinition = {
	id: string,
	title: string,
	description: string,
	suspects: { SuspectDefinition },
	locations: { LocationDefinition },
	evidence: { EvidenceDefinition },
	timeline: { TimelineEventDefinition },
	objectives: { ObjectiveDefinition },
}

export type DiscoveredEvidence = EvidenceDefinition & {
	discovered: boolean,
	discoveredAt: number?,
}

-- A revealed timeline event as sent to the client. Only events whose source
-- evidence has been discovered are ever included.
export type TimelineEventProgress = {
	id: string,
	timestamp: string,
	title: string,
	description: string,
	-- Display names of the revealing evidence (never hidden ids of undiscovered
	-- clues; these are only the sources that have actually been found).
	sources: { string },
}

export type TimelinePayload = {
	events: { TimelineEventProgress },
	-- Total number of events that exist for the case (not hidden content).
	totalEvents: number,
}

export type EvidenceState = {
	[string]: DiscoveredEvidence,
}

export type PlayerCaseState = {
	caseId: string,
	discovered: EvidenceState,
	-- Revealed timeline event ids. An event is revealed once any of its source
	-- evidence has been discovered.
	discoveredTimeline: { [string]: boolean },
	-- objectiveProgress[objectiveId][requirementId] = completed
	objectiveProgress: { [string]: { [string]: boolean } },
	-- Objectives already reported complete, so completion fires exactly once.
	completedObjectives: { [string]: boolean },
	startedAt: number,
}

export type PlayerData = {
	userId: number,
	name: string,
	phase: GamePhase,
	caseState: PlayerCaseState,
	createdAt: number,
}

-- Interaction contract passed over the network (client -> server).
export type InteractionRequest = {
	instance: Instance,
	kind: InteractionKind,
}

-- Interaction prompt shown to the client for a nearby object.
export type InteractionPromptData = {
	instance: Instance,
	kind: InteractionKind,
	label: string,
	key: string,
}

export type EvidencePayload = {
	evidence: DiscoveredEvidence,
	totalDiscovered: number,
	totalEvidence: number,
	-- The timeline event revealed by this discovery, if it revealed one.
	revealedEvent: TimelineEventProgress?,
}

return {}
