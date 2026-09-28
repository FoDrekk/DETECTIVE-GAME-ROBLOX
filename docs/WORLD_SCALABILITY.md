# World Scalability — how the current game grows

Status: **review and plan.** No code changes are proposed for now. Every change
below is documented for the roadmap phase that needs it, and each will get its
own proposal before implementation. Decisions: `DESIGN_DECISIONS.md` D-39 to
D-41.

**Verdict: no rewrite.**
- The core (data-driven cases, server-authoritative services, the headless test
  harness) is the right foundation for a multi-case, multi-location game.
- What's missing is a handful of **world-level concepts** the office never
  needed: locations as places, characters outside a case, progression across
  cases, persistence, streaming.
- Each can be added beside the existing systems, one at a time, when a case
  needs it.

---

## 1. What exists (inspected 2026-09-29)

| Area | Where | Notes |
|---|---|---|
| Case data | `src/config/Case001.luau` (1,561 lines); `CaseRegistry` | Fully data-driven: evidence, statements, conversations, contradictions, deductions, accusations, solution with `solvedVariants`. Server-only (ServerStorage). |
| Case loading | `CaseRegistry.luau` | Loads every ModuleScript named `Case%d+` from `Config` or `Config/Cases`; `register()` for tests |
| Case start | `Config.Game.AutoStartCase` | A single active case |
| Phase machine | `GameStateService` + `GameStateMachine` | **One server-wide machine** (MainMenu, CaseBriefing, Investigation, CaseClosed), mirrored into `PlayerData.phase` |
| Player state | `PlayerDataService`, `Types.PlayerData` | One `caseState: PlayerCaseState` per player; in memory, no persistence |
| Players | `SessionGuard` | One investigator per server (R2) |
| Interaction | `InteractionService`, `Interactable` (CollectionService tag) | Tag-based; **server-side distance validation** (`MaxPromptDistance + 4`) |
| Evidence and reasoning | `EvidenceService`, `ReasoningService`, `TimelineService`, `ObjectiveService`, `AccusationService` | Generic over case data; facts are `FactReference { kind, id }` |
| Dialogue | `ConversationService` | Branching nodes, conditions, flags, `present` with `claims`; one conversation per suspect per case |
| NPCs | `SuspectSpawner` | Spawns the case's suspects at `npcPlacement` (absolute `Vector3`) with appearance data |
| Placement | `EvidenceDefinition.propPlacement`, `LocationDefinition.signPlacement` | **Absolute world coordinates in case data** |
| Environment | `OfficeRoom`, `OfficeInterior`, `OfficeDetailing`, `CitySkyline`, `PropKit`, `EnvironmentBake` | Code-built geometry baked in Edit mode (`Baked`/`BuilderVersion` stamps); office-specific |
| Events | `StoryEvents` | An additive, fire-and-forget server event bus for observers |
| Remotes | `Signals` (27) | Thin; payloads validated server-side |
| Tests | `tests/cases/*`, `tools/headless` | 309 unit tests plus a 179-check scripted playthrough through real client scripts |
| Performance | R5 baseline (Studio, a low-end phone profile) | About 17 ms CPU and 24–25 ms GPU per frame; 2,811 parts, 22 lights; shadows not the cost |

## 2. Scales as-is

- **The case definition model.** Evidence, statements, contradictions,
  deductions, accusations and epilogue variants. CASE-001 v2 and CASE-002 fit
  it with small additions only.
- **Reasoning, grading and timeline.** They are generic over `FactReference`,
  and any fact kind pairs with any other. CASE-001 v2's Statement × Statement
  contradiction needs no change (verified in `ReasoningService` and
  `CaseFileView`).
- **Dialogue.** Branching, conditions, flags and `present`. "Show anyone" in
  CASE-002 is the same outcome model applied to more characters.
- **Server authority.** Case data never replicates, the client only renders
  payloads, and interactions are range-checked on the server. Keep this
  exactly.
- **CaseRegistry.**
  - Rojo turns a folder with `init.luau` into a ModuleScript named after the
    folder.
  - So a **`Case002/` folder** (with `init.luau` plus sub-modules) is still a
    ModuleScript named `Case002`, and the existing `^Case%d+$` scan loads it
    unchanged.
- **StoryEvents.** A ready-made hook for cross-case observers (the Dossier,
  Tier-2 memory) that doesn't touch the gameplay pipeline.
- **The test harness.** Per-case headless playthroughs are a copy of the
  existing pattern.
- **Single-player** (OD-06). One player per server removes whole classes of
  problems: shared phase, contention, replication of other players' case
  state.

## 3. Stays case-specific

- Story text, dialogue, reveal and epilogues.
- The puzzle graph: which facts exist, which pairs contradict, which questions
  are asked.
