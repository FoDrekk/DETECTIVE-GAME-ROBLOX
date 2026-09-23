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
	-- Optional: where to place a physical NPC for this suspect in the
	-- current office environment. Absent means no NPC is spawned for this
	-- suspect. Purely technical staging data, not story content.
	npcPlacement: {
		position: Vector3,
		lookAt: Vector3?,
	}?,
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

-- A single requirement attached to an objective. Every non-nil field is a
-- gate that must match the observed interaction for the requirement to
-- advance (see ObjectiveService.requirementSatisfied):
--   evidence     : the objective advances when this evidence id is discovered.
--   interaction  : the objective advances only when an interaction of this
--                  kind was performed.
--   target       : the objective advances only when the interacted
--                  instance's Name matches this value. For requirements that
--                  are not evidence-specific (e.g. "talk to the named
--                  interactable").
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
	-- Objective ids that must already be completed before this objective can
	-- become active. Absent/empty means no prerequisite (available from the
	-- start, subject to authored order).
	prerequisites: { string }?,
}

-- A single line in a linear conversation. `next` is the following node's
-- id; nil marks the final line -- continuing past it completes the
-- conversation. `statementId` is unlocked (server-side) the moment this
-- node is reached. No branching/choices yet: this phase is deterministic
-- and linear only.
export type DialogueNodeDefinition = {
	id: string,
	speaker: string,
	text: string,
	next: string?,
	statementId: string?,
}

-- A suspect's conversation: a small graph of DialogueNodeDefinitions.
export type ConversationDefinition = {
	suspectId: string,
	startNodeId: string,
	nodes: { [string]: DialogueNodeDefinition },
}

-- A single piece of unlockable investigative information tied to a suspect.
-- Content is never duplicated here: the client payload is built by reading
-- the suspect's own authored fields (e.g. alibi) at unlock time, so a
-- statement can never drift from the suspect data it comes from.
export type StatementDefinition = {
	id: string,
	suspectId: string,
	label: string,
}

-- A reference to an already-discovered/unlocked fact, by kind and id.
-- Never a copy of the fact's content -- always resolved live from the
-- owning service (EvidenceService for "Evidence", ConversationService for
-- "Statement") so it can never drift and can never be forged by a client.
export type FactReference = {
	kind: "Evidence" | "Statement",
	id: string,
}

-- Two independently discovered/unlocked facts that conflict. Deterministic
-- and config-driven: unlocked only once BOTH referenced facts are true for
-- a player, never inferred from text. `reason` is an optional short label
-- for why they conflict (not a place to author new case narrative -- this
-- phase's real case data does not use it; see ARCHITECTURE.md).
export type ContradictionDefinition = {
	id: string,
	label: string,
	left: FactReference,
	right: FactReference,
	reason: string?,
}

-- A conclusion unlocked once every one of `requiredFacts` is discovered/
-- unlocked. Distinct from a contradiction: the facts do not need to
-- conflict, only all be known. No conclusion text is authored on the
-- definition itself -- see ARCHITECTURE.md for why this phase ships no
-- production deduction content.
export type DeductionDefinition = {
	id: string,
	label: string,
	requiredFacts: { FactReference },
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
	conversations: { ConversationDefinition },
	statements: { StatementDefinition },
	contradictions: { ContradictionDefinition },
	deductions: { DeductionDefinition },
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
	-- The player's current conversation, if any. Authoritative; the client
	-- never supplies or infers this.
	activeConversation: { suspectId: string, nodeId: string }?,
	-- Suspect ids whose conversation has already been completed once, so
	-- completion fires exactly once (mirrors completedObjectives).
	completedConversations: { [string]: boolean },
	-- Statement ids unlocked for this player so far.
	unlockedStatements: { [string]: boolean },
	-- Contradiction/deduction ids unlocked for this player so far. Evaluated
	-- and owned by ReasoningService; never set directly by any other system.
	unlockedContradictions: { [string]: boolean },
	unlockedDeductions: { [string]: boolean },
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

-- A single unlocked statement as sent to the client. `text` is resolved
-- server-side from the source suspect's authored data at unlock time.
export type StatementPayload = {
	id: string,
	suspectId: string,
	label: string,
	text: string,
}

-- Spoiler-safe view of the player's current dialogue step. Never includes
-- future nodes, the raw `next` pointer, or anything beyond what is needed
-- to render this one line.
export type DialoguePayload = {
	active: boolean,
	suspectId: string?,
	suspectName: string?,
	nodeId: string?,
	speaker: string?,
	text: string?,
	canContinue: boolean,
	completed: boolean,
	-- Present only on the turn a statement is newly unlocked.
	unlockedStatement: StatementPayload?,
}

-- An unlocked contradiction as sent to the client. `leftSummary`/
-- `rightSummary` are display names resolved server-side from the two
-- referenced facts -- always safe to include because a contradiction is
-- only ever unlocked once both facts are themselves already unlocked.
export type ContradictionPayload = {
	id: string,
	label: string,
	reason: string?,
	leftSummary: string,
	rightSummary: string,
}

-- An unlocked deduction as sent to the client. `basedOn` lists display
-- names of the contributing facts, for the same reason as above.
export type DeductionPayload = {
	id: string,
	label: string,
	basedOn: { string },
}

-- The player's complete currently-authorized reasoning state. Never
-- includes a locked contradiction/deduction or a statement that has not
-- been unlocked -- this is the only shape ReasoningService ever sends.
export type ReasoningPayload = {
	statements: { StatementPayload },
	contradictions: { ContradictionPayload },
	deductions: { DeductionPayload },
}

return {}
