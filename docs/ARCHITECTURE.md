# Mystery Case — Architecture

Source lives on disk and is synced into Studio via Rojo. Server is authoritative
for gameplay/state/evidence/progression; the client handles input, camera and
presentation only.

## Layers

| Layer | Location | Responsibility |
|-------|----------|----------------|
| Server | `src/server` | Authoritative state, evidence, phases, world integration |
| Client | `src/client` | Input, camera, presentation, remote listeners |
| Shared | `src/shared` | Types, config, state machine, signals, contracts, logger, utilities |
| Config | `src/config` | Case data and the case registry (pure data). Server-only (M2): case definitions carry the solution, so they map under `ServerStorage`, never `ReplicatedStorage`. |
| UI | `src/ui` | Reusable theme-driven UI component factories |
| Tests | `tests/` | Headless unit tests (mapped under ServerStorage) |

Instances are mapped by `default.project.json`:

```
ReplicatedStorage.Shared      <- src/shared
ReplicatedStorage.UI          <- src/ui      (requireable UI factories)
ServerScriptService.Server    <- src/server  (Script, children = services)
StarterPlayer...Client        <- src/client  (LocalScript, children = modules)
Workspace.Office              <- assets/Office.rbxm  (Studio-authored world)
ServerStorage.Config          <- src/config  (case data; server-only, M2)
ServerStorage.UnitTest        <- tests/      (RunUnitTest + Cases + Fixtures)
ServerScriptService.UnitTestRunner <- tests/UnitTestRunner.server.luau (Disabled)
```

## Foundation contracts (Phase 2E)

### Shared interactable contract
`src/shared/Interactable.luau` is the single source of truth for interactables.
Both `InteractionService` (server validation) and `InteractionController`
(client presentation) parse attributes through `Interactable.describe`, so the
two sides can never disagree. Attribute contract: `InteractionKind`,
`PromptLabel`, optional `EvidenceId`, optional `ReadableText`, optional
`ObservationText` (Phase 2O — authored flavour text for a non-evidence
object; parsed into `Descriptor.observation`), optional `SuspectId`
(identifies which suspect a Talk-kind interactable represents; since Phase
2G, `InteractionService`'s Talk handler consumes this to start a
conversation). Enabled kinds are declared once in `Interactable.EnabledKinds`.

### Logging
`src/shared/Logger.luau` provides scoped, severity-based logging
(`DEBUG`/`INFO`/`WARN`/`ERROR`). Use `Logger.scoped("ServiceName")`; the minimum
severity comes from `Config.Logging.MinSeverity` (DEBUG suppressed by default).
Recoverable failures use `:warn`/`:error`; unrecoverable configuration errors use
`Logger.fatal`, which raises loudly. Never log hidden case/story data.

### Service lifecycle
Services expose a predictable `start()` and are initialised by
`init.server.luau` in dependency order: environment → remotes → stateless
services → event bridges → phase machine → player lifecycle → request handlers.
`init.server.luau` validates configuration up front (`Logger.fatal` if the active
case is not registered). Startup never fails silently.

### Signal naming
`CaseBriefingLoaded` carries a spoiler-safe `Types.CasePayload`
(`{ briefing: CaseBriefing }`). The older `CaseLoaded` name is gone — one signal,
one meaning.

### Tests
`tests/` maps to `ServerStorage.UnitTest`. Run headlessly in Play via:
`require(ServerStorage.UnitTest.RunUnitTest)(filter?, timeout?)`.
Results print `[PASS]`/`[FAIL]`/`[TIMEOUT]` plus a `[SUMMARY]` line.
`UnitTestRunner` is a disabled Script for manual runs.

Mock player UserIds come from `t.nextUserId()` (Phase 2G.1), a single
ever-decrementing counter owned by `RunUnitTest.luau` itself — always
negative, so a mock id can never collide with a real `Player.UserId`
(always positive), and never reset within a session, so a second
`RunUnitTest()` call in the same Play session can never collide with mock
`PlayerDataService` state an earlier call left behind. Each run also clears
the `PlayerDataService` entries for the mock ids it dispensed once it
finishes, so repeated runs in one session stay clean rather than merely
non-colliding. No test file keeps its own local UserId counter.

## World vs. logic split

The office *environment* is Studio-authored and versioned as a binary model
(`assets/Office.rbxm`), mapped by Rojo to `Workspace.Office`. It owns geometry,
furniture, props, lighting fixtures and the spawn. Gameplay *logic* (evidence,
objectives, interaction, state, camera, UI) stays in Luau services.

`OfficeRoom.luau` no longer builds geometry. It only removes the default
Baseplate/SpawnLocation, applies the runtime evening lighting/atmosphere, and
validates that the authored interactables satisfy the gameplay contract.

## Server services

- **PlayerDataService** — in-memory `PlayerData` per player, `PlayerCaseState`.
- **CaseService** — case definitions + per-player progress payloads, plus
  read-only accessors for a case's suspects and locations
  (`getSuspects`/`getSuspect`/`getLocations`/`getLocation`). Validates at boot
  that every objective `prerequisites` reference resolves to a real objective
  in the same case (warns, does not crash, on a dangling reference).
- **EvidenceService** — authoritative discovery; rejects duplicates. Reveals the
  matching timeline event on first discovery, then publishes `StoryEvents`
  `"EvidenceDiscovered"`.
- **TimelineService** — data-driven case timeline. Events stay hidden until one
  of their source evidence items is discovered. Since M5 the timeline is also a
  player mechanic: until the player reconstructs it, events are delivered in
  the case's authored `timelineChallengeOrder` (deliberately non-chronological)
  and `submitSequence` accepts an ordered id list only when it matches the
  canonical chronological order the server computes. Owns
  `PlayerCaseState.timelineEstablished`; on success calls
  `ObjectiveService.recordFact(player, "Timeline", "")` directly (so the gated
  objective completes synchronously) and publishes `StoryEvents`
  `"TimelineEstablished"`. Once established, events are delivered in
  chronological order (see below).
- **ObjectiveService** — data-driven objective tracking, including multi-
  objective sequencing (see below). Evaluates generic evidence/interaction/
  target/contradiction/deduction requirements from case data; owns
  completion; publishes `StoryEvents` `"ObjectiveCompleted"`; subscribes to
  `StoryEvents` `"ContradictionUnlocked"`/`"DeductionUnlocked"` (Phase 2J).
- **ConversationService** (Phase 2G) — authoritative, data-driven suspect
  conversations. Owns `activeConversation`/`completedConversations`/
  `unlockedStatements` per player; publishes `StoryEvents`
  `"ConversationStarted"`/`"ConversationCompleted"` (see below).
- **ReasoningService** (Phase 2H) — evaluates contradiction/deduction unlock
  against already-discovered evidence and already-unlocked statements. Owns
  `unlockedContradictions`/`unlockedDeductions` per player; publishes
  `StoryEvents` `"ContradictionUnlocked"`/`"DeductionUnlocked"` (see below).
- **AccusationService** (Phase 2N) — owns the player's formal accusation: a
  permanent, per-player choice made only once every objective is complete.
  Records `PlayerCaseState.accusationId`; publishes `StoryEvents`
  `"AccusationMade"`; exposes a spoiler-safe picker payload and the factual,
  evidence-derived resolution the closing screen shows (see below).
- **InteractionService** — validates interaction requests and dispatches to
  per-kind handlers (Examine/Read/PickUp/Talk). Talk starts a conversation via
  `ConversationService`.
- **GameStateService** — shared phase machine (MainMenu/CaseBriefing/
  Investigation/CaseClosed), broadcasts phase changes. `requestConclude`
  (Phase 2L) gates the Investigation -> CaseClosed edge with a player-specific
  gameplay authorization check on top of the state machine's own graph
  validation (see below).
- **OfficeRoom** — runtime lighting/spawn cleanup, evidence props (look from
  `PropKit` by `propPlacement.style`), location signs, and (in `finalize`,
  after every environment module has built) observations and authored-content
  validation for the Studio-built `Workspace.Office` environment.
- **OfficeDetailing** — runtime corrections and crime-scene staging on the
  authored office: spawn, Daniel's desk settled onto the floor, reception
  partition, meeting-room glazing, dropped ceilings, scene tape, chalk
  outline, evidence markers, desk-prop styling.