- Bespoke props and one-off scripted moments (the phone unlock, a lift trip
  log).
- A case's time of day and weather (case time, D-26).
- Objective wording (the pacing spine stays per case).

## 4. Needs abstraction later

Each item names its **trigger**: the roadmap phase that needs it. Nothing is
done ahead of its trigger.

### A1. Session state per player, and a hub phase
- **Now.** One server-wide phase machine. It is correct for one player per
  server, and it already mirrors into `PlayerData.phase`.
- **At scale.** The hub, free roam between cases, and several cases.
- **Change.**
  - Make the per-player phase authoritative.
  - Add `Hub` (between cases) and keep `Investigation` meaning "inside the
    active case".
  - The server-wide machine becomes a thin wrapper, or goes away.
- **Trigger:** Phase 7 (Foundations), before the hub exists.
- **Not tonight.** The brief forbids rewriting GameStateService, and nothing
  needs it yet.
- **Risk:** medium. `GameStateService_Test` pins today's behaviour; the change
  is migrating those tests, not redesigning them.

### A2. Progression and persistence
- **Now.** One in-memory `caseState`.
- **Change.**
  - `PlayerData.cases: { [caseId]: PlayerCaseState }`, plus `activeCaseId`.
  - A small `WorldState`: completed cases, tool unlocks, Tier-2 memory flags,
    Dossier facts.
  - Saved with DataStores **at checkpoints only**: case start, accusation,
    case close.
  - A schema `version` field and migration tests.
  - Mid-case saves only once cases exceed about 30 minutes.
- **Trigger:** Phase 7.
- **Not tonight:** no DataStores (brief).
- **Risk:** medium. Save failures and migrations. Mitigate with retries, a
  session lock (single-player makes this simple) and version tests in the
  headless harness.

### A3. Locations as places, with anchors
- **Now.** `LocationDefinition` is a name plus an optional sign. Every NPC and
  prop placement in case data is an **absolute Vector3**, welded to the office's
  coordinates.
- **Change.**
  - A **Location registry**, world data rather than case data:
    `{ id, district, displayName, streamingRegion, anchors }`.
  - Anchors are named, tagged `Attachment`s (or parts) inside the location's
    model: `Pelangi.Guardhouse.LogBook`, `Delima.L9.Reception.Printer`.
  - Case data refers to **anchor IDs**, not coordinates. A location can then be
    rebuilt or moved without editing cases.
  - CASE-001 keeps working through a compatibility path that treats absolute
    positions as "anchor: world".
- **Trigger:** Phase 6 (the proof-of-concept slice is the first place built
  on anchors).
- **Risk:** low, and it pays for itself on the first rebuild.

### A4. Environment pipeline
- **Now.** Geometry is code-built (`PropKit`, the Office builders) and baked in
  Edit mode.
  - That's fine for one office.
  - It doesn't scale to districts: authoring speed, visual quality, and part
    count on PC.
- **Change.**
  - Districts are **authored models**: meshes, built in Blender or taken from
    inspected Creator Store assets.
  - Kits get variation (the shoplot row kit, the condo lobby kit).
  - The code builders remain for the office and as a bake tool.
  - PropKit stays useful for small dressing.
- **Trigger:** Phase 6 (the first kit, for the slice); Phase 8 (the rest of
  Pelangi Square).
- **Risk: high.** This is the real bottleneck: an art pipeline, not code. See §8.

### A5. Character registry
- **Now.** Characters exist only inside a case (`suspects`), staged by
  `SuspectSpawner`.
- **Change.**
  - A **character registry**: Tier 1 and Tier 2 people with identity,
    appearance, voice notes, home location and base lines.
  - Cases add **overlays**: conversations, knowledge, "show" reactions,
    accusability.
  - Tier 3 comes from a per-location **ambient spawner** that never touches
    case data.
  - Model: `NPC_WORLD_DESIGN.md` §4.
- **Trigger:** Phase 6 (two or three Tier-2 locals in the slice); Phase 8 (the
  full registry for CASE-002).
- **Risk:** low to medium. ConversationService already keys everything by
  suspect ID; overlays are a lookup change.

### A6. Case data layout
- **Now.** One 1,561-line module for one floor.
- **Change.** A folder per case: `Case002/init.luau` (id, title, rules,
  solution) plus `Evidence`, `People`, `Dialogue/<character>`, `Reasoning`,
  `Timeline`. `init` assembles them. CaseRegistry is unchanged (§2).
- **Trigger:** Phase 7, ahead of CASE-002 authoring.
- **Risk:** none.

### A7. The Case File at world scale
- **Now.** Two lists and a claim button. That's right for about 20 facts.
- **Change.**
  - Filters by person and place.
  - Photos as a fact kind; pinned addresses.
  - The **case board** at the hub for multi-case context and the Dossier.
