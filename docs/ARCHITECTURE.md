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
| Config | `src/config` | Case data and the case registry (pure data) |
| UI | `src/ui` | Reusable theme-driven UI component factories |
| Tests | `tests/` | Headless unit tests (mapped under ServerStorage) |

Instances are mapped by `default.project.json`:

```
ReplicatedStorage.Shared      <- src/shared
ReplicatedStorage.Config      <- src/config
ReplicatedStorage.UI          <- src/ui      (requireable UI factories)
ServerScriptService.Server    <- src/server  (Script, children = services)
StarterPlayer...Client        <- src/client  (LocalScript, children = modules)
Workspace.Office              <- assets/Office.rbxm  (Studio-authored world)
ServerStorage.UnitTest        <- tests/      (RunUnitTest + Cases)
ServerScriptService.UnitTestRunner <- tests/UnitTestRunner.server.luau (Disabled)
```

## Foundation contracts (Phase 2E)

### Shared interactable contract
`src/shared/Interactable.luau` is the single source of truth for interactables.
Both `InteractionService` (server validation) and `InteractionController`
(client presentation) parse attributes through `Interactable.describe`, so the
two sides can never disagree. Attribute contract: `InteractionKind`,
`PromptLabel`, optional `EvidenceId`, optional `ReadableText`, optional
`SuspectId` (identifies which suspect a Talk-kind interactable represents;
since Phase 2G, `InteractionService`'s Talk handler consumes this to start a
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
  of their source evidence items is discovered; ordered by `timeMinutes`.
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
- **InteractionService** — validates interaction requests and dispatches to
  per-kind handlers (Examine/Read/PickUp/Talk). Talk starts a conversation via
  `ConversationService`.
- **GameStateService** — shared phase machine (MainMenu/CaseBriefing/
  Investigation/CaseClosed), broadcasts phase changes. `requestConclude`
  (Phase 2L) gates the Investigation -> CaseClosed edge with a player-specific
  gameplay authorization check on top of the state machine's own graph
  validation (see below).
- **OfficeRoom** — runtime lighting/spawn cleanup and authored-content validation
  for the Studio-built `Workspace.Office` environment.
- **SuspectSpawner** (Phase 2G) — runtime placement of a physical NPC for each
  suspect that authors an `npcPlacement` (see below).
- **StoryEvents** (Phase 2F) — minimal, generic server-only publish/subscribe
  for future story systems to observe authoritative facts (see below).

## Client modules

- **InputController** — centralised input (E = interact, ESC = close, T =
  timeline, C = case file, Q = conclude investigation once offered).
- **InteractionController** — proximity scan, prompt data, request dispatch.
- **InteractionPromptView** — small `[E] Examine` prompt.
- **EvidencePanel** — dark investigative evidence panel.
- **CaseBriefingView** — cinematic case briefing overlay.
- **ObjectiveView** — minimal current-objective checklist + completion banner.
- **TimelineView** — case timeline overlay (discovered events only), T to open.
- **DialogueView** (Phase 2G) — full-screen conversation presentation; renders
  only the single server-authorized dialogue step it is given.
- **CaseFileView** (Phase 2H) — persistent investigation notes panel
  (unlocked statements/contradictions/deductions), C to open.
- **CaseClosedView** (Phase 2L) — cinematic closing overlay, shown during the
  `CaseClosed` phase; renders exactly the server's `Types.CaseClosedSummary`.
- **CameraController** — third-person explore + smooth examine framing.

## Data contracts

- Interactables are `CollectionService`-tagged `"Interactable"` with attributes
  `InteractionKind`, `PromptLabel`, optional `EvidenceId`; parsed exclusively via
  `src/shared/Interactable.luau`.
- Cases follow `Types.CaseDefinition`: id, title, description, suspects,
  locations, evidence, timeline, objectives, conversations, statements,
  contradictions, deductions.
- Evidence follows `Types.EvidenceDefinition`: id, name, description, location,
  importance, plus optional `details`, `timestamp`, `category`,
  `timelineEventId`, `relatedEvidenceIds` (plus runtime `discovered`).
- Timeline events follow `Types.TimelineEventDefinition`: id, timestamp,
  timeMinutes, title, description, sourceEvidenceIds. Only discovered events are
  ever sent to clients.
- `CaseService.buildClientPayload` returns only `Types.CaseBriefing` (id, title,
  description) so undiscovered evidence/timeline facts never reach the client.
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
(`id`, `speaker`, `text`, `next: string?`, `statementId: string?`). This
phase's conversations are deterministic and linear (`next` forms a single
chain); no branching/choice contract exists, since nothing in Case001
justifies one yet.

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
with **C**, closed with **C** or **ESC**, mutually exclusive with
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
`{ contradiction = "CONTRA-001" }`. `OBJ-001`/`OBJ-002` are unmodified. No
deduction exists for CASE-001 yet; the `deduction` gate exists so a future
one needs no second requirement system, and is proven today only by a
synthetic fixture (`ObjectiveService_Test`'s `CASE-TEST-OBJ-REASONING`).

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
- **Gameplay authorization** (`GameStateService.requestConclude`, new) — is
  *this specific player* currently allowed to use it. Reads only
  `ObjectiveService.getActiveObjectiveId(player)` (server-side player state);
  a player with no active objective left — and with real case data, so a
  data-less player can't pass this check for the wrong reason — may conclude.
  Never trusts a client-supplied completion claim of any kind.

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

Concluding is entirely player-initiated (`[Q]`, only offered once
`ObjectivePayload.allComplete` is true) — `OBJ-003` completing never
auto-transitions the phase. `CaseClosedView` (mirrors `CaseBriefingView`'s
exact cinematic pattern) shows `Types.CaseClosedSummary`: real, computed
counts (objectives/evidence/contradictions) built from server-side state at
the moment of conclusion — never a verdict, never a claim about who did what.

**Known limitation, deliberately not addressed this phase**: `GameStateService`'s
phase machine is a single, server-wide singleton, not per-player — matching
this game's real single-player-session scope everywhere else. `requestConclude`'s
authorization check is correctly per-player, but the transition it gates, once
authorized, is still the same global broadcast every other phase change already
uses. This is consistent with the rest of the codebase's explicit no-multiplayer
scope and was not something this phase's authorization fix needed to solve.

## Deliberately not implemented (Phase 2G/2H/2I/2J/2L boundary)

Phase 2G shipped a one-suspect vertical slice; Phase 2H added the reasoning
architecture with no content to run it on; Phase 2I brought SUS-002 online
and authored CASE-001's first real contradiction; Phase 2J gave that
contradiction a gameplay consequence via objective sequencing; Phase 2L let
the player formally conclude once everything is done. Explicitly out of
scope until their own phase: any suspect beyond SUS-001/SUS-002, branching
dialogue/choices, interrogation, confrontation, accusation/case resolution, a
deduction for CASE-001, a second contradiction, NPC AI/movement/animation, voice acting,
cinematic cutscenes, additional locations, persistence, and
multiplayer/per-session state. `Types.DialogueNodeDefinition.next` still
supports a linear chain only — a real choice/branch contract remains future
work, added only once a case's content actually needs it. `CaseClosed` shows
only a factual summary — no verdict, no accusation, no narrative resolution.

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
them generically, no service code changes needed there either.
