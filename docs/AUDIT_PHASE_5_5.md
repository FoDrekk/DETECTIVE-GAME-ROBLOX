# Phase 5.5 full audit

Date: 2026-10-02
Branch: `claude/mystery-case-full-audit-1af3c9`
Baseline: `7cf0a2c` (`claude/audit-phase-5-5-979a2e`) plus the uncommitted
Phase 5.5 work from the `project-skills-discovery-bfc9e1` worktree (the
21-shot intro, the dressed sets, the room changes and its saved place). The
local repository was the source of truth; nothing was reset, reverted or
cloned over.

Scope: gameplay flow, architecture, Roblox engineering, Rojo, tests and
tooling, the CASE-001 intro, the office and the night city, and the
documentation.

## What was wrong, and what changed

### Gameplay and engineering

- **Rojo deleted the game's remotes mid-Play.** `ReplicatedStorage` is
  `$ignoreUnknownInstances: false`, so a connected Rojo session removed the
  `Signals` folder the server creates at boot, and the intro never started.
  `default.project.json` now declares `Signals` (keeping its runtime
  children). Found in Studio, fixed, re-verified in Studio.
- **A client could ask for any phase move the transition graph allowed**,
  not just the ones the UI offers. The handler now accepts exactly three:
  begin (`GameStateService.requestBegin`, new: only from `CaseBriefing`,
  only for a player with case data), conclude and replay, each guarded by
  its own function. New tests cover begin-only-from-briefing, no case data,
  and asking for the briefing mid-investigation.
- **A set that failed to build was retried on every shot and action** that
  named it, warning each time. `CutsceneSets` now remembers a failure for the
  rest of the scene.
- **Gamepad look in the lift assumed 60 fps.** `CameraController` scales
  stick look by the real frame time.
- **The player's double floated or sank** depending on avatar proportions,
  because it was placed by its root. `SetKit.avatarDouble` now takes the
  feet's position and uses the avatar's own hip height; `rootAt` and `sitOn`
  cover walking and sitting.

### The intro (CUT-INTRO)

Story, dialogue, shot count (21) and length (169 s) are unchanged. What
changed is what the shots show (details in `CASE_001_INTRO_SCREENPLAY.md` §10):

- **The city aerial showed almost nothing.** Three causes: a bank test in
  `City.luau` with its sign inverted, geometry beyond the distance where
  Roblox draws small parts, and an atmosphere dense enough to fog the rest.
  All three fixed, and the camera re-framed (lower, closer, FOV 48).
- **Street, car, forecourt and lobby** were rebuilt or re-dressed: the LRT
  guideway and piers, shophouses, sodium lamps, a lit mamak interior, a
  car that moves as one model, a tower with its name, a lobby with a
  ceiling, and the investigator walking through each.
- **The lift** has its own lighting preset (`Lift`) and a softer panel.
- **Sound:** the phone buzz stops when the hand turns it over; the motif is
  listed on every shot it plays through (a new test pins the rule).

### The office and the night city

- **The windows looked onto a dark wall.** The bake kept a legacy authored
  `Backdrop` that now stood in front of the plan's windows, the near towers
  were tall enough to block the view, the window panes used the Glass
  material (which all but hides what's behind it), and the skyline could
  stream out. Fixed: the backdrop is no longer kept, the skyline is rebuilt
  in layers (921 parts, 90 towers, 795 lit windows) inside persistent
  models, and the panes are plain transparent plastic.
- **The night atmosphere** now lives in `Config.Environment.Night.Atmosphere`
  (thin, sodium-tinted) instead of being hard-coded in `OfficeRoom`.
- `Config.Environment.BuilderVersion` is **10**.

### Review of the carried-over work

The uncommitted work from the other worktree was reviewed line by line
before being kept:

- **Whiteboard: reverted.** It had been retyped as a neat "Q3 pipeline"
  list, which contradicts the case's observation text (`Case001.luau`:
  *in Daniel's handwriting … struck through "R&L" and written a single "R"*)
  and the story bible. The approved handwritten board is back; the
  readability change (unlit text) stays.
- **`AlwaysOnTop` removed** from the whiteboard and its sticky notes: it drew
  them through walls.
- **Lift certificate restored.** The approved storyboard puts a framed
  certificate in the lift; the new control panel had replaced it. Both are
  now on the south wall.
- **Daniel's office kept.** The desk was turned round as a whole (his chair
  behind it, facing the door), and the evidence placements moved with it; the
  second cup is still on the visitor's side (EV-006). No case document pins
  the old chair angle.
- The pantry galley, the surau sign moved into reception and the lift
  control panel were kept as they are.

### Tooling and documentation

- **The headless playthrough was failing (132/176).** The shim lacked
  `Vector2` negation, `Dot` and `Cross`, and a `ValueBase`'s `Changed` didn't
  carry its value; the playthrough still drove the retired briefing screen.
  It now plays the intro through the real client: a tap doesn't skip and a
  hold does, a full showing ends on its own, a replay starts at `LIFT-OPEN`,
  every set builds and performs every action, stays out of the office, stands
  the double on its floor, and leaves nothing behind.
- **README** told readers to `require` the test runner from the command bar,
  which gives false failures, and described the retired briefing start. Both
  corrected; the hold-to-skip control is listed.
- **The intro screenplay** had lost the approved storyboard that its own §7
  refers to by shot number. It is restored as reference, with this pass's
  production notes added.
- **ARCHITECTURE** documents the intro system and the `Signals` declaration,
  and the builder version.

## Verification

| Check | Result |
|---|---|
| Headless unit tests (`entry_tests`, luau 0.740) | 471 run, 471 passed, 0 failed (after every fix in this audit) |
| Headless playthrough (`entry_playthrough`) | 351 checks, 0 failed |
| Headless engine checks (`entry_engine`) | 76 checks, 0 failed |
| Studio `UnitTestRunner` (Server, collected via `LogService.MessageOut`) | 471 run, 471 passed, 0 failed, 16.6 s |
| Studio intro, played uninterrupted | `CUT-INTRO` from `BED-WIDE`, `seconds=169`, ended `reason=finished`; control returned in the lift with the objective panel and the `[E] Examine Lift` prompt |
| Studio visual pass | Each set captured during the pass (city, street, car, Nora's call, forecourt, lobby, lift) and the office windows; issues found were fixed and re-captured, except the lift's last light change and the horizon glow (still not drawing) |
| `git diff --check` | Clean (run before commit) |

**Not verified, and why**
- The Studio runs above used the source as Rojo last synced it, before the
  final two fixes (whiteboard, lift certificate). Those two are verified
  headlessly only (tests and a scene dump), not on screen.
- Replay from the lift doors and hold-to-skip were verified headlessly, not
  re-run in Studio in this pass.
- The Studio session had the **main checkout's** `MysteryCaseRoblox.rbxl`
  open (its bake is stamped v5; Play rebuilt it at runtime and logged the
  warning). Nothing was saved into either place file. The `.rbxl` committed
  on this branch is the one carried over from the other worktree, and it
  doesn't carry a v10 bake.
- No physical gamepad, no real phone, no new performance measurement.

## Remaining issues

1. Bake and save the place at v10 (see `ROADMAP.md`, 5.6, item 1).
2. The lobby constable and the mamak rider are block figures.
3. The far horizon glow behind the skyline doesn't render at its distance.
4. The open plan reads sparse at night.
5. The studio noticeboard puts Sam (the night guard) on the firm's kitchen
   rota; probably unintended.
6. Performance on low-end devices with the larger skyline is unmeasured.

The proposal for the next step is `ROADMAP.md`, Phase 5, "5.6 proposal".
