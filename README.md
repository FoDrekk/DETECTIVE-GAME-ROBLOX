# Mystery Case — Roblox

Single-player detective investigation game (working title).

This repository contains the **local Luau source code** for the game. Roblox
Studio is used for 3D world building, visual editing and play-testing; all code
lives on disk and is synchronised into Studio with **Rojo**.

## Base place

`MysteryCaseRoblox.rbxl` is the **original base place** and must be treated as
read-only. It is committed to the repository intentionally. Do not overwrite,
rebuild over, or delete it. Generated places go to `/build/` (git-ignored).

## Toolchain

Tools are pinned in `rokit.toml` and managed by
[Rokit](https://github.com/rojo-rbx/rokit).

| Tool | Version | Purpose |
|------|---------|---------|
| Rojo | 7.7.0   | Syncs disk source into Roblox Studio |

Install / restore tools:

```sh
rokit install
```

## Workflow

1. In Roblox Studio, install the **Rojo** plugin (one-time).
2. Start the Rojo server from the project root:

   ```sh
   rojo serve
   ```

3. In Studio, connect the Rojo plugin to `localhost:34872`.
4. Edit Luau files under `src/` — changes sync live into Studio.
5. Build a standalone place from source (output is git-ignored):

   ```sh
   rojo build -o build/MysteryCaseRoblox.rbxlx
   ```

> The base `MysteryCaseRoblox.rbxl` is never used as a Rojo build target.

## Project structure

```
MysteryCaseRoblox/
├─ MysteryCaseRoblox.rbxl   # original base place (do not overwrite)
├─ default.project.json     # Rojo project mapping
├─ rokit.toml               # pinned toolchain
├─ .gitignore
├─ README.md
├─ assets/
│  └─ Office.rbxm           # Studio-authored office environment -> Workspace.Office
├─ docs/                    # design docs, case bible, localisation notes
├─ tests/                   # headless unit tests -> ServerStorage.UnitTest
└─ src/
   ├─ server/               -> ServerScriptService.Server
   ├─ client/               -> StarterPlayer.StarterPlayerScripts.Client
   ├─ shared/               -> ReplicatedStorage.Shared
   ├─ config/               -> ReplicatedStorage.Config
   └─ ui/                   -> ReplicatedStorage.UI
```

## Tests

Headless unit tests live under `tests/` and run on the server during Play:

```lua
-- In the command bar during Play, or via the disabled UnitTestRunner Script:
require(game.ServerStorage.UnitTest.RunUnitTest)()          -- all
require(game.ServerStorage.UnitTest.RunUnitTest)("Timeline") -- filtered
```

Each case is a ModuleScript under `tests/cases` named `<Module>_Test`. Results
print `[PASS]` / `[FAIL]` / `[TIMEOUT]` plus a `[SUMMARY]` line.

## Status

Phase 2K: the investigation tells you when it's done.

- **"Investigation Complete" acknowledgment**: once every currently-authored
  objective (`OBJ-001` → `OBJ-002` → `OBJ-003`) is complete, the objective
  panel says so explicitly instead of silently going quiet.
- **Bug fix**: `ObjectivePayload.allComplete` had existed since Phase 2F but
  was computed wrong (it duplicated `objective.completed` instead of meaning
  "no objective remains active") and had no reader. Now correct and
  consumed by `ObjectiveView`.
- No new content, no `GamePhase` transition, no accusation/resolution — the
  player keeps playing exactly as before.

Phase 2J: the first contradiction now has a gameplay consequence.

- **`OBJ-003`** ("Review Victor Lane's Statement") completes the moment
  `CONTRA-001` unlocks — no extra interaction required. Before this phase,
  discovering the contradiction was purely informational.
- **`ObjectiveService` now reacts to reasoning**: it subscribes to
  `StoryEvents` `"ContradictionUnlocked"`/`"DeductionUnlocked"` (mirroring
  `ReasoningService`'s own subscription pattern), and `ObjectiveRequirement`
  gained two generic optional gates, `contradiction`/`deduction`, alongside
  the existing `evidence`/`interaction`/`target`. No case id or contradiction
  id is hardcoded in `ObjectiveService` — a future deduction can use the same
  gate with no new requirement system.
- No new evidence, suspect, dialogue, contradiction, or deduction was added.

Phase 2I: second suspect, first real contradiction.

- **Victor Lane (SUS-002) is now playable**: same generic pattern as Mara
  Reyes — `npcPlacement`, a `ConversationDefinition`, a `StatementDefinition`
  — authored entirely as case data, no `SuspectSpawner`/`ConversationService`
  code changes needed.
- **CASE-001's first real contradiction**: `CONTRA-001` links Victor's own
  alibi statement ("Says he left the office at 22:30. Keycard log suggests
  otherwise.") to a new, independently discoverable `EV-004` ("Keycard Log")
  evidence item, whose `details` states only that the record disagrees with
  his claim — no new timestamp or event was invented. `ReasoningService`
  evaluates it with the same generic logic Phase 2H already shipped; nothing
  in `ReasoningService` changed.
- **`OBJ-002`** ("Question Victor Lane") directs the player to him after
  `OBJ-001`, using the existing Talk+target requirement for the first time
  against a real suspect (previously only proven by a synthetic fixture).
- **Case File** now shows both suspects' statements, clearly attributed
  (`MARA REYES — ALIBI` / `VICTOR LANE — ALIBI`), and — once both facts are
  discovered — the first contradiction ever shown there.
- `EV-004` has no hand-placed counterpart in the Studio-authored office
  asset; `OfficeRoom` spawns a minimal physical prop for it at runtime from
  a new, optional `EvidenceDefinition.propPlacement` field (mirrors
  `npcPlacement`). See `docs/ARCHITECTURE.md` for why.

Phase 2H: investigation reasoning architecture (contradictions and
deductions), shipped with the mechanism proven but no real content yet.

- **`ReasoningService`**: evaluates contradiction/deduction unlock from
  already-discovered evidence and already-unlocked statements, driven purely
  by `StoryEvents` (`EvidenceDiscovered`, `StatementUnlocked`) — no polling,
  no per-frame scans, deterministic and config-driven (never inferred from
  text).
- **Case File UI**: a new persistent `CaseFileView` (`[C]` to open) lists
  unlocked statements — closing a real gap, since previously the only way to
  see the alibi statement was the transient notice during dialogue.

Phase 2G: first playable story layer — a one-suspect
encounter/talk/dialogue/completion vertical slice.

- **Suspect NPC**: Mara Reyes (SUS-001) is a static humanoid rig, spawned at
  runtime near the meeting area from her authored `npcPlacement`, tagged with
  the existing `Interactable` contract (`Talk`, `SuspectId`). No NPC-specific
  interaction path — the same `InteractionService`/`InteractionController`
  code handles her as it does Phone/Laptop/Document.
- **Conversations**: `ConversationService` is the sole authority over
  conversation state (start/advance/complete/leave), all server-side. Content
  is a deterministic, linear 3-line exchange built only from SUS-001's
  already-authored `name` and `alibi` — no invented facts.
- **Statement**: completing the conversation unlocks `STMT-SUS-001-ALIBI`,
  whose text is read live from SUS-001's `alibi` field (never duplicated).
- **Dialogue UI**: `DialogueView` renders only the single server-authorized
  line it's given; `[E]` continues, `[ESC]` closes early.
- Objectives are **not** wired to this conversation: extending `OBJ-001`
  would regress existing completion behavior, and a new objective solely to
  demo the feature would invent storyline content. The underlying
  Talk+target requirement mechanism is proven by a synthetic test case
  instead. See `docs/ARCHITECTURE.md` for the full reasoning.

See `docs/ARCHITECTURE.md` for the full breakdown, including what is
deliberately not implemented yet.

Phase 2F: story-system architecture foundation (no new story content).

- **Objective sequencing**: `ObjectiveService` derives the active objective
  from completion + data-driven `prerequisites` instead of a hardcoded first
  objective. CASE-001's single objective is unaffected.
- **Suspect/location access**: `CaseService.getSuspects`/`getLocations` (and
  singular lookups) read the case's existing authored data. Server-side only;
  not yet sent to any client.
- **NPC preparation**: `Interactable` gained an optional `SuspectId`
  attribute, parsed the same way as `EvidenceId`, for a future NPC to reuse
  the existing interactable contract. (Phase 2G gives this its first NPC.)
- **StoryEvents**: `src/server/StoryEvents.luau` is a small, additive,
  server-only publish/subscribe layer future story systems can observe
  (`EvidenceDiscovered`, `ObjectiveCompleted` today). The existing discovery
  pipeline does not depend on it.

See `docs/ARCHITECTURE.md` for the full breakdown, including what is
deliberately not implemented yet.

Phase 2E complete: the foundation is hardened and covered by automated tests.

- **Shared interactable contract** (`Shared.Interactable`) used by both client
  and server, so prompt and validation can never drift.
- **Scoped logger** (`Shared.Logger`) with DEBUG/INFO/WARN/ERROR; fatal
  misconfiguration fails loudly, recoverable failures are observable.
- **Predictable service lifecycle** with up-front configuration validation.
- **Headless test harness** (68 tests) covering the state machine, case
  registry, interactable contract, evidence, timeline, objectives, the full
  discovery pipeline, and failure handling.
- `assets/Office.rbxm` is tracked and protected from the build-output ignore rule.

Phase 2C added clue detail and the case timeline.

- **World / logic split**: the office environment is Studio-authored and
  versioned as `assets/Office.rbxm` (mapped to `Workspace.Office`); all gameplay
  logic stays in Luau services.
- Server-authoritative **objective system** (`ObjectiveService`), fully
  data-driven from case data.
- Server-authoritative **timeline system** (`TimelineService`): events stay
  hidden until their source evidence is discovered, then appear chronologically.
- **Interaction framework** with per-kind handlers: `Examine`, `Read` (for the
  Document), and `PickUp` / `Talk` foundations.
- **Evidence panel** shows name, location, category, time, description and
  details. **Timeline overlay** (`T`) lists discovered events with their sources.
- **Objective UI**: a minimal current-objective checklist with a cinematic
  completion banner.
- Evening office atmosphere: entrance/lobby, main open-plan office, Daniel's
  private workspace (primary investigation), meeting area, storage, windows onto
  a low-detail urban night backdrop.

Undiscovered information is never sent to clients: the case payload carries only
briefing presentation data.

As of Phase 2C: no NPCs, dialogue, interrogation, suspect AI, deduction board,
contradiction system, accusation, persistence, multiplayer, monetisation,
final character models or full exterior city yet. (Phase 2G added one static,
talkable suspect NPC with a linear conversation; Phase 2I added a second and
CASE-001's first real contradiction — see Status above. NPC AI/movement,
interrogation, a deduction, a second contradiction, and accusation are still
not implemented.)

### Core loop

CASE BRIEFING → INVESTIGATION → EXPLORE → EXAMINE → DISCOVER CLUE →
OBJECTIVE PROGRESS → NEXT CLUE

### Investigation flow (CASE-001)

1. Player spawns in the office lobby → server enters `CaseBriefing`; client
   shows the briefing and the **CURRENT OBJECTIVE** checklist (OBJ-001
   "Investigate Daniel's office").
2. Press **E** to begin → server enters `Investigation`.
3. Explore the office and find Daniel's desk, then Examine the Phone and Laptop
   and **Read** the Document. Each interaction is validated server-side; a dark
   evidence panel presents the discovery (with its time and details) and the
   matching timeline event is revealed.
4. Press **T** to review the **CASE TIMELINE** — discovered events only, in
   chronological order. **T** or **ESC** closes it.
5. Each required action ticks its checklist row (`□` → `✓`).
6. When all requirements are met the server completes OBJ-001 and the client
   shows **OBJECTIVE COMPLETE**.
7. Re-examining discovered evidence does not duplicate progress; invalid, wrong
   kind, and too-far interactions are rejected. Not every interactable yields
   evidence.

