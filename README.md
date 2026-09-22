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

Phase 2F in progress: story-system architecture foundation, no new story
content.

- **Objective sequencing**: `ObjectiveService` derives the active objective
  from completion + data-driven `prerequisites` instead of a hardcoded first
  objective. CASE-001's single objective is unaffected.
- **Suspect/location access**: `CaseService.getSuspects`/`getLocations` (and
  singular lookups) read the case's existing authored data. Server-side only;
  not yet sent to any client.
- **NPC preparation**: `Interactable` gained an optional `SuspectId`
  attribute, parsed the same way as `EvidenceId`, for a future NPC to reuse
  the existing interactable contract. No NPC exists yet.
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

No NPCs, dialogue, interrogation, suspect AI, deduction board, contradiction
system, accusation, persistence, multiplayer, monetisation, final character
models or full exterior city yet.

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

