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
	-- no authored counterpart in the generated office.
	-- Mirrors `SuspectDefinition.npcPlacement` exactly. Absent means the
	-- evidence must already exist as a Studio-authored interactable (as
	-- EV-001/002/003 do). Purely technical staging, not story content.
	propPlacement: {
		position: Vector3,
		lookAt: Vector3?,
		-- Which PropKit model to build for it (e.g. "Printout",
		-- "EspressoCup"); absent builds a plain panel.
		style: string?,
		-- The prop stays out of the world until every condition
		-- holds for the investigator (same condition language as dialogue),
		-- then appears and stays for the rest of the case (RevealService).
		-- Only the prop is gated: the evidence itself can still be reached
		-- another way (e.g. a line of dialogue that grants it). Absent means
		-- the prop is there from the start, as before.
		revealWhen: { DialogueCondition }?,
		-- The prompt the prop shows ("Read Unlocked Phone"); absent
		-- derives it from the evidence's name, as before.
		label: string?,
	}?,
	-- Examining (or being handed) this evidence also hands over
	-- these others, through EvidenceService.grant, in the same moment: one
	-- object, one action, several clues (an unlocked phone gives the message
	-- and the watch data). Already-known ones are skipped. The readout names
	-- the ones newly added (EvidencePayload.alsoAdded).
	grantsEvidence: { string }?,
	-- This evidence is a Studio-authored (or baked) interactable
	-- that already exists in the office and is named `instanceName` -- a
	-- flavour object promoted to a clue. At runtime OfficeRoom gives that
	-- instance this evidence's id (and `label` as its prompt, if given),
	-- exactly as observations are applied by instance name. Purely technical
	-- staging, like propPlacement; mutually exclusive with it.
	bindTo: {
		instanceName: string,
		label: string?,
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
	-- Optional: how the NPC looks. Absent falls back to a plain default
	-- avatar. `body` names a package in Config.Characters.Bodies; `hair` is a
	-- verified Roblox catalog asset id, recoloured to `hairColor`. The face is
	-- the avatar's default head. Purely presentation.
	appearance: SuspectAppearance?,
}

export type SuspectAppearance = {
	body: string,
	-- Catalog hair accessory id; absent for a shaved head.
	hair: number?,
	hairColor: Color3,
	skin: Color3,
	-- Worn colours: shirt/jacket (torso and sleeves), trousers, shoes.
	top: Color3,
	bottom: Color3,
	shoes: Color3,
	-- Small, code-built wardrobe details that make a character readable at
	-- a glance (keys into SuspectSpawner's detail builders, e.g. "Tie",
	-- "Scarf", "SecurityPatch"), and the colour they use.
	details: { string }?,
	accent: Color3?,
}

