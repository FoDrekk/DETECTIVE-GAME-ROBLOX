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
	-- Other evidence ids this clue relates to. Authored only where the
	-- relationship is already implied by existing case facts; surfaced in the
	-- evidence panel / case file as a cross-reference, never as a conclusion.
	relatedEvidenceIds: { string }?,
	-- Optional: where to place a physical, code-spawned interactable prop for
	-- this evidence in the current office environment, for evidence that has
	-- no hand-placed counterpart in the Studio-authored `assets/Office.rbxm`.
	-- Mirrors `SuspectDefinition.npcPlacement` exactly. Absent means the
	-- evidence must already exist as a Studio-authored interactable (as
	-- EV-001/002/003 do). Purely technical staging, not story content.
	propPlacement: {
		position: Vector3,
		lookAt: Vector3?,
	}?,
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
	-- Optional: where to place a physical nameplate/sign for this location in
	-- the current office environment (M3). Absent means no sign is spawned.
	-- Mirrors SuspectDefinition.npcPlacement -- purely technical staging.
	-- `text` is the sign's own text -- deliberately separate from `name`
	-- (the location's identity, e.g. "Office") since a door nameplate reads
	-- the occupant's name, not the room's.
	signPlacement: {
		position: Vector3,
		lookAt: Vector3?,
		text: string,
	}?,
}