- **OfficeInterior** (M7) — finishes, suspended ceiling, after-hours
  lighting plan, furniture (replacing the shell's block furniture) and room
  dressing; tags three flavour props as interactables.
- **PropKit** (M7) — the furniture/fixture builders OfficeInterior and
  OfficeRoom use: parts + Roblox built-in PBR materials only, one palette,
  one invisible collider per prop, shadows only on large parts.
- **SuspectSpawner** (Phase 2G) — runtime placement of a physical NPC for each
  suspect that authors an `npcPlacement` (see below).
- **StoryEvents** (Phase 2F) — minimal, generic server-only publish/subscribe
  for future story systems to observe authoritative facts (see below).

## Client modules

- **InputController** — centralised input (E = interact / continue, T =
  timeline, C = case file, Q = accusation once offered). Escape is also bound,
  but live Roblox clients reserve it for the system menu and never deliver it
  to the game, so no panel relies on it: every panel closes with its own key,
  the evidence readout with `[E] Continue` (or a click), and
  `GuiService.MenuOpened` runs the same close-all path (M1). Each action is
  bound to its keyboard key and its gamepad button (from `InputGlyphs`), and
  `InputController.invoke(action)` lets touch buttons trigger the very same
  callbacks — one code path for all three input schemes.
- **InputHints** — tracks the active scheme (keyboard / gamepad / touch) from
  the player's last input (or the `InputSchemeOverride` attribute for QA) and
  keeps hint labels in sync via `InputHints.bind`, which only ever sets text.
  The per-scheme bindings and glyphs themselves are the pure, unit-tested
  shared module `InputGlyphs`.
- **TouchControls** — on touch only: a context-labelled primary action
  button (the bootstrap supplies the label: examine target, Continue, Begin,
  Investigate again) and Case File / Timeline / Name Suspect buttons, polled
  from bootstrap providers at 10 Hz.
- **InteractionController** — proximity scan, prompt data, request dispatch.
- **InteractionPromptView** — small `[E] Examine` prompt (glyph follows the
  scheme; hidden on touch, where the primary touch button replaces it).
- **EvidencePanel** — dark investigative evidence panel.
- **ObservationPanel** (Phase 2O) — lightweight, transient flavour-text
  readout for non-evidence interactables; visually distinct from the evidence
  panel, auto-dismisses, and carries no discovery.
- **CaseBriefingView** — the case briefing, as a shot of the crime scene with
  the case number, title, hook and time/place over it (M8, see below).
- **ObjectiveView** — minimal current-objective checklist + completion banner.
  Only shown during `Investigation`. The server sends a completed objective
  and its successor in the same frame, so a non-final completion is held on
  screen for ~2 s before the next objective replaces it.
- **TimelineView** — case timeline overlay (discovered events only), T to open.
- **DialogueView** (Phase 2G, rewritten M7) — cinematic conversation
  presentation: letterbox, live speaker portrait (a still copy of the NPC in a
  ViewportFrame), name/role plate, typewriter reveal with punctuation pauses,
  player lines set apart, the asked question echoed, a choice list (number
  keys / mouse / touch / gamepad selection, NEW marks), statement toasts and a
  camera-local depth of field. Renders only the server-authorized step it is
  given and reports a picked choice id.
- **CaseFileView** (Phase 2H) — persistent investigation notes panel
  (unlocked statements/contradictions/deductions), C to open.
- **AccusationView** (Phase 2N) — the formal accusation picker, opened with
  Q once every objective is complete; renders exactly the server's
  `Types.AccusationPayload` (the suspects) and reports only the chosen id.
- **CaseClosedView** (Phase 2L) — cinematic closing overlay, shown during the
  `CaseClosed` phase; renders exactly the server's `Types.CaseClosedSummary`
  (Phase 2N adds the accused suspect and whether the evidence is consistent
  with that accusation).
- **CameraController** — third-person explore + smooth examine framing.

## Data contracts

- Interactables are `CollectionService`-tagged `"Interactable"` with attributes
  `InteractionKind`, `PromptLabel`, optional `EvidenceId`; parsed exclusively via
  `src/shared/Interactable.luau`.
- Cases follow `Types.CaseDefinition`: id, title, description, suspects,
  locations, evidence, timeline, objectives, conversations, statements,
  contradictions, deductions, accusations (optional, Phase 2N).
- Evidence follows `Types.EvidenceDefinition`: id, name, description, location,
  importance, plus optional `details`, `timestamp`, `category`,
  `timelineEventId`, `relatedEvidenceIds` (plus runtime `discovered`).
- Timeline events follow `Types.TimelineEventDefinition`: id, timestamp,
  timeMinutes, title, description, sourceEvidenceIds. Only discovered events are
  ever sent to clients.
- `CaseService.buildClientPayload` returns only `Types.CaseBriefing` (id, title,
  description, and since M8 the optional time/place of `CaseDefinition.setting`) so undiscovered evidence/timeline facts never reach the client.
- Objectives follow `Types.ObjectiveDefinition`: id, title, description,
  requiredEvidence, requiredInteractions, generic `requirements`, and optional
  `prerequisites` (objective ids that must already be complete). Each
  requirement may key off `evidence`, `interaction` kind, and/or `target` (the
  interacted instance's `Name`, for requirements that are not evidence-tied).
- Interaction kinds: `Examine`, `Read`, `PickUp`, `Talk`. Each maps to a handler
  in `InteractionService.HANDLERS` implementing the signature
  `(player, info) -> boolean`.

## Objective sequencing (Phase 2F)

`ObjectiveService` no longer assumes a single `objectives[1]`. The *active*
objective for a player is the first objective, in authored array order, that
is both (a) not yet completed and (b) has every id in its `prerequisites`
already present in `completedObjectives`. An objective with no `prerequisites`
is available from the start.

`recordInteraction` evaluates progress only for objectives that are currently
unlocked and incomplete — a locked objective's requirements are never
evaluated, so progress can never be credited to it early. When completing an
objective changes which objective is active, `ObjectiveService.sendCurrent` is
invoked automatically so the client picks up the next objective's initial
state without waiting for a further interaction. CASE-001 still declares a
single objective with no prerequisites, so its runtime behavior is unchanged;
sequencing only activates once a case authors more than one objective.

`ObjectiveRequirement.target` is evaluated as an exact match against the
interacted instance's `Name`. It exists for requirements that should advance
on interacting with a specific named object regardless of evidence — CASE-001
does not currently use it.

### "Investigation complete" (Phase 2K)

`Types.ObjectivePayload.allComplete` existed since Phase 2F's multi-objective
work but was computed wrong (`objectiveIsComplete(objective, progress)` —
identical to `payload.objective.completed`, one field over) and had no
client-side reader. Phase 2K fixes the computation to what the field always
claimed: `getActiveObjective(data) == nil`, true only once no objective
remains active for the player. `ObjectiveView.showCompleted` now reads it —
when true, the existing per-objective completion banner reads "INVESTIGATION
COMPLETE" instead of "OBJECTIVE COMPLETE". No `GamePhase` transition is
triggered by this; the player keeps playing exactly as before, just with an
honest acknowledgment that every currently-authored objective is done.

## Suspects and locations (Phase 2F)

`Types.SuspectDefinition` and `Types.LocationDefinition` are unchanged and
still authored directly in case data (see `src/config/Case001.luau`).
`CaseService` now exposes read-only, non-case-specific accessors —
`getSuspects(caseId)`, `getSuspect(caseId, suspectId)`,
`getLocations(caseId)`, `getLocation(caseId, locationId)` — mirroring the
existing `getCase(caseId)` pattern. These are server-side only: no client
payload includes suspect or location data yet, since nothing consumes it on
the client. This phase adds access, not content — CASE-001's suspects and
locations are unread by any other system.

`Interactable`'s attribute contract gained an optional `SuspectId` attribute,
read into `Descriptor.suspectId` exactly like `EvidenceId`. Since Phase 2G
this is what a Talk-kind NPC uses instead of a parallel interaction system.

## StoryEvents (Phase 2F)

`src/server/StoryEvents.luau` is a small, generic, server-only publish/
subscribe module (`StoryEvents.on(kind, callback)` /
`StoryEvents.publish(kind, player, data)`), backed by one `BindableEvent` per
event kind. It exists so future story systems (dialogue, contradictions,
deductions) can observe authoritative facts without the systems that produce
those facts needing to know they exist.

It is strictly additive and non-authoritative: the existing pipeline
(`Interaction → EvidenceService.discover → TimelineService.revealForEvidence
→ ObjectiveService.recordInteraction`) remains direct, synchronous function
calls — nothing in that pipeline depends on `StoryEvents` to function.
`EvidenceService` publishes `"EvidenceDiscovered"` after a successful
discovery; `ObjectiveService` publishes `"ObjectiveCompleted"` when an
objective's completion is first recorded. `StoryEventKind` currently declares
only these two kinds; add a new kind only when a system actually publishes
it — this module is not a place to pre-declare future story content (no
`ConversationCompleted`, `StatementUnlocked`, etc. exist yet, on purpose).

This is separate from `Shared/Signals.luau`, which wraps `RemoteEvent`s for
client↔server communication. `StoryEvents` never crosses the client boundary.
Since Phase 2G it also carries `"ConversationStarted"`/`"ConversationCompleted"`,
published by `ConversationService`.

## Suspect NPCs (Phase 2G)

A suspect becomes a physical, talkable presence in the office purely through
data: `Types.SuspectDefinition.npcPlacement` (`{ position: Vector3, lookAt:
Vector3? }`), authored per suspect in case data. `SuspectSpawner.start()`
(called from `init.server.luau`, after `OfficeRoom.start()`) loops over
`CaseService.getSuspects(activeCaseId)` — never a raw case table, and no
suspect id is hardcoded — and builds a static (unanimated), R6-proportioned
humanoid rig for every suspect that has `npcPlacement`; a suspect without one
simply has no physical NPC. Only `SUS-001` (Mara Reyes) has `npcPlacement`
this phase, per the "one playable suspect" scope.

The spawned rig's root part is tagged with the existing `Interactable`
contract (`InteractionKind = "Talk"`, `PromptLabel`, `SuspectId`) — no
NPC-specific interaction path exists anywhere. `InteractionController` (client
scan/prompt) and `InteractionService` (server validation: tag, kind match,
distance) treat it exactly like any other interactable; the only new logic is
`InteractionService`'s `talkHandler`, which calls
`ConversationService.begin(player, descriptor.suspectId)`.

The root part is named after the suspect's `id` (not the literal
"HumanoidRootPart") so an `ObjectiveRequirement.target` can address one
specific suspect's NPC — every spawned rig would otherwise share the same
instance name. Safe: these rigs are fully anchored, static, and never
animated or moved, so nothing depends on the literal name
"HumanoidRootPart" (that name is still used for the *player's own* character
root part elsewhere, an unrelated lookup). Only `SUS-001` had `npcPlacement`
through Phase 2H; Phase 2I adds `SUS-002` — no `SuspectSpawner` code changed
for the second suspect, exactly as this module's docstring anticipated.

## Conversations (Phase 2G)

`ConversationService` is the sole authority over conversation state. Per
player (`PlayerCaseState`): `activeConversation: { suspectId, nodeId }?`,
`completedConversations: { [suspectId]: boolean }`, `unlockedStatements:
{ [statementId]: boolean }`. The client never supplies or infers any of it.

Conversations are authored per case as `Types.ConversationDefinition`: a
`suspectId`, a `startNodeId`, and a map of `Types.DialogueNodeDefinition`
(`id`, `speaker`, `text`, `next: string?`, `statementId: string?`). Phase 2G's
conversations were linear; M7 adds branching (see "Interrogation (M7)"),
and a linear graph still behaves exactly as described here.

- `ConversationService.begin(player, suspectId)` — rejects if the player
  already has an active conversation, the suspect doesn't exist, or the
  suspect has no authored conversation. Otherwise sets `activeConversation`
  to the start node, unlocks that node's statement if any, and publishes
  `"ConversationStarted"`.
- `ConversationService.advance(player)` — rejects with no active
  conversation. Otherwise follows the current node's `next`. Continuing past
  a node with `next == nil` completes the conversation instead: clears
  `activeConversation`, records `completedConversations[suspectId] = true`
  exactly once (idempotent — replaying the same conversation later publishes
  no second `"ConversationCompleted"`), and publishes the event on first
  completion only.
- `ConversationService.leave(player)` — closes the conversation early (no
  completion, no event); already-unlocked statements stay unlocked. Safe to
  call with nothing active.
- `ConversationService.getCurrentPayload(player)` — synchronous re-read of
  the current step, for resync and for tests (Deferred `BindableEvent`
  delivery made waiting on `onUpdated` from inside a test unreliable — see
  Phase 2F's `StoryEvents_Test` notes; the same lesson applies here).

Player cleanup needs no extra code: `PlayerDataService.clear` already wipes
the whole `PlayerCaseState`, including `activeConversation`, on
`PlayerRemoving`.

### Movement lock (controlled dialogue mode, Phase 2G.1)

A conversation could otherwise go stale if the player walked away mid-line
without pressing ESC. Rather than detect that (which would need a polling
loop or per-frame distance check), `ConversationService` makes it
structurally impossible: `begin` server-side sets the player's
`Humanoid.WalkSpeed`/`JumpPower`/`JumpHeight` to `0`, after capturing the
prior values; every path that clears `activeConversation` (`leave`, natural
completion, and each fail-safe branch in `advance`) restores exactly those
captured values. This is a no-op for a player with no `Character` (e.g. every
mock player in the test suite), so it never affects tests that don't
exercise it. Dialogue input (continue/close) is untouched — only
walking/jumping is suspended, and only for the conversation's duration.

### Dialogue payload (spoiler safety)

`Types.DialoguePayload` — the only shape ever sent to a client — carries
`active`, `suspectId`, `suspectName`, `nodeId`, `speaker`, `text`,
`canContinue`, `completed`, and `unlockedStatement?`. It never carries the
raw node's `next` pointer, `statementId`, or any other node in the graph. The
client cannot see a future line, a locked branch, or the conversation's
internal structure — only the one line it has just been authorized to show.

### Statements

`Types.StatementDefinition` is `{ id, suspectId, label }` — deliberately no
`text` field. A statement's content is resolved at unlock time by reading the
source suspect's own authored data (`CaseService.getSuspect(...).alibi`), so
it can never drift from the fact it represents and no content is duplicated
across two places in case data. CASE-001 ships exactly one:
`STMT-SUS-001-ALIBI`, unlocked the moment the conversation reaches the node
that reveals it.

## Objective/conversation integration (Phase 2G)

`ObjectiveRequirement.interaction = "Talk"` plus `target = <NPC instance
Name>` (both fields already existed — see Phase 2F) is sufficient to express
"talk to this suspect" as an objective requirement; no new requirement schema
was added. CASE-001's `OBJ-001` is deliberately **not** modified to require
talking to Mara Reyes: adding a requirement to it would change what already
counted as complete for existing playthroughs (a regression), and authoring a
new objective whose only purpose is to demonstrate the mechanic would be
inventing storyline content that doesn't exist in the case data. The
mechanism is proven end-to-end instead by a synthetic test case (see
`ObjectiveService_Test`'s `CASE-TEST-SEQ` fixture, `OBJ-C`).

Phase 2I gives the mechanism its first real use: `OBJ-002` ("Question Victor
Lane") requires `interaction = "Talk", target = "SUS-002"`, gated behind
`OBJ-001` via `prerequisites`. `OBJ-001` itself is untouched — its
requirements and behavior are exactly what they were in Phase 2C.

## Investigation reasoning (Phase 2H)

`ReasoningService` evaluates two kinds of relationship between already-known
facts, entirely server-side:

- **Contradiction** — two independently discovered/unlocked facts conflict.
- **Deduction** — a conclusion unlocked once a defined set of facts are all
  known (the facts do not need to conflict with each other).

Both are expressed with one small, shared building block —
`Types.FactReference` (`{ kind: "Evidence" | "Statement", id: string }`) —
instead of a generic graph or a duplicate evidence/statement contract. A fact
reference is never a copy of content: `ReasoningService` always resolves it
live through the fact's owning service (`EvidenceService.isDiscovered`/
`.getState` for `"Evidence"`; `ConversationService.isStatementUnlocked`/
`.getUnlockedStatement` for `"Statement"`, both added this phase). This is
also why contradiction/deduction unlocking can never be inferred from text or
fuzzy-matched — it is a deterministic check against `FactReference`s an
author explicitly wrote in case data.

`Types.ContradictionDefinition` is `{ id, label, left, right, reason? }`;
`Types.DeductionDefinition` is `{ id, label, requiredFacts }`. Neither stores
authored conclusion prose — see "Deliberately not implemented" below for why.

### Event flow

`ReasoningService` never discovers evidence or unlocks statements itself, and
`EvidenceService`/`ObjectiveService` never call into it directly. The only
new coupling is one direction, through the existing `StoryEvents` bus:

```
EvidenceService.discover      -> StoryEvents "EvidenceDiscovered" (existing)
ConversationService (unlock)  -> StoryEvents "StatementUnlocked"  (new)
                                          |
                                          v
                              ReasoningService.evaluate(player)
                                          |
                                          v
              StoryEvents "ContradictionUnlocked" / "DeductionUnlocked"
```

`ReasoningService.start()` subscribes to both event kinds; `evaluate` walks
every authored contradiction/deduction for the player's case and unlocks any
whose fact references are now all known. It is idempotent (guarded by
`unlockedContradictions`/`unlockedDeductions`, so a StoryEvent firing twice
for the same underlying fact unlocks nothing a second time) and only ever
runs in reaction to one of those two events — never on a timer, never a
per-frame scan.

Per-player state (`PlayerCaseState.unlockedContradictions`/
`.unlockedDeductions`) needs no new cleanup code: `PlayerDataService.clear`
already wipes the whole `PlayerCaseState` on `PlayerRemoving`.

### Payload / spoiler safety

`Types.ReasoningPayload` (`{ statements, contradictions, deductions }`) is
the only shape ever sent to a client, via `ReasoningService.getPayload`. Each
list contains only entries the player has actually unlocked — a locked
contradiction or deduction is never included, never partially included, and
never distinguishable from "does not exist" on the wire. `ContradictionPayload`/
`DeductionPayload` include resolved display names (`leftSummary`/
`rightSummary`/`basedOn`) rather than raw fact references, which is always
safe: those names are only ever resolved for facts that are, by construction,
already unlocked for that player by the time the contradiction/deduction
itself unlocks.

### Case File UI

`CaseFileView` (client) is a persistent investigation notes panel — opened
with **C**, closed with **C**, mutually exclusive with
`TimelineView` (both are full-screen centered panels). It renders exactly
the `ReasoningPayload` it is given: a STATEMENTS section, a CONTRADICTIONS
section, and a DEDUCTIONS section, each only drawn when it has at least one
entry. It was justified this phase because it closes a real, existing gap —
before this, the only way to see SUS-001's alibi statement was the transient
"STATEMENT RECORDED" notice during dialogue, with no way to review it
afterward. The Contradictions/Deductions sections are real, tested
architecture with a real consumer (the UI itself); they simply render empty
for CASE-001 today, honestly, rather than showing placeholder content.

### CASE-001's first real contradiction (Phase 2I)

Phase 2H audited CASE-001 and found no two independently discoverable facts
that actually conflicted, and left `contradictions`/`deductions` empty rather
than manufacture one — the mechanism was proven only by a synthetic fixture
(`ReasoningService_Test`'s `CASE-TEST-REASONING`, which still exists and still
covers edge cases CASE-001 itself doesn't, like invalid fact references).

Phase 2I brings SUS-002 (Victor Lane) online as CASE-001's second playable
suspect — `npcPlacement`, a `ConversationDefinition`, and a
`StatementDefinition`, authored exactly the way `SuspectSpawner`/
`ConversationService` already expected, no service code changed for it. His
statement's text is still resolved live from his own already-authored
`alibi` field, never duplicated.

That alibi ("Says he left the office at 22:30. Keycard log suggests
otherwise.") already implied an independently discoverable access record;
`EV-004` ("Keycard Log") is that record, made real. Its `details` text
states only that the record disagrees with his own stated departure time —
it does not invent a new timestamp, location, or event anywhere the case
data doesn't already support one. `EV-004` authors `propPlacement` (see
below) but no `timelineEventId`, since a chronological timeline entry would
need a precise clock time this case never specifies.

`CASE-001.contradictions` now declares one entry, `CONTRA-001`, linking
`{ kind = "Statement", id = "STMT-SUS-002-ALIBI" }` to
`{ kind = "Evidence", id = "EV-004" }` — `ReasoningService` evaluates it with
the exact same generic logic proven in Phase 2H; nothing in `ReasoningService`
changed. `deductions` stays empty; Phase 2I adds no deduction.

#### Evidence without a Studio-authored prop

`EV-001`/`EV-002`/`EV-003` are all hand-placed in the Studio-authored
`assets/Office.rbxm`. `EV-004` has no such counterpart: there was no reliable
way from this development environment to persist a live Studio-side edit of
that binary asset back into the tracked file. Instead, `Types.EvidenceDefinition`
gained an optional `propPlacement` field (`{ position, lookAt? }`, mirroring
`SuspectDefinition.npcPlacement` exactly), and `OfficeRoom` — already the
module responsible for runtime office setup, not a new service — spawns a
minimal static prop for any evidence that authors one, tags it with the same
`Interactable` contract as every hand-placed prop, and parents it under a new
`Workspace.Office.EvidenceProps` folder. Evidence without `propPlacement`
(`EV-001`–`EV-003`) is completely unaffected — this is purely additive.

## Reasoning-gated objectives (Phase 2J)

`CONTRA-001` unlocked correctly through Phase 2I but had no gameplay
consequence — nothing reacted to it. Phase 2J connects it to progression
without inventing any new mechanic:

```
ReasoningService  --StoryEvents "ContradictionUnlocked"/"DeductionUnlocked"-->  ObjectiveService
```

`ObjectiveService` had never subscribed to `StoryEvents` before this phase
(`recordInteraction` is called directly and synchronously by
`InteractionService`). It now also subscribes to `"ContradictionUnlocked"`/
`"DeductionUnlocked"` in `start()`, mirroring `ReasoningService.start()`'s own
subscription pattern exactly. Each callback validates the event's id is a
string, then calls a new, narrowly-scoped `ObjectiveService.recordFact(player,
kind, id)` — the StoryEvents counterpart to `recordInteraction`, sharing the
exact same underlying evaluation/completion logic (extracted into a private
`evaluateObjectives`, so neither this service's per-case-nothing behavior nor
any of its existing evidence/interaction/target handling changed).

`Types.ObjectiveRequirement` gained two optional sibling gates:
`contradiction: string?` and `deduction: string?`, alongside the existing
`evidence`/`interaction`/`target`. The other three are matched against the
single event that triggered evaluation; `contradiction`/`deduction` are
matched instead against the player's own persisted
`unlockedContradictions`/`unlockedDeductions` state. That distinction is
deliberate: a contradiction can unlock before the objective gated on it is
even active (its prerequisite might complete later), and checking live state
rather than "did this specific event carry the right id" means the
requirement resolves correctly however the two end up ordered — with no
event-replay system, and no case/contradiction id hardcoded in
`ObjectiveService` anywhere.

CASE-001 declares one new objective, `OBJ-003` ("Review Victor Lane's
Statement"), gated behind `OBJ-002`, with a single requirement:
`{ contradiction = "CONTRA-001" }`. `OBJ-001`/`OBJ-002` are unmodified. The
`deduction` gate was proven at the time only by a synthetic fixture
(`ObjectiveService_Test`'s `CASE-TEST-OBJ-REASONING`); Phase 2M later gives
it `OBJ-004`/`DEDUCT-001` as its first real content (see "First real
deduction (Phase 2M)" above).

## Replay (M4)

`GameStateService.requestReplay(player)` is the inverse of `requestConclude`:
valid only while the phase is `CaseClosed` and only for a player with case
data. It walks the graph's own edges (`CaseClosed -> MainMenu ->
CaseBriefing`, which re-grants the case via the existing `CaseBriefing`
onEnter hook), then `PlayerDataService.clear` + `initialize` wipe that
player's entire `PlayerCaseState` — evidence, timeline, statements,
reasoning, objectives, accusation — since every service keeps its per-player
state there. It fires `GameStateService.onReplay()`, a `BindableEvent`; the
bootstrap bridge respawns the character (`LoadCharacter`) and re-pushes
objectives/timeline/reasoning/accusation, exactly as `onPlayerAdded` does.
The bridge ignores non-Instance players (the unit harness's mock tables).

There is no new remote: a `RequestPhaseChange("CaseBriefing")` received while
the phase is `CaseClosed` is dispatched to `requestReplay`, the same way
`"CaseClosed"` is dispatched to `requestConclude`. The client sends it from
`[E] Investigate again` on the closing screen, and clears its own
`investigationComplete`/last-summary flags whenever `CaseBriefing` begins.

## Timeline reconstruction (M5)

Before M5 the timeline was decorative: every event revealed automatically and
was handed to the client already sorted, so the player never engaged with it.
M5 makes establishing the sequence a real, server-validated investigation step.

- **Challenge order.** `CaseDefinition.timelineChallengeOrder` (optional)
  names timeline event ids in a deliberately non-chronological order;
  `TimelineService.challengeOrder` delivers the discovered events in that
  order (falling back to the `timeline` array order, then appending any event
  the list omits, so nothing is ever lost). It is fixed by the case, never
  shuffled at random, so the puzzle is deterministic and reproducible.
- **Submission.** `TimelineService.submitSequence(player, orderedIds)` accepts
  the order only when the list is non-empty, contains exactly the player's
  discovered events (no missing, no duplicate, no undiscovered id), each
  once, in canonical chronological order (`timeMinutes`, then id — the same
  ordering `chronological()` computes). The server compares against its own
  data; a client can neither invent a correct order nor claim one.
- **Permanence & idempotency.** `PlayerCaseState.timelineEstablished` is set
  once and stays set; a later call is a safe no-op returning false.
- **Objective integration.** `submitSequence` calls
  `ObjectiveService.recordFact(player, "Timeline", "")` **directly** (the
  same synchronous pattern `InteractionService` uses for evidence and
  interaction requirements) so an objective gated on `timelineEstablished`
  completes the instant the order is accepted, independent of deferred
  `StoryEvents` delivery. The `"TimelineEstablished"` StoryEvent is published
  too, for any other observer.
- **Requirement gate.** `ObjectiveRequirement.timelineEstablished` is a new
  optional gate alongside `evidence`/`interaction`/`target`/`contradiction`/
  `deduction`; `requirementSatisfied` checks the player's own live state.
  CASE-001's `OBJ-006` ("Reconstruct the Night") uses it and is the final
  objective. It no longer gates the accusation picker on its own: M9's
  `accusationRules.opensAfter` (see below) lets `[Q]` open as soon as
  `OBJ-002` completes, well before the timeline (or the rest of the case)
  is reconstructed -- accusing early is possible, and costs what it should.
- **Spoiler safety.** Until established, the client receives the events with
  their clock times hidden (it renders `?`); the canonical order and the true
  timestamps are only sent once the player has earned them. The payload
  (`Types.TimelinePayload.established`) carries one boolean and nothing about
  the answer.
- **Client.** `TimelineView` (opened with `T`) renders move-up/move-down
  controls and a `Confirm sequence` button while unestablished, submits the
  working order through the `SubmitTimelineOrder` remote, and becomes
  read-only once the server confirms. It decides nothing — it renders the
  server's order and reports the player's arrangement.

## Case Closed: formal conclusion (Phase 2L)

`GameStateMachine` has allowed `Investigation -> CaseClosed` since Phase 2E,
but nothing ever used it — graph legality was never gameplay authorization.
Audit for this phase found the edge was, until now, genuinely ungated: any
client could request it at any time and the server would honor it, since
`GameStateMachine.transition` only ever validates *that the edge exists*, not
*whether this player may use it right now*. That distinction is now explicit
and enforced:

- **Graph validity** (`GameStateMachine`) — is this transition structurally
  allowed at all. Unchanged.
- **Gameplay authorization** (`GameStateService.requestConclude`) — is
  *this specific player* currently allowed to use it. Reads only server-side
  player state: no active objective (so a data-less player can't pass for the
  wrong reason) **and** a recorded accusation (Phase 2N, below). Never trusts
  a client-supplied completion claim of any kind.

`requestConclude` is a plain, public, directly-testable function (matching
`ObjectiveService.recordInteraction`/`ConversationService.begin`'s pattern) —
the `RequestPhaseChange` handler dispatches to it for `"CaseClosed"` requests
instead of inlining the check, so the authorization logic isn't buried inside
an untestable `RemoteEvent.OnServerEvent` closure. It fires a `BindableEvent`
(`GameStateService.onCaseClosed()`), not the `CaseClosedSummary` RemoteEvent
directly — the same indirection `ReasoningService`/`ObjectiveService` already
use, since a real RemoteEvent's `FireClient` requires an actual `Player`
Instance and would reject a test's mock player table. `init.server.luau`'s
bridge is the only thing that touches the real RemoteEvent.

`CaseClosedView` (mirrors `CaseBriefingView`'s exact cinematic pattern) shows
`Types.CaseClosedSummary`: real, computed counts
(objectives/evidence/contradictions) built from server-side state at the
moment of conclusion, plus (Phase 2N) the player's own accusation and whether
the evidence is consistent with it, and (M2) the case's verdict on that
accusation — see "The case has an answer (M2)" below.

**Known limitation, deliberately not addressed this phase**: `GameStateService`'s
phase machine is a single, server-wide singleton, not per-player — matching
this game's real single-player-session scope everywhere else. `requestConclude`'s
authorization check is correctly per-player, but the transition it gates, once
authorized, is still the same global broadcast every other phase change already
uses. This is consistent with the rest of the codebase's explicit no-multiplayer
scope and was not something this phase's authorization fix needed to solve.

## Player accusation & case resolution (Phase 2N)

Phase 2L let the player conclude, but conclusion was purely mechanical: the
player pressed a key and the server printed counts. Nothing the player
*decided* affected the outcome, and the case's authored reasoning
(`CONTRA-001.reason`, `DEDUCT-001`) was only ever displayed, never acted on.
Phase 2N makes the player name a suspect — the one act that closes an
investigation — and reports the result factually.

### Data

`Types.AccusationDefinition` is `{ id, suspectId, label, supportedBy? }`,
authored per case in `CaseDefinition.accusations` (optional). It asserts no
new story fact: `supportedBy` is only a list of already-authored
contradiction/deduction ids. `CaseDefinition.accusations` for CASE-001 ships
`ACC-001` (Victor Lane, supported by `CONTRA-001` + `DEDUCT-001`) and `ACC-002`
(Mara Reyes, named by nothing).

### Service

`AccusationService` is server-authoritative and owns
`PlayerCaseState.accusationId`:

- `accuse(player, accusationId)` — rejects unless the player exists, the id
  is authored, **no objective remains active** (read from
  `ObjectiveService.getActiveObjectiveId`, never a client claim), and the
  player has not already accused. An accusation is permanent: repeating the
  same choice or changing it is a safe no-op. Records the id, publishes
  `StoryEvents` `"AccusationMade"` once, and pushes the payload.
- `getPayload(player)` — `Types.AccusationPayload` (`{ options, selected? }`).
  Options are the case's authored accusations; nothing on the wire ever
  reveals which option is supported. `selected` appears only after the player
  has accused.
- `getResolution(player)` — resolves the player's own accusation into
  `Types.AccusationResolution` (`supported`, `basedOn`). `supported` is true
  only when every referenced contradiction/deduction has actually been
  unlocked by *this* player; `basedOn` lists those unlocked display names.
  This is a statement about the evidence the player gathered, never about who
  committed anything.

### Flow

```
[Q] (client, only once ObjectivePayload.allComplete)
      -> AccusationView (picker: the case's suspects)
      -> SubmitAccusation(accusationId)            [client -> server]
      -> AccusationService.accuse   (eligibility + permanence, server-side)
      -> GameStateService.requestConclude          (re-checks accusation)
      -> Investigation -> CaseClosed
      -> CaseClosedSummary.accusation -> CaseClosedView
```

The `SubmitAccusation` handler dispatches to `AccusationService.accuse`, and
only on a first success calls `GameStateService.requestConclude` —
`requestConclude` re-derives authorization from server state, so the
transition is never driven by the client's belief. `[Q]` no longer concludes
directly; `Type.ObjectiveView`'s hint reads "Name a Suspect".

### Spoiler safety / non-invention

The picker payload carries only suspect ids/names the player can already see
in the world. The resolution is derived entirely from facts the player
unlocked, and every label it prints (`basedOn`) resolves live from the case's
authored contradiction/deduction `label`s — no new narrative, no asserted
culprit. An unsupported accusation is a legitimate, reported outcome, not an
error.

## Investigation feedback & discoverability (Phase 2O)

The mechanical loop was complete after Phase 2N but the experience was silent:
7 of the office's 10 hand-placed interactables yield no evidence, so examining
them produced no visible response at all; the required actions were unmarked;
and the case was never stated back to the player. Phase 2O is a presentation
and content pass — no new systems, no new case entities.

### Observations

`Types.ObservationDefinition` (`{ instanceName, text }`) is authored in
`CaseDefinition.observations` (optional). `OfficeRoom.applyObservations` (the
same module that already owns runtime office setup) sets each target
interactable's `ObservationText` attribute **at runtime**, by instance name —
mirroring the existing `npcPlacement`/`propPlacement` runtime-application
precedent, and leaving `assets/Office.rbxm` untouched. An entry whose instance
is absent is skipped; an interactable that carries `EvidenceId` is never
given observation text.

`InteractionService.examineHandler`/`readHandler` now branch: an object with
`EvidenceId` discovers evidence exactly as before; an object with only
`ObservationText` invokes `presentObservation`, which fires the service's
`onObservation` `BindableEvent` (bridged in `init.server.luau` to the
`ObservationShown` RemoteEvent). This path discovers nothing, advances no
objective, and touches no reasoning/evidence/timeline state. The client's
`ObservationPanel` renders it as a transient, low-key readout distinct from
the dark `EvidencePanel`.

### First-person testimony

CASE-001's suspect `alibi` fields and dialogue nodes were rewritten into
first person with distinct voices. Every line preserves exactly the
already-authored fact it came from (Mara: asleep at home, phone records
unverified; Victor: left at 22:30, keycard log suggests otherwise); no
motive, action, or event was added. Statement text is still resolved from the
suspect's own `alibi` at unlock time, so it cannot drift.

### Evidence cross-references

`relatedEvidenceIds` is now authored on `EV-001`↔`EV-002` — the only
relationship CASE-001's facts support (both record activity at Daniel's
workspace minutes apart, 11:47 PM and 11:42 PM). `EvidenceService.discover`
includes the already-discovered partners' names in `EvidencePayload.related`;
`ReasoningService.getPayload` adds a `relatedEvidence` section (discovered
evidence + discovered partners) that `CaseFileView` renders as "EVIDENCE
LINKS". An undiscovered partner is never included, so the cross-reference is
spoiler-safe. Unlinked evidence is simply absent, never faked.

### Factual case restatement

`Types.CaseClosedSummary` gained `timeline` (the player's discovered events,
already spoiler-safe via `TimelineService.getDiscovered`) and `contradiction`
(the player's unlocked contradiction, via `ReasoningService.getPayload`).
`CaseClosedView` now restates the sequence of events and the contradiction
alongside the counts and the accusation — all from already-authorized facts.
(M2 later adds `verdict`, the one field on this summary that is a judgment,
not a restatement — see below.)

### Discoverability hint

`ObjectiveView` now displays the active objective's own authored
`description` in the panel (previously only the title and checklist were
shown). The prompt is therefore always stated, using information the player
already had — no waypoint, marker, highlight, or hidden data.

## First real deduction (Phase 2M)

Phase 2I shipped CASE-001's first real contradiction, but nothing ever
closed the gap where a player could complete every pre-2M objective without
ever speaking to SUS-001 (Mara Reyes) — the only suspect an early player is
naturally drawn to question was, in fact, optional.

Phase 2M brings `DEDUCT-001` ("Both Accounts, One Contradiction") online as
CASE-001's first real deduction: `requiredFacts` are
`STMT-SUS-001-ALIBI`, `STMT-SUS-002-ALIBI` and `EV-004` — all already-authored
content, referenced by id only, never duplicated. Unlike a contradiction, the
three facts do not need to conflict; the deduction unlocks once all three are
known. `ReasoningService` evaluates it with the exact same generic logic
Phase 2H shipped — nothing in `ReasoningService` changed.

`OBJ-004` ("Close the Investigation") is gated behind `OBJ-003` and has a
single requirement, `{ deduction = "DEDUCT-001" }`, completing the moment the
deduction unlocks — the same pattern as `OBJ-003`/`CONTRA-001` in Phase 2J.
`OBJ-001`/`OBJ-002`/`OBJ-003` are unmodified. No new evidence, suspect,
dialogue, contradiction or location is added.

The `deduction` requirement gate itself, and the
`DeductionUnlocked` -> `ObjectiveService.recordFact` wiring, were already
built and proven in Phase 2J by a synthetic fixture
(`ObjectiveService_Test`'s `CASE-TEST-OBJ-REASONING`); Phase 2M supplies the
first real content they run on.

## The case has an answer (M2)

Through Phase 2O, `CaseClosed` deliberately never said who did it: the
closing screen reported only whether the player's own accusation was
*consistent with the evidence they gathered*, never whether it was *true*.
That was a real gap — a mystery with no answer isn't a mystery, it's a
checklist. M2 gives CASE-001 a solution and rewrites its content around it,
without touching a single id, objective, or the discovery flow.

**The solution.** `Types.CaseSolution` (`{ culpritSuspectId, reveal }`) is an
optional field on `CaseDefinition`, authored once in `Case001.luau`'s
`solution` table. It is never sent to a client as part of the case's own
payload — `CaseBriefingView`'s `CasePayload` never included case content
beyond the header, and that discipline is what makes `solution` safe to add
alongside it. `CaseSolution` is exported from `Types` (shared, so the type
itself is inspectable) but the *value* lives only in `ServerStorage`.

**Case data moved to `ServerStorage.Config`** (was `ReplicatedStorage.Config`).
This was the actual enforcement mechanism: before M2, nothing in
`CaseDefinition` was secret, so mapping case modules under `ReplicatedStorage`
cost nothing. A `solution` field changes that — a case definition sitting in
`ReplicatedStorage` would let any client `require()` it directly and read the
answer before investigating anything. Every server module that required
`Config.CaseRegistry` now does so via `ServerStorage` instead of
`ReplicatedStorage`; no client module ever required it. `CaseRegistry` itself
still knows nothing about being server-only — it is data, not a security
boundary; the boundary is entirely which DataModel service the folder is
parented under.

**The verdict.** `AccusationService.getVerdict(player)` is the only thing
that ever reads `solution`. It returns nil until the player has actually
committed to an accusation (mirrors `getResolution`'s own precondition), then
compares `accusationId`'s `suspectId` against `solution.culpritSuspectId` and
returns `Types.CaseVerdict` (`{ correct, culpritName, reveal }`) — resolving
`culpritName` from `CaseService.getSuspect`, never hardcoding it. Wrong is as
honestly reported as right: an incorrect accusation still names the real
culprit and the `reveal` text, exactly like a real closed case would.
`GameStateService.getClosingSummary` calls it once, alongside everything else
already being assembled for `CaseClosedSummary`, and the result is `verdict`
on that summary — nil for a case that authors no `solution`, in which case
`CaseClosedView` falls back to Phase 2N's supported/unsupported reporting.

**CASE-001's answer.** Victor Lane killed Daniel Reyes to stop him ending
their partnership. Every already-existing clue was rewritten to actually
support it, none renamed or restructured:
- The briefing's own internal contradiction is gone: Daniel was found
  "shortly after 23:00" while his last call was "minutes before his death" at
  11:47 PM could never both be true. He is now found "shortly after
  midnight" — after the 12:00 AM meeting he never made.
- `EV-001`'s last call is now explicitly *to Mara* (was anonymous), paying
  off her own alibi ("I never heard his call") as the same event instead of
  two coincidentally-unconnected facts.
- `EV-002`/`EV-003` now name what the laptop draft and the meeting were
  *for* (dissolving the partnership) — motive, not just activity — and back
  a new deduction, `DEDUCT-002` ("Daniel Was Ending the Partnership"),
  `requiredFacts = { EV-002, EV-003 }`.
- `EV-004` (the keycard log) now states a real fact instead of only a
  disagreement: Victor's badge left at 11:52 PM, five minutes after Daniel's
  call — still worded from the log's own authority, inventing no new
  document. Its `timelineEventId`/`timestamp` are new (`TIMELINE-004`),
  since the case now has a specific time to place it at.
- `CONTRA-001.reason` and `DEDUCT-001.label` were reworded to state the
  break plainly (Victor's alibi is the only one the evidence contradicts;
  Mara's is merely unverifiable) rather than gesture at "a contradiction"
  the player had to infer the significance of themselves.
- `ACC-001.supportedBy` now also names `DEDUCT-002`, so accusing Victor is
  supported by opportunity *and* motive, not opportunity alone.

None of this added a new suspect, evidence id, objective, or contradiction
mechanism — see "Extension points" below for why that was never necessary:
the reasoning system was generic from Phase 2H, CASE-001 simply had nothing
worth deducing about motive until now.

## Production presentation (M6)

Presentation only: no service, payload or case-state contract changed.

- **Audio** — `client/SoundController` builds `SoundService.MysteryCase_Audio`
  with two SoundGroups (Ambience, Effects) from `Config.Audio`. The bootstrap
  calls `play(cue)` on real events (evidence discovered, dialogue/panel ticks,
  a new contradiction/deduction or the timeline being established, the
  verdict) and `setDucked` while dialogue or the closing screen is up.
- **Suspects** — `server/SuspectSpawner` builds each NPC with
  `Players:CreateHumanoidModelFromDescription` from the suspect's optional
  `appearance` (`Types.SuspectAppearance`: body package key into
  `Config.Characters.Bodies`, hair asset id + colour, skin/outfit colours).
  The root is anchored; the default idle plays on the server Animator. The
  Interactable contract lives on an invisible, welded hitbox part still named
  after the suspect id, so `InteractionService`, objective `target` matching
  and client framing are unchanged. A `ConversationStarted` StoryEvents
  subscriber tweens the root to face the speaking player (mock players are
  ignored).
- **Camera** — `CameraController.faceSubject(part)` frames a conversation from
  the player's side at face height (`Config.Camera.Conversation`);
  `playCinematic(from, to, duration)` / `stopCinematic()` drive the title
  drift in their own mode, which the examine/explore transitions leave alone.
- **Title screen** — `client/TitleScreenView` opens once per client session
  (`Config.Presentation`), holds the briefing back while open, and routes the
  primary input to Play (`E` / `X` / tap / click). Dismissing fires
  `onDismissed`, on which the bootstrap shows the briefing if that is the
  current phase.
- **Environment** — `OfficeDetailing.settleDanielsDesk` rigidly moves the
  asset's elevated desk group onto the floor (idempotent: only an elevated
  desk is moved) and `dressDeskProps` restyles the desk interactables in place
  (names, tags and positions of evidence untouched). `server/CitySkyline`
  builds the night city deterministically (fixed seed) beside the authored
  backdrop.
- **Targeting** — `InteractionController.findNearest` scores each in-range
  interactable by distance × a facing weight (1 ahead → 2.8 behind the camera
  heading); the range check itself is unchanged.

## Interrogation (M7)

Conversations branch. The contract extends `Types.DialogueNodeDefinition`
and `Types.ConversationDefinition` additively:

- `choices: { DialogueChoiceDefinition }?` — what the investigator can say
  at this line (`id`, `text`, `next`, `requires?`, `once?`). `choicesFrom`
  borrows another node's list, so an answer returns straight to the question
  list without an extra "anything else?" line.
- `requires: { DialogueCondition }` — `{ kind, id, negate? }` with kinds
  `Evidence`, `Statement`, `Contradiction`, `Deduction` (the player's own
  state) and `Flag` (conversation memory). Evaluated server-side only.
- `setFlags`/`clearFlags` on a node remember what happened (e.g. the
  investigator called someone a liar); `entries` (`{ node, requires }`, first
  match wins) choose where a conversation starts, so a character can greet
  you differently, or stay cold until you apologise.
- `isPlayer` marks the investigator's own lines.
- `StatementDefinition.text` (optional) lets one suspect own several
  statements; absent, the text still resolves from the suspect's `alibi`.

`ConversationService.choose(player, choiceId)` honours a choice only if it is
on the current line and available to that player (conditions hold, a `once`
choice unused); `advance` refuses to skip a line that is waiting for a
choice (`"choice-required"`). The payload gains `choices` (id + words only —
never `next` or `requires`), `prompt` (the question just asked),
`isPlayer` and `suspectRole`. The client sends `DialogueChoose(choiceId)`.

Authoring rule used in CASE-001: a question that unlocks a statement is
hidden *once that statement is known* (a negated `Statement` condition), not
with `once` — so walking away mid-answer can never lose a fact.
`ConversationService.validate(caseDef)` reports dangling nodes/choices,
unknown ids and never-set flags; it runs at startup (warnings) and in tests.

Objective progress also became state-aware: an evidence requirement counts
evidence already discovered, and a Talk+target requirement counts a suspect
already spoken to (`PlayerCaseState.metSuspects`), so a clue found before
its objective became active is never stranded (a clue can't be rediscovered).
When the active objective changes, known facts are credited immediately.
Re-examining a found clue re-opens its readout (`EvidenceService.review`,
payload `revisited = true`), with no new discovery.

## Environment (M7)

Built at runtime, like every earlier environment change (the binary office
asset is never edited from code). Boot order: `OfficeRoom.start` (lighting,
evidence props, signs) → `OfficeDetailing.start` → `OfficeInterior.start` →
`OfficeRoom.finalize` (observations + validation, so flavour props built by
the interior receive their text) → `CitySkyline` → `SuspectSpawner`.

- **Lighting**: `Lighting.LightingStyle = Realistic` and
  `PrioritizeLightingQuality` are set by script (they are scriptable;
  `Lighting.Technology` is not). The clock is 00:40. Values live in
  `Config.Environment.Night` and `Config.Environment.Interior`. 19 interior
  lights, of which only a handful cast shadows.
- **No third-party models.** All furniture is PropKit (parts + built-in
  materials, no scripts, no asset ids). Characters keep the verified catalog
  body/hair ids from M6, plus welded wardrobe details from
  `SuspectAppearance.details`.

## Patching a baked place (Phase 5.2)

The environment builders adopt what a baked place already contains, so a
change to their text or props doesn't reach a saved place by itself. Rather
than a full forced re-bake (which discards any hand edits to baked props),
three builders expose a targeted patch, run once in Edit mode:

- `OfficeInterior.patchSignage()` rebuilds only the `Interior/Signage` folder
  (the small Malay signs);
- `OfficeDetailing.patchTapeOutline()` replaces the chalk outline (v1) or the
  tape outline and numbered marker;
- `SuspectSpawner.patchIdentities()` re-applies each suspect's name, prompt,
  name tag and skin tone from case data to the baked NPCs, leaving their
  position, pose, hair and clothes alone.

Text baked into other props (the fascia, the printout, exit signs, the pantry
note) was migrated with an explicit old-to-new table, then the place's
`BuilderVersion` stamp was set to `Config.Environment.BuilderVersion`
(bumped to 3, to 4 in Phase 5.3 and to 5 in Phase 5.4). Bump the version whenever what a builder generates changes.
In Edit mode, `require` caches a module for the whole session; require a
`Clone()` of the ModuleScript to run its current source.

`CaseLocalisation_Test` scans every text in `Workspace.Office` for v1 names, so
it is also the check that a baked place was really patched.

## Stabilisation (M8)

- **Case briefing**: no panel. `CaseBriefingView` plays
  `Config.Presentation.BriefingShot` (a slow drift from the far corner of
  Daniel's office across the chalk outline to his desk) through
  `CameraController.playCinematic`, with thin letterbox bars, a shade in the
  lower-left corner only, and a text column: case number, title, the
  one-to-two-sentence hook (`CaseDefinition.description`), the time and place
  (`CaseDefinition.setting`), and a real **Begin investigation** button (also
  the primary input and the touch primary). It hands the camera back only
  when the server moves the phase on (`hide`: a short dip to black). Styling
  lives in `Config.UI.Briefing`.
- **Movement during cinematics**: `CameraController.playCinematic` disables
  the default character controls until `stopCinematic` (title screen and
  briefing), so the player can't walk off while the camera is elsewhere. A
  second shot started while one plays keeps the camera type saved before
  the first, so `stopCinematic` can't restore `Scriptable`.
- **Stale copies in the base place**: `MysteryCaseRoblox.rbxl` (read-only)
  still carries an old `ReplicatedStorage.Config` (the pre-M7 case,
  solution included, where every client can read it) and an old
  `ReplicatedStorage.Signals`. Nothing requires either, and Rojo kept them
  because `ReplicatedStorage` has no `$path`. The project now sets
  `"$ignoreUnknownInstances": false` on `ReplicatedStorage`, so connecting
  Rojo removes anything there that the project doesn't define. The
  `Signals` folder is recreated at runtime.
- **Removed as unused** (no references in src, tests, tools or the project):
  the `InteractionPrompt`/`PromptCleared` remote names,
  `Config.Game.DefaultPhase`, `Config.Camera.DefaultDistance`/`DefaultHeight`/
  `TransitionBlendTime`, `DialogueView.onLineShown`,
  `TitleScreenView.getPlayButton`, `PropKit.filingCabinet`, and the
  `.gitkeep` files in folders that have content.

## The detective decides (M9)

The reasoning layer used to conclude for the player: a contradiction
unlocked the moment both facts were known. M9 hands those moments to the
player, without changing who owns what.

- **ReasoningService** still owns `unlockedContradictions` and
  `unlockedDeductions`. `evaluate` skips anything authored with `claim`
  (contradictions) or `question` (deductions). New entry points:
  `claimContradiction(player, a, b)` (two fact references, either order,
  both known to the player, must match an authored pair) and
  `answerDeduction(player, id, optionId)` (the question must be open, i.e.
  all its facts known). Each fires `onFeedback` with a
  `ReasoningFeedbackPayload` (`claimed`/`correct`/`already`/`no-conflict`/
  `wrong`/`cooldown`/`invalid`). Misses increment
  `caseState.reasoningMistakes` and set a short lockout
  (`Config.Reasoning.MissCooldown`, in memory, not case state). The payload
  gains `evidence` (discovered, for pairing) and `openQuestions` (prompt,
  options and basis, never the answer).
- **ConversationService**: a choice with `present` does not move on. It
  sets `activeConversation.presenting` and re-sends the line with a
  `present` block (the heading, plus the ids and names of the found
  evidence). `present(player, evidenceId | nil)` backs out (nil) or shows
  something the player has found. Outcomes are checked in order; the first
  whose evidence and conditions hold leads to its node, and anything else
  leads to the choice's `next`. Listeners registered with `onPresented` run
  synchronously before the reaction line is sent. ReasoningService registers
  one to unlock the contradiction an outcome `claims` (it can't be required
  from ConversationService, which it depends on). `validate` checks the
  outcomes too.
- **AccusationService**: `isOpen(player)` replaces "no active objective" in
  both `accuse` and `GameStateService.canConclude`. With
  `accusationRules.opensAfter` it is that objective being complete. With
  `requiresCase`, `accuse(player, id, motiveId, proofId)` only accepts a
  motive and proof the player has established, and stores them.
  `getVerdict` grades them: Solved when both are in the accusation's
  `motives`/`proofs`, Unproven when the suspect is right but the case isn't,
  Wrong otherwise, with `solution.solvedEpilogue`/`unprovenEpilogue` or the
  accusation's `wrongEpilogue`. (P7: `solution.solvedVariants` can replace
  the Solved epilogue with one reflecting how far the investigation went --
  the first variant whose `requiredFacts` the player has all established.
  CASE-001 uses it for an investigator who broke Victor. Grades never
  change.) Unproven/Wrong also carry a one-line `shortfall` (Phase 2P). The
  payload gains `open`, `requiresCase`, and
  the established `motives`/`proofs` (labels only). It is re-sent when
  objectives complete or reasoning changes.
- **Remotes**: `DialoguePresent`, `ClaimContradiction`, `AnswerDeduction`
  (client → server; ids only, all re-validated) and `ReasoningFeedback`
  (server → client).
- **Client**:
  - DialogueView turns a `present` payload into the choice list (evidence,
    marked EVIDENCE, then "Never mind."), so keys, mouse, touch and gamepad
    work unchanged. It echoes "You show: …" above the reaction.
  - CaseFileView is rebuilt around open questions, a two-column "what people
    said / what you found" selection with a claim button, and the
    established facts, with a stamp on success.
  - AccusationView has three sections (who, why, what proves it) and ACCUSE
    enabled only when complete.
  - CaseClosedView shows the grade, the epilogue and the missteps. (Phase 3:
    the objective count reads "Leads followed", since accusing opens partway
    through the objective chain; R7 adds "Timeline reconstructed" when
    `CaseClosedSummary.timelineReconstructed`, which GameStateService fills
    from `TimelineService.isEstablished` -- display only, never graded.)
- **Phase 3 (release readiness)**: `Components.fitToViewport(panel,
  designSize, margin?, minScale?)` adds a `UIScale` that shrinks a
  fixed-size panel to the viewport (never above 1, floor 0.5); CaseClosedView,
  TimelineView and EvidencePanel use it, matching what AccusationView and
  CaseFileView already did inline. `SessionGuard` (server) admits one
  investigator per server (`Config.Game.MaxInvestigators`); the bootstrap
  kicks any further player with `Config.Game.FullServerMessage`. It is a
  safety net for the server-wide phase machine -- Max Players should still
  be 1 in the published place.
  - The Q/touch accusation gate follows the payload's `open`, announced
    once per case.
  - **DialogueView (R4)**: the panel and the choice list each carry their
    own `UIScale` (kept in sync by `rescale`), sized against the real
    choice count rather than a fixed 9-slot allocation, so a short
    landscape phone can fit the choices under the letterbox bars instead
    of running them off the top of the screen. `panelY(extra)` computes
    the panel's Position (scaled, and compensated for a real Roblox
    behaviour: once anything in an `IgnoreGuiInset` screen carries a
    `UIScale`, it renders `GetGuiInset().Y` pixels higher than its
    declared offset); both `rescale` and the open/close tween in
    `setOpen` go through it, so they never compute two different
    answers for where the panel sits.

## Story engine capabilities (Phase 5.1)

Three generic capabilities that CASE-001 v2 (and later cases) author as data.
CASE-001 v1 uses none of them, so it plays exactly as before.

### Evidence revealed by a condition (`propPlacement.revealWhen`)

- **Data.** `EvidenceDefinition.propPlacement.revealWhen: { DialogueCondition }`.
  It uses the dialogue's own condition language: every condition must hold,
  checked by `ConversationService.conditionsHold`.
- **RevealService** holds the prop out of the world from boot:
  - the part named after the evidence id, plus its `<id>_Look` model;
  - built by OfficeRoom or adopted from a baked place;
  - held in `ServerStorage.MysteryCase_HeldProps`.
  It puts the prop back exactly where it was once the conditions hold.
- **Server-authoritative by construction.** ServerStorage doesn't replicate,
  and InteractionService already refuses anything outside Workspace.
- **When it re-evaluates:**
  - on `EvidenceDiscovered`, `StatementUnlocked`, `ContradictionUnlocked` and
    `DeductionUnlocked`;
  - on every conversation step, which is where dialogue flags change.
- **Latched per case** in `caseState.revealedProps`, so a cleared flag never
  hides a prop again. A replay starts a new case state, and `refresh` (called
  on join and from the replay bridge) holds the prop back again.
- **Only the prop is gated.** The evidence can still be reached another way,
  such as a line of dialogue that grants it.
- **Limits:**
  - Only code-spawned props (`propPlacement`) can be gated.
  - The world is shared: one investigator per server (SessionGuard).
    Per-player visibility belongs with per-player sessions
    (`WORLD_SCALABILITY.md` A1).

### Evidence bound to an existing object (`bindTo`, Phase 5.3)

- **Data.** `EvidenceDefinition.bindTo = { instanceName, label? }`.
- **What it does.** At boot, `OfficeRoom.applyEvidenceBindings` finds the
  Interactable with that name in the baked office and sets its `EvidenceId`
  (and `PromptLabel`, if given). It also drops any `ObservationText` the
  object carried, since it is a clue now and not flavour.
- **Why.** Two of v2's new clues are objects the place already has (the shelves
  and the file cabinet). Binding adds no prop and no builder change.
- **A missing name is reported, never invented** (a warning, and the
  "missing authored interactable" check still fires).
- **A new prop in a baked place.** `OfficeRoom.patchEvidenceProps(rebuild?)`
  builds the `propPlacement` props a baked place lacks, and rebuilds the ids
  named in `rebuild` (used for EV-007's new sticker). `OfficeInterior.patchCredenza()`
  adds the credenza to Daniel's office the same way.

### Evidence handed over in a conversation (`grantsEvidence`)

- **Data.** `DialogueNodeDefinition.grantsEvidence: { string }`.
- **When it runs.** When a node is reached, `ConversationService` calls
  `EvidenceService.grant` for each id:
  - after the node's statement is unlocked;
  - before its line is sent, so questions that need the evidence are offered
    on that same line.
- **What `grant` does.** It is `discover` (timeline, StoryEvent, reasoning)
  plus `ObjectiveService.recordEvidence`: the objective credit an examine gets
  from InteractionService. An `interaction` gate on a requirement is implied
  by the evidence being known.
- **Idempotent.** Evidence already found is skipped, so one clue can have
  several routes.
- **On the client:**
  - `EvidencePayload.granted` means no camera framing and no readout over the
    conversation, only the discovery sound.
  - `DialoguePayload.grantedEvidence` shows an "EVIDENCE ADDED" notice under
    the top bar. It is a second label, so the statement notice is unchanged.
  - The full readout lives in the Case File.
- **Validation:**
  - `ConversationService.validate` reports unknown granted ids.
  - `OfficeRoom.validateInteractables` doesn't expect a world object for
    granted evidence.

### Evidence that hands over evidence (`EvidenceDefinition.grantsEvidence`, Phase 5.4)

- **Data.** `EvidenceDefinition.grantsEvidence: { string }`. One object, one
  action, several clues: an unlocked phone gives the message and the watch data.
- **How it runs.** `EvidenceService` records and announces the examined item
  first, then hands the others over through `grant` (so each gets the same
  timeline reveal, StoryEvent and objective credit as any discovery). Already-known
  ones are skipped. It works the same whether the item is examined or is itself
  handed over by a conversation.
- **The readout.** `EvidencePayload.alsoAdded` names only the ones newly added.
  `EvidencePanel` shows them as an "ALSO ADDED" line; the handed-over items send
  their own `granted` payloads, so they get the discovery sound and no readout.
- **A chain can't loop.** The primary is already discovered before the others are
  asked for, and `ConversationService.validate` rejects unknown ids, a self-grant
  and a loop.
- **A prop's own prompt.** `propPlacement.label` sets the prompt ("Read Unlocked
  Phone"); absent derives it from the evidence's name.

### A scene at a Solved close (`solution.solvedCutscenes`, Phase 5.4)

- **Data.** `CaseSolution.solvedCutscenes: { { cutsceneId, requiredFacts? } }`,
  chosen like `solvedVariants`: the first entry whose facts the player has
  established (one without facts always matches, so it goes last).
  `AccusationService.getOutroCutsceneId` returns it, and only for a Solved
  verdict.
- **The close.** `GameStateService.requestConclude` moves to `CaseClosed` as
  before, then plays that scene and holds the closing summary. When the scene ends
  (finished, skipped or timed out: the `CutsceneFinished` StoryEvent) the summary
  is announced. If no scene is authored, or it can't play, the summary comes at once.
- **The hand-off is `GameStateService.announceClose`**, which `requestConclude` calls, so
  it can be tested without walking the phase machine. The held summary is keyed by
  UserId: a BindableEvent hands its listeners a copy of a table, so a mock player
  would never match itself.
- **A replay** drops a waiting summary. `GameStateService.isClosingScenePlaying`
  says whether one is held.
- **The investigator's avatar is hidden during any scripted shot**
  (`CameraController.playShot`, shown again by `stopCinematic`): a scene's cameras
  are placed in the office wherever the player happens to be standing.
- **On the client** nothing new: the phase is already `CaseClosed`, the scene
  takes the screen, and the Case Closed card shows when the summary arrives.
- **Validation.** `CutsceneService.validate` rejects an entry that names a scene
  the case doesn't have.

### Scripted scenes (`cutscenes`: CutsceneService and CutsceneView)

**Data.** `CaseDefinition.cutscenes: { CutsceneDefinition }`.
- Shots: a camera `from`, an optional `to`, `fieldOfView`, `duration`,
  `fadeIn` and `fadeOut`, and timed subtitle `lines` (with or without a
  speaker).
- `skippable` (default true).
- `replayFrom`: the shot a second showing in the same session starts at.

**The server decides (`CutsceneService`):**
- **What plays and when.** Only `play(player, id)` starts a scene; there is
  no client request for one. It is refused during a conversation or another
  scene.
- **That a scene is on.** InteractionService ignores requests, and
  `ConversationService.begin` refuses.
- **When it's over.**
  - The client reports the end or a skip (the `CutsceneFinished` remote: the
    id and a skip flag).
  - A skip is accepted only if the scene allows it.
  - The end is accepted no sooner than the scene's length, minus
    `Config.Cutscene.EndTolerance`.
  - If the client never reports, a timer calls `expire` after the length plus
    `Config.Cutscene.EndGrace`. The grace is fixed per showing, and `expire`
    ends only a scene that is actually overdue.
  - Every end publishes the `CutsceneFinished` StoryEvent: `{ cutsceneId,
    skipped, timedOut }`.
- **Replay-aware.** Scenes seen this session are remembered outside the case
  state, which a replay wipes.
- **Checked at boot.** `validate` checks each scene's structure.
- **Time** comes from one source (`useClock`), so the tests never wait in real
  time.

**The client presents it (`CutsceneView`):**
- Letterbox bars, dips to black and subtitles.
- `CameraController.playShot`: a one-way eased move. `stopCinematic` puts the
  field of view back.
- Timing is scheduled against the scene's start clock, so it never drifts.
- **Skipping takes two presses** of the primary input ([E] / (X) / the touch
  button reading "Skip"): the first shows the hint, a second within
  `SkipConfirmWindow` skips. An unskippable scene ignores it.
- **The HUD steps aside** while a scene plays (`beforeCutscene` /
  `afterCutscene` in the bootstrap).
- A stale "over" naming another scene is ignored.

**Remotes:** `CutsceneUpdated` (server to client) and `CutsceneFinished`
(client to server).

### Tests

- **Unit** (fixture cases, no real-time waits): `GrantsEvidence_Test`,
  `RevealService_Test` and `CutsceneService_Test`.
- **End to end:** `tools/headless/entry_engine.luau` drives the real server
  and client scripts through player inputs, on a fixture case made active for
  that run only.

## Headless verification

`tools/headless` runs the game's Luau without Studio on a small engine
stand-in (see its README): the unit suite (with the server bootstrap first,
as in Play), a scripted end-to-end playthrough driving the real client
scripts through player inputs, an end-to-end check of the Phase 5.1 engine
capabilities on a fixture case, a scene dump for layout previews, and a
Rojo-compatible sourcemap for `luau-lsp analyze`. It complements, and does
not replace, a Studio playtest.

The service tests pin themselves to `tests/fixtures/LegacyCase.luau` (the
pre-M7 CASE-001, frozen), registered by `RunUnitTest` before any test runs,
so they keep testing the mechanics they were written for; CASE-001's live
content is covered by `Case001_Test` and `BranchingDialogue_Test`.

## Deliberately not implemented

Phase 2G shipped a one-suspect vertical slice; Phase 2H added the reasoning
architecture with no content to run it on; Phase 2I brought SUS-002 online
and authored CASE-001's first real contradiction; Phase 2J gave that
contradiction a gameplay consequence via objective sequencing; Phase 2L let
the player formally conclude once everything is done; Phase 2M authored
CASE-001's first real deduction and the objective that completes on it;
Phase 2N made the player accuse a suspect, gating the conclusion on that
choice and reporting a factual, evidence-derived resolution; Phase 2O gave
every interactable a response, put the suspects' accounts in their own
voices, linked related evidence, restated the case at the close, and
surfaced each objective's own description as a hint; M2 gave the case an
authored answer and a verdict on the player's own accusation.

Explicitly still out of scope: NPC AI/movement, voice acting, cutscene
content (Phase 5.1 added the scene player; no case authors a scene yet),
additional locations, persistence, and multiplayer/per-session state. (M6 added only an idle animation, a turn to face the speaker, and a
title-screen camera drift; M7 added branching interrogation and a third
character, the night guard, who is not a suspect.)

## Extension points (future phases)

Add cases by dropping `CaseNNN.luau` in `src/config` (or registering one
in-memory via `CaseRegistry.register`, used by the test harness). Add
interaction kinds by adding a handler to `InteractionService.HANDLERS` and
enabling it in `Interactable.EnabledKinds`. Add objectives/timeline events —
including multi-objective sequences via `prerequisites`, or a Talk+target
requirement — by extending case data only; services evaluate requirements
generically. Add a new `StoryEvents` kind only once a system actually
publishes it. Add a second playable suspect by authoring its `npcPlacement`,
a `ConversationDefinition`, and (optionally) a `StatementDefinition` in case
data — no service code changes needed. Add a real contradiction/deduction to
a case by authoring `ContradictionDefinition`/`DeductionDefinition` entries
that reference real evidence/statement ids — `ReasoningService` evaluates
them generically, no service code changes needed there either. Add an
accusable suspect by authoring an `AccusationDefinition` (optionally with a
`supportedBy` naming real contradiction/deduction ids) in case data —
`AccusationService` evaluates it generically and hardcodes no case or
accusation id. Add flavour text to a non-evidence interactable by authoring
an `ObservationDefinition` in case data — `OfficeRoom` applies it by instance
name at runtime and no service code changes are needed. Phase 5.1, all in
case data: hold an evidence prop back until the story reveals it
(`propPlacement.revealWhen`), hand evidence over in a line of dialogue
(`grantsEvidence`), and author scripted scenes (`cutscenes`) that a story
trigger plays with `CutsceneService.play`.