export type LocationDefinition = {
	id: string,
	name: string,
	description: string,
	-- Optional: where to place a physical nameplate/sign for this location in
	-- the current office environment. Absent means no sign is spawned.
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

-- Authored flavour text for a non-evidence interactable. Keyed by
-- the interactable instance's Name in the authored environment (e.g.
-- "CoffeeCup"), since that is what the environment exposes. Applying one
-- sets the object's `ObservationText` attribute at runtime; it creates no
-- evidence, timeline, objective or reasoning state. An entry whose instance
-- is not present is simply skipped -- purely additive.
-- `label` optionally overrides the interaction prompt itself
-- (e.g. an authored "Examine Coffee Cup" that reads as real evidence next to
-- the actual clue): applying one sets `PromptLabel` alongside `ObservationText`.
-- Absent leaves the authored asset's own prompt label untouched.
export type ObservationDefinition = {
	instanceName: string,
	text: string,
	label: string?,
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
--                  unlocked in the player's own authoritative state.
--                  Checked live, not against a one-shot event, so it
--                  is satisfied correctly however the contradiction and this
--                  objective's own unlock happen to be ordered.
--   deduction    : same as `contradiction`, for a deduction id. CASE-001's
--                  OBJ-004 uses this via DEDUCT-001; the gate is
--                  generic and hardcodes no case id.
--   timelineEstablished : the objective advances once this player has
--                  successfully reconstructed the case timeline. Checked
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

-- A condition on what this player already knows or has done in dialogue.
-- Evaluated server-side against the player's own state; `negate` inverts it
-- (e.g. "only while this statement is still unknown").
--   Evidence      : evidence id discovered
--   Statement     : statement id unlocked
--   Contradiction : contradiction id unlocked
--   Deduction     : deduction id unlocked
--   Flag          : a conversation flag set by an earlier node (setFlags)
export type DialogueConditionKind = "Evidence" | "Statement" | "Contradiction" | "Deduction" | "Flag"

export type DialogueCondition = {
	kind: DialogueConditionKind,
	id: string,
	negate: boolean?,
}

-- Something the investigator can say. Offered only while every `requires`
-- condition holds; a `once` choice disappears after it has been chosen.
-- Choosing it moves the conversation to `next`.
export type DialogueChoiceDefinition = {
	id: string,
	text: string,
	next: string,
	requires: { DialogueCondition }?,
	once: boolean?,
	-- Choosing this asks the investigator to show a piece of evidence
	-- instead of moving on at once. See DialoguePresentDefinition; for a
	-- presenting choice `next` is where evidence that means nothing to this
	-- character leads.
	present: DialoguePresentDefinition?,
}

-- One piece of evidence that lands with this character. Showing
-- `evidence` while `requires` holds moves the conversation to `next`, and,
-- if `claims` names a contradiction, the investigator has just made that
-- connection themselves (ReasoningService unlocks it).
export type DialoguePresentOutcome = {
	evidence: string,
	next: string,
	requires: { DialogueCondition }?,
	claims: string?,
}

-- "show them something". `prompt` heads the evidence picker. Outcomes
-- are checked in order; evidence that matches none leads to the choice's
-- own `next`.
export type DialoguePresentDefinition = {
	prompt: string,
	outcomes: { DialoguePresentOutcome },
}

-- A single line of a conversation. `next` is the following node's id; nil
-- marks the final line -- continuing past it completes the conversation.
-- `statementId` is unlocked (server-side) the moment this node is reached.
--
-- Branching: a node with `choices` (or `choicesFrom`, which borrows another
-- node's choices so a topic can return to the question list without an
-- extra "anything else?" line) waits for the investigator to pick one of
-- the choices currently available to them. If none is available the node
-- behaves like a linear one (`next`, or the end). `setFlags`/`clearFlags`
-- let the conversation remember what happened (e.g. the investigator
-- pressed too hard) for later entries, choices and lines. `isPlayer` marks
-- a line spoken by the investigator.
--
-- `grantsEvidence` lists evidence ids discovered, server-side
-- through EvidenceService, the moment this node is reached -- evidence a
-- character hands over or shows the investigator. Discovery is idempotent,
-- so the same evidence can also be reachable by other routes (an object to
-- examine, another conversation); whichever comes first discovers it.
export type DialogueNodeDefinition = {
	id: string,
	speaker: string,
	text: string,
	next: string?,
	statementId: string?,
	grantsEvidence: { string }?,
	choices: { DialogueChoiceDefinition }?,
	choicesFrom: string?,
	setFlags: { string }?,
	clearFlags: { string }?,
	isPlayer: boolean?,
}

-- Where a conversation starts when its `requires` all hold. Entries are
-- checked in order; the first match wins, otherwise `startNodeId` is used.
-- This is how a character greets the investigator differently the second
-- time, or after being accused of lying.
export type ConversationEntry = {
	node: string,
	requires: { DialogueCondition },
}

-- A suspect's conversation: a small graph of DialogueNodeDefinitions.
export type ConversationDefinition = {
	suspectId: string,
	startNodeId: string,
	nodes: { [string]: DialogueNodeDefinition },
	entries: { ConversationEntry }?,
}

-- A single piece of unlockable investigative information tied to a suspect.
-- `text` is what the Case File records. When absent it is resolved from the
-- suspect's own `alibi` at unlock time (the original single-statement
-- contract), so an alibi statement can never drift from the suspect data.
export type StatementDefinition = {
	id: string,
	suspectId: string,
	label: string,
	text: string?,
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
	-- The investigator has to make this connection themselves -- by
	-- pairing the two facts in the case file, or by showing the evidence to
	-- the person who said it -- instead of it unlocking the moment both
	-- facts are known.
	claim: boolean?,
}