- **Trigger:** Phase 7, ready for CASE-002's 30 or more facts in Phase 8.
- **Risk:** low (UI only).

### A8. Tools as data
- **Camera subjects.** Tagged details plus a server-side frame check against
  the player's camera (position, range, field of view).
- **CCTV recordings.** Authored timelines of moments, where each "markable"
  moment grants a fact.
- **Records.** Tables in case data, returned only when a justifying fact is
  cited.
- **Placement.** New server services beside EvidenceService. They emit
  ordinary evidence, so reasoning and accusation are unchanged.
- **Trigger:** Phase 6 (camera, CCTV and pins are what the slice tests).
- **Risk:** medium. The camera frame check must be server-authoritative and
  cheap.

### A9. Small v2 capabilities (CASE-001 v2)
- **Evidence revealed by a condition.** `revealWhen` on `propPlacement`, for the
  badge-log printout.
- **Evidence granted by dialogue.** `grantsEvidence`, for the phone unlock.
- **A cinematic sequencer.** Shots as data, skippable and replay-aware, for the
  intro and outro.
- **Trigger:** Phase 5.
- **Risk:** low. Each is additive and testable headlessly.

## 5. World streaming

- Turn **StreamingEnabled** on in Phase 6, for the slice. It isn't set in
  `default.project.json` today; the office didn't need it.
- **Model streaming modes:**
  - *Atomic* for any model that contains an Interactable, so a prop never
    half-streams.
  - *Persistent* for case-critical anchors near the player's objective area.
  - *Default* for dressing.
- **Interactables.** The client finds them by CollectionService tag. Streamed-in
  instances appear and streamed-out ones disappear, so the client scanner must
  listen for tag add and remove (it doesn't need to today). The server's
  distance validation is unaffected.
- **Interiors.** Streamed as regions. A case scene should never depend on an
  instance the player can't currently see.
- **Studio's `rbx-convert-to-streaming` skill** (in the Studio MCP toolset used
  on this project) is a starting point for auditing the conversion.

## 6. Performance (PC reference)

- **Target:** 60 fps on a mid-range PC at 1080p (a frame budget of about
  16.7 ms). Mobile is secondary (OD-04).
- **The baseline caveat.** R5 measured about 17 ms CPU and 24–25 ms GPU in
  Studio's device simulator. Studio adds editor overhead and the profile was a
  phone. Phase 4 includes a **real-client PC measurement** of the office, to set
  the true baseline.
- **Budgets** (to confirm by profiling the Phase 6 slice):
  - about 3,000–4,000 visible parts or meshes per streamed area;
  - no more than about 25 dynamic lights near the player;
  - shadows on key lights only;
  - Tier-3 people as simple rigs, at most about 25 visible.
- **Rules.**
  - Prefer meshes over part-built detail.
  - Bake lighting mood into materials where possible.
  - Keep code-built dressing to hero areas.

## 7. Server state and authority

- **Keep:** everything decided on the server from case data; the client sends
  intents (IDs only); payloads carry only what the player has earned.
- **New services** (camera, CCTV, records, world state) follow the same shape:
  validate the request, change state, emit a payload and fire a StoryEvent.
- **Single-player** means no shared-world locking. SessionGuard stays.

## 8. Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Art throughput** for districts | High | High | Kits with variation; one slice at a time; a named art pipeline before Phase 7 |
| **Writing volume** (each case is thousands of lines) | High | High | A story bible before code, always; the case folder layout; the headless playthrough per case |
| Save and migration bugs | Medium | High | Checkpoint saves only; a version field; migration tests; retries |
| Streaming breaks interaction | Medium | Medium | Atomic models; tag-listening client; headless tests with streamed-out props |
| PC performance at district density | Medium | Medium | Profile the slice before building more; a mesh pipeline |
| Scope creep (driving, simulation) | Medium | High | `GAME_VISION.md` "not" list; the design decision record; the owner's review gate |

## 9. Order of work

Phase numbers match `ROADMAP.md`, "Pre-production roadmap".

| Roadmap phase | Items |
|---|---|
| 4: v1 release QA | A real-client PC performance baseline |
| 5: CASE-001 v2 and intro | A9 (`revealWhen`, `grantsEvidence`, sequencer); v2 content |
| 6: Connected proof of concept | A3 (locations and anchors), A4 (the first mesh kit), minimal A5, A8 (camera, CCTV, pins); streaming; PC profiling |
| 7: Foundations | A1 (per-player session and hub phase), A2 (progression and persistence), A6 (case folders), A7 (Case File filters and board) |
| 8: CASE-002 and hub | The full A5 registry; the rest of the A4 art for Pelangi Square; the Balai Lama hub |
| 9+: The city grows | Records Request, LRT and e-hailing travel, more districts |