-- Authored flavour text for a non-evidence interactable (Phase 2O). Keyed by
-- the interactable instance's Name in the authored environment (e.g.
-- "CoffeeCup"), since that is what the environment exposes. Applying one
-- sets the object's `ObservationText` attribute at runtime; it creates no
-- evidence, timeline, objective or reasoning state. An entry whose instance
-- is not present is simply skipped -- purely additive.
export type ObservationDefinition = {
	instanceName: string,
	text: string,
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
-- gate that must be satisfied for the requirement to advance (see
-- ObjectiveService.requirementSatisfied). All present gates are ANDed
-- together against a single observed event:
--   evidence     : the objective advances when this evidence id is discovered.
--   interaction  : the objective advances only when an interaction of this
--                  kind was performed.
--   target       : the objective advances only when the interacted
--                  instance's Name matches this value. For requirements that
--                  are not evidence-specific (e.g. "talk to the named
--                  interactable").
--   contradiction: the objective advances once this contradiction id is
--                  unlocked in the player's own authoritative state (Phase
--                  2J) -- checked live, not against a one-shot event, so it
--                  is satisfied correctly however the contradiction and this
--                  objective's own unlock happen to be ordered.
--   deduction    : same as `contradiction`, for a deduction id. CASE-001's
--                  OBJ-004 uses this (Phase 2M) via DEDUCT-001; the gate is
--                  generic and hardcodes no case id.
--   timelineEstablished : the objective advances once this player has
--                  successfully reconstructed the case timeline (M5). Checked
--                  live against the player's own state, like the reasoning
--                  gates above, so ordering never matters.
export type ObjectiveRequirement = {
	id: string,
	label: string,
	evidence: string?,
	interaction: InteractionKind?,
	target: string?,
	contradiction: string?,
	deduction: string?,
	timelineEstablished: boolean?,
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
-- conflict, only all be known. `label` names the conclusion.
export type DeductionDefinition = {
	id: string,
	label: string,
	requiredFacts: { FactReference },
}

-- A suspect the player may formally accuse once every objective is complete.
-- An accusation never asserts a new story fact: `supportedBy` only lists
-- already-authored contradiction/deduction ids that, when the player has
-- actually unlocked them, make accusing this suspect consistent with the
-- evidence they gathered. An accusation with an empty/absent `supportedBy`
-- is one the evidence does not single out -- still selectable, and honestly
-- reported as unsupported, never presented as established fact.
export type AccusationDefinition = {
	id: string,
	suspectId: string,
	label: string,
	supportedBy: {
		contradictions: { string }?,
		deductions: { string }?,
	}?,
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
	-- True only when the player has no active objective left after this
	-- update -- every currently-authored objective in the case is complete
	-- (Phase 2K). Distinct from `objective.completed`, which is about this
	-- one objective only.
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
	-- Authored flavour text for non-evidence interactables, applied at
	-- runtime by instance name (Phase 2O). Optional and additive.
	observations: { ObservationDefinition }?,
	evidence: { EvidenceDefinition },
	timeline: { TimelineEventDefinition },
	-- M5: the order in which a not-yet-reconstructed timeline presents its
	-- events to the player (a list of timeline event ids). Deliberately
	-- different from chronological order so reconstructing it is a real
	-- puzzle. Optional: absent means the authored `timeline` array order is
	-- used as-is. Never affects which events exist or how they sort once the
	-- player has established the sequence.
	timelineChallengeOrder: { string }?,
	objectives: { ObjectiveDefinition },
	conversations: { ConversationDefinition },
	statements: { StatementDefinition },
	contradictions: { ContradictionDefinition },
	deductions: { DeductionDefinition },
	-- Suspects the player may formally accuse once the investigation is
	-- complete. Optional: a case without any accusation data simply cannot be
	-- concluded by accusation (Phase 2N).
	accusations: { AccusationDefinition }?,
	-- The true answer (M2). Server-only: case definitions live in
	-- ServerStorage and this is only ever sent inside the closing summary,
	-- after the player has committed to an accusation.
	solution: CaseSolution?,
}

export type CaseSolution = {
	culpritSuspectId: string,
	-- What actually happened, told to the player at the close.
	reveal: string,
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
	-- Whether this player has reconstructed the timeline (M5). While false the
	-- events are delivered in the authored challenge order for the player to
	-- arrange; once true they are delivered in canonical chronological order.
	established: boolean,
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
	-- The accusation id this player has formally made, if any. Owned by
	-- AccusationService (Phase 2N); never set directly by any other system.
	-- Once set it is permanent (an accusation is a commitment).
	accusationId: string?,
	-- Whether this player has successfully reconstructed the case timeline
	-- (M5). Owned by TimelineService; never set directly by any other system.
	-- Once true it stays true (a solved ordering is not un-solved).
	timelineEstablished: boolean?,
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
	-- Display names of this evidence's authored `relatedEvidenceIds` that the
	-- player has already discovered. Presentational cross-reference only;
	-- undiscovered related evidence is never included.
	related: { string }?,
}

-- Authored, non-evidence description shown when the player examines a
-- flavour object that carries no evidence (Phase 2O). Purely presentational:
-- it creates no evidence, timeline, objective, or reasoning state, and never
-- comes from hidden case data.
export type ObservationPayload = {
	title: string,
	body: string,
}

-- A single unlocked statement as sent to the client. `text` is resolved
-- server-side from the source suspect's authored data at unlock time.
export type StatementPayload = {
	id: string,
	suspectId: string,
	-- Resolved live from the source suspect's own authored `name`, same as
	-- `text` is resolved from `alibi` -- never a second copy of it. Lets a
	-- client with more than one unlocked statement (Phase 2I) show which
	-- suspect each one belongs to.
	suspectName: string,
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

-- A discovered evidence item and the display names of its already-discovered
-- related evidence, for the case file's cross-reference section. Only ever
-- built from already-discovered evidence, so it can never leak a hidden clue.
export type RelatedEvidencePayload = {
	id: string,
	name: string,
	related: { string },
}

-- The player's complete currently-authorized reasoning state. Never
-- includes a locked contradiction/deduction or a statement that has not
-- been unlocked -- this is the only shape ReasoningService ever sends.
export type ReasoningPayload = {
	statements: { StatementPayload },
	contradictions: { ContradictionPayload },
	deductions: { DeductionPayload },
	-- Discovered evidence that authors `relatedEvidenceIds`, with the names of
	-- the related items already discovered. Cross-reference only.
	relatedEvidence: { RelatedEvidencePayload },
}

-- A single suspect option in the accusation picker (Phase 2N). `suspectId`/
-- `suspectName`/`label` are all presentation data the player already knows
-- (the suspects are visible in the world and their names are on their
-- nametags); nothing here reveals which accusation is supported by the
-- evidence -- that is decided server-side only after the player chooses.
export type AccusationOption = {
	id: string,
	suspectId: string,
	suspectName: string,
	-- The suspect's authored role (e.g. "Spouse"); public case data.
	suspectRole: string?,
	label: string,
}

-- The accusation picker's spoiler-safe state, sent to a client only once
-- every objective is complete. `selected` is present once this player has
-- made an accusation. Never carries the answer (which option is supported).
export type AccusationPayload = {
	options: { AccusationOption },
	selected: AccusationOption?,
}

-- How an accepted accusation relates to the facts the player actually
-- gathered. `supported` is true only when every contradiction/deduction the
-- accusation names has actually been unlocked by this player -- never a
-- claim that the accusation is "correct", only that the evidence they found
-- is consistent with it. `basedOn` lists those unlocked display names.
export type AccusationResolution = {
	id: string,
	suspectId: string,
	suspectName: string,
	label: string,
	supported: boolean,
	basedOn: { string },
}

-- The summary sent once the server accepts the player's conclusion of the
-- investigation (Phase 2L). Every count is a real total, not a hardcoded
-- CASE-001 number. `accusation` (2N) is the suspect this player accused and
-- whether the evidence they unlocked supports it; `timeline`/`contradiction`
-- (2O) restate only facts the player actually discovered; `verdict` (M2) is
-- the case's true answer, revealed only now that the player has committed.
export type CaseClosedSummary = {
	objectivesCompleted: number,
	objectivesTotal: number,
	evidenceExamined: number,
	evidenceTotal: number,
	contradictionsIdentified: number,
	accusation: AccusationResolution?,
	timeline: { TimelineEventProgress },
	contradiction: ContradictionPayload?,
	-- Present once the player has accused and the case authors a solution.
	verdict: CaseVerdict?,
}

-- Whether the player's accusation named the culprit, and what happened.
export type CaseVerdict = {
	correct: boolean,
	culpritName: string,
	reveal: string,
}

return {}