-- A conclusion unlocked once every one of `requiredFacts` is discovered/
-- unlocked. Distinct from a contradiction: the facts do not need to
-- conflict, only all be known. `label` names the conclusion.
export type DeductionDefinition = {
	id: string,
	label: string,
	requiredFacts: { FactReference },
	-- Instead of unlocking the moment its facts are known, the
	-- deduction becomes an open question in the case file that the
	-- investigator has to answer.
	question: DeductionQuestion?,
}

-- An open question in the case file. Offered once every required fact
-- is known; `answer` is the id of the right option and never leaves the
-- server.
export type DeductionQuestion = {
	prompt: string,
	options: { { id: string, text: string } },
	answer: string,
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
	-- (Cases with accusationRules.requiresCase) the deductions that
	-- stand up as this suspect's motive, and the contradictions that prove
	-- it. The investigator picks one of each from what they have
	-- established; both must be listed here for the case to hold.
	motives: { string }?,
	proofs: { string }?,
	-- What happens after accusing this suspect when they are not the
	-- culprit.
	wrongEpilogue: string?,
}

-- When an accusation may be made and what it needs.
--   opensAfter   : objective id; once it is complete the investigator may
--                  accuse, even with objectives left (absent: only once
--                  every objective is complete).
--   requiresCase : an accusation names a motive (an established deduction)
--                  and a proof (an established contradiction) as well as a
--                  suspect, and the verdict is graded on them.
export type AccusationRules = {
	opensAfter: string?,
	requiresCase: boolean?,
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
	-- update -- every currently-authored objective in the case is complete.
	-- Distinct from `objective.completed`, which is about this
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
	-- The briefing's time/place line ("12:40 AM", "Rozario & Lim ·
	-- Tingkat 9"). Optional: absent means the line is not shown.
	time: string?,
	place: string?,
}

export type CasePayload = {
	briefing: CaseBriefing,
	-- This case opens on a scene instead of the static briefing
	-- screen, so the client goes straight from the title screen to the
	-- investigation and lets the intro play. Says nothing about the scene
	-- itself: its shots only ever travel when the server starts it.
	introReplacesBriefing: boolean?,
}

export type CaseDefinition = {
	id: string,
	title: string,
	-- The briefing's story hook: a sentence or two, not a summary.
	description: string,
	-- When and where the case opens, shown under the hook.
	setting: { time: string, place: string }?,
	suspects: { SuspectDefinition },
	locations: { LocationDefinition },
	-- Authored flavour text for non-evidence interactables, applied at
	-- runtime by instance name. Optional and additive.
	observations: { ObservationDefinition }?,
	evidence: { EvidenceDefinition },
	timeline: { TimelineEventDefinition },
	-- The order in which a not-yet-reconstructed timeline presents its
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
	-- concluded by accusation.
	accusations: { AccusationDefinition }?,
	accusationRules: AccusationRules?,
	-- The true answer. Server-only: case definitions live in
	-- ServerStorage and this is only ever sent inside the closing summary,
	-- after the player has committed to an accusation.
	solution: CaseSolution?,
	-- Scripted scenes (shots, subtitles), played on the server's
	-- word by CutsceneService. Optional: a case without any has none.
	cutscenes: { CutsceneDefinition }?,
	-- The scene this case opens with. Optional: a case without one
	-- opens on its briefing, exactly as before.
	intro: CaseIntro?,
}

--[[
	The scene a case opens with. Data, so a case says "this is my
	intro" and the engine plays it: the server starts `cutsceneId` when the
	investigation begins, and the static briefing screen is skipped for a case
	whose intro replaces it (`replacesBriefing`).
]]
export type CaseIntro = {
	cutsceneId: string,
	-- The briefing screen is retired for this case: the intro does its job
	-- (CASE-001's briefing showed something the intro withholds).
	replacesBriefing: boolean?,
}

--[[
	A scripted scene. The server decides when one plays
	(CutsceneService.play) and when it is over; the client only presents
	the shots it is sent and reports reaching the end (or a skip).
	`skippable` defaults to true. `replayFrom` names the shot a replay
	starts at once this scene has been seen in the current session (e.g.
	after "Investigate again"); absent plays it from the top every time.
]]
export type CutsceneDefinition = {
	id: string,
	shots: { CutsceneShot },
	skippable: boolean?,
	replayFrom: string?,
}

-- One camera shot: a move from `from` to `to` over `duration` seconds (a
-- still shot omits `to`), with optional dips from/to black and subtitle
-- lines timed from the start of the shot.
export type CutsceneShot = {
	id: string,
	duration: number,
	camera: {
		from: CutsceneCameraPoint,
		to: CutsceneCameraPoint?,
		-- Degrees; absent keeps the player's own field of view.
		fieldOfView: number?,
		-- The field of view the move ends on (a slow push-in or pull-out).
		fieldOfViewTo: number?,
		-- How the move eases. "InOut" (the default), "Out", "In", "Linear".
		ease: string?,
		-- A hand-held sway, 0 (locked off) to 1 (a running camera).
		handheld: number?,
	},
	fadeIn: number?,
	fadeOut: number?,
	lines: { CutsceneLine }?,
	-- The set the shot is framed in. Its camera points are the set's
	-- own coordinates; the client builds the set and offsets them. Absent: the
	-- points are world coordinates (the office).
	set: string?,
	-- The look of the shot, a named preset of
	-- Config.Cutscene.LightingPresets (sky, ambient, grade, bloom). Client-side
	-- only. Absent: the world's own lighting.
	lighting: string?,
	-- The shot's depth of field.
	focus: CutsceneFocus?,
	-- Sounds fired at their own moments in the shot (named cues of
	-- Config.Audio.Cutscene: a scene never carries an asset id).
	sounds: { CutsceneSoundCue }?,
	-- Things that happen in the set at their own moments (a phone
	-- buzzing, a door sliding, a floor number changing): named actions the set
	-- knows how to perform.
	actions: { CutsceneAction }?,
	-- A card over the shot (the title card).
	titleCard: CutsceneTitleCard?,
	-- The shot hands the look to the player: the camera stays at
	-- `camera.from.position` (it cannot also move) and they turn it. Presence,
	-- not control: they still can't move (the lift).
	mouseLook: boolean?,
}

-- What is sharp in a shot. `distance` studs from the camera stays in
-- focus (with `radius` studs of depth either side); `toDistance` racks the
-- focus there over the shot. `blur` is how strongly the rest softens (0..1).
export type CutsceneFocus = {
	distance: number,
	toDistance: number?,
	radius: number?,
	blur: number?,
}

--[[
	A named cue of Config.Audio.Cutscene, played `at` seconds into its
	shot. `volume` overrides the cue's own for this shot.

	A cue whose config says `loops` is a bed (rain, traffic, the music). A bed
	keeps going across cuts for as long as each shot asks for it (rain that
	restarted on every cut would announce the edit), and fades out at the first
	shot that doesn't. `stop` ends a bed mid-shot instead of starting it (a phone
	buzzing until a hand turns it over). Any other cue is a one-shot: it plays once
	and is never carried over. `fade` is the seconds a cue takes to come in (or,
	with `stop`, to go out). `from` starts the sound that many seconds into the
	recording.
]]
export type CutsceneSoundCue = {
	at: number,
	cue: string,
	volume: number?,
	stop: boolean?,
	fade: number?,
	from: number?,
}

-- `name` is one of the actions the shot's set defines
-- (CutsceneSets); `args` are its parameters.
export type CutsceneAction = {
	at: number,
	name: string,
	args: { [string]: any }?,
}

-- A card over the shot: `title`, with an optional second line and a
-- small line over it, shown from `at` seconds into the shot for `duration`.
export type CutsceneTitleCard = {
	at: number,
	duration: number,
	title: string,
	subtitle: string?,
	kicker: string?,
}

export type CutsceneCameraPoint = {
	position: Vector3,
	lookAt: Vector3,
}

-- A subtitle: `text` shown from `at` seconds into the shot for `duration`
-- seconds, under `speaker` when given (none for captions and narration).
export type CutsceneLine = {
	at: number,
	duration: number,
	text: string,
	speaker: string?,
}

export type CaseSolution = {
	culpritSuspectId: string,
	-- What actually happened, told to the player at the close.
	reveal: string,
	-- What happened next, when the culprit was named with a case that
	-- holds (solvedEpilogue) or one that doesn't (unprovenEpilogue).
	solvedEpilogue: string?,
	unprovenEpilogue: string?,
	-- A Solved ending that reflects how far the investigation went. The
	-- first variant whose facts this player has all established replaces
	-- `solvedEpilogue`. Never changes the grade -- only what a case that
	-- already held says happened next.
	solvedVariants: { SolvedEpilogueVariant }?,
	-- A scene played once a Solved verdict is accepted, before the
	-- Case Closed screen (a dawn outro). The first entry whose facts this
	-- player has all established plays; an entry with no `requiredFacts`
	-- always matches, so put it last. Never for a case that didn't hold.
	solvedCutscenes: { SolvedCutscene }?,
}

export type SolvedEpilogueVariant = {
	requiredFacts: { FactReference },
	epilogue: string,
}

export type SolvedCutscene = {
	cutsceneId: string,
	requiredFacts: { FactReference }?,
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
	-- Whether this player has reconstructed the timeline. While false the
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
	-- `presenting` is the id of a presenting choice waiting for the
	-- investigator to pick the evidence to show.
	activeConversation: { suspectId: string, nodeId: string, presenting: string? }?,
	-- Conversation memory: flags set by dialogue nodes, and the `once`
	-- choices already used (keyed "<suspectId>/<choiceId>"). Owned by
	-- ConversationService.
	dialogueFlags: { [string]: boolean },
	usedChoices: { [string]: boolean },
	-- Suspect ids this player has spoken to at least once (a conversation
	-- was started), so a "talk to X" objective can be credited even if the
	-- conversation happened before that objective became active.
	metSuspects: { [string]: boolean },
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
	-- AccusationService; never set directly by any other system.
	-- Once set it is permanent (an accusation is a commitment).
	accusationId: string?,
	-- The motive (deduction id) and proof (contradiction id) named with
	-- the accusation, when the case requires them. Owned by
	-- AccusationService.
	accusationMotive: string?,
	accusationProof: string?,
	-- Connections that didn't hold in the case file -- pairings that
	-- don't conflict, wrong answers. Owned by ReasoningService; reported at
	-- the close.
	reasoningMistakes: number,
	-- Whether this player has successfully reconstructed the case timeline.
	-- Owned by TimelineService; never set directly by any other system.
	-- Once true it stays true (a solved ordering is not un-solved).
	timelineEstablished: boolean?,
	-- Evidence ids whose gated prop (propPlacement.revealWhen) has
	-- been revealed this case. Owned by RevealService; a reveal is never
	-- undone within a case (a replay starts a new case state).
	revealedProps: { [string]: boolean },
	-- The scene this player is watching, if any. Owned by
	-- CutsceneService. `startedAt` is the server clock when it was sent,
	-- `duration` the seconds it runs from the shot it started at, and `grace`
	-- how long after that the server stops waiting for the client.
	activeCutscene: { id: string, startedAt: number, duration: number, grace: number }?,
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
	-- True when this is an already-discovered clue being looked at again
	-- (not a new discovery).
	revisited: boolean?,
	-- True when the evidence was handed over in a conversation
	-- (DialogueNodeDefinition.grantsEvidence) rather than found by examining
	-- an object: there is nothing to frame, and the conversation announces
	-- it (DialoguePayload.grantedEvidence).
	granted: boolean?,
	-- Display names of the evidence this one handed over with it
	-- (EvidenceDefinition.grantsEvidence), for an "also added" line under the
	-- readout. Only ones newly added; never anything already known.
	alsoAdded: { string }?,
}

-- Authored, non-evidence description shown when the player examines a
-- flavour object that carries no evidence. Purely presentational:
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
	-- client with more than one unlocked statement show which
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
	-- The suspect's public role (e.g. "Night Security"), for the name plate.
	suspectRole: string?,
	nodeId: string?,
	speaker: string?,
	text: string?,
	-- True when the investigator speaks this line.
	isPlayer: boolean?,
	canContinue: boolean,
	completed: boolean,
	-- Present only on the turn a statement is newly unlocked.
	unlockedStatement: StatementPayload?,
	-- Display names of evidence this line just handed over,
	-- present only on the turn it was newly discovered.
	grantedEvidence: { string }?,
	-- The questions the investigator may ask now (ids + words only; never
	-- where they lead). Present only while the line is waiting for a choice.
	choices: { DialogueChoicePayload }?,
	-- What the investigator just said to get this line, if it followed a
	-- choice -- shown above the reply so the exchange reads as dialogue.
	prompt: string?,
	-- The name of the evidence the investigator just showed, if this
	-- line is the reaction to it.
	presented: string?,
	-- Present while the investigator is choosing what to show: the
	-- picker's heading and the evidence they have (ids and names only).
	present: DialoguePresentPayload?,
}

-- A scene for the client to play, or (active = false) the
-- server saying the current one is over. `shots` are only those from the
-- shot the scene starts at (a replay may start part-way through).
export type CutscenePayload = {
	active: boolean,
	id: string?,
	shots: { CutsceneShot }?,
	skippable: boolean?,
	-- This scene is the case's intro, so it is skipped by holding
	-- (a hold can't happen by accident) and hands over to the investigation
	-- rather than returning to whatever was on screen before it.
	isIntro: boolean?,
}

export type DialoguePresentPayload = {
	prompt: string,
	options: { { id: string, name: string } },
}

export type DialogueChoicePayload = {
	id: string,
	text: string,
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
	-- The evidence this player has found (for pairing against a
	-- statement), and the questions they can answer now.
	evidence: { EvidenceFactPayload },
	openQuestions: { DeductionQuestionPayload },
}

-- A discovered piece of evidence as a fact the case file can pair.
export type EvidenceFactPayload = {
	id: string,
	name: string,
	details: string,
}

-- An open question, without its answer.
export type DeductionQuestionPayload = {
	id: string,
	prompt: string,
	options: { { id: string, text: string } },
	basedOn: { string },
}

-- What the server made of a pairing or an answer.
--   claimed / correct   : the connection holds (a new contradiction or
--                         deduction; `label` names it)
--   already             : it was already established
--   no-conflict / wrong : it doesn't hold (no spoiler: nothing else said)
--   cooldown            : too soon after a miss
--   invalid             : not something this player can pair or answer
export type ReasoningFeedbackPayload = {
	kind: "Claim" | "Answer",
	result: "claimed" | "correct" | "already" | "no-conflict" | "wrong" | "cooldown" | "invalid",
	label: string?,
}

-- A single suspect option in the accusation picker. `suspectId`/
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
	-- Whether this player may accuse now (server-decided).
	open: boolean,
	-- When true the accusation also needs a motive and a proof, chosen
	-- from what the player has established (the lists below). Neither list
	-- says which entry fits which suspect.
	requiresCase: boolean,
	motives: { { id: string, label: string } },
	proofs: { { id: string, label: string } },
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
-- investigation. Every count is a real total, not a hardcoded
-- CASE-001 number. `accusation` is the suspect this player accused and
-- whether the evidence they unlocked supports it; `timeline`/`contradiction`
-- restate only facts the player actually discovered; `verdict` is
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
	-- Connections that didn't hold along the way.
	mistakes: number,
	-- Whether this player put the night in its real order
	-- (TimelineService.isEstablished), which never changes the grade but
	-- is worth showing since it's easy to skip.
	timelineReconstructed: boolean,
}

-- Whether the player's accusation named the culprit, and what happened.
export type CaseVerdict = {
	correct: boolean,
	culpritName: string,
	reveal: string,
	-- How the case stood up.
	--   Solved   : the culprit, with a motive and a proof that hold
	--   Unproven : the culprit, but the case named doesn't hold
	--   Wrong    : someone else
	-- Cases without accusationRules.requiresCase grade Solved or Wrong.
	grade: "Solved" | "Unproven" | "Wrong",
	-- What happened next, for this grade (authored; may be absent).
	epilogue: string?,
	-- For Unproven/Wrong only -- one sentence on which of the named
	-- motive/proof didn't hold, computed only from data already authored on
	-- the accusation. Never the true motive/proof; nil for Solved, and nil
	-- for a case that doesn't grade on motive/proof at all.
	shortfall: string?,
}

return {}
