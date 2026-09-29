# Mystery Case — Development Roadmap

Written after a full audit of the repository and a real Studio playthrough
from spawn to Case Closed. Supersedes the phase-by-phase "out of scope" lists
in `ARCHITECTURE.md` as the forward plan; those sections remain the record of
what each phase deliberately did and did not build.

> **Forward vision:** the long-term direction (Kota Arwana, the SCU, the
> connected city, CASE-001 v2 and beyond) lives in `GAME_VISION.md`. The
> "Pre-production roadmap" section below is the plan from here. The sections
> between "The game" and "Phase 3" are the record of CASE-001 v1 as built,
> including its original names (Reyes, Lane, Okafor).

## The game

**Mystery Case** is a short (10–15 minute), single-player, single-location
detective game. It is night; Daniel Reyes has been found dead in his office.
The player is the investigator who arrives at the scene.

Core loop:

```
BRIEFING → EXPLORE → EXAMINE → EVIDENCE (timeline grows)
        → QUESTION SUSPECTS → STATEMENTS
        → CROSS-REFERENCE (contradictions / deductions in the Case File)
        → RECONSTRUCT THE TIMELINE
        → ACCUSE → RESOLUTION
```

What makes it worth playing is one moment: **catching a lie with evidence you
found yourself**, then being told whether you read the case correctly. Every
system should serve that moment; nothing is added because it is technically
possible.

## Where the project stands

The **architecture is mature and should be kept**: server-authoritative,
data-driven case definitions, generic evidence/objective/reasoning/accusation
services, a clean client view layer, and a solid test harness. None of it needs
rebuilding.

What the playthrough showed is that the **player experience** is the
bottleneck, in three layers:

1. **Friction bugs** that break first impressions or can soft-lock a real
   player (blank briefing, an evidence panel only closable with the
   Roblox-reserved Escape key, misplaced HUD elements, overlapping panels).
2. **The mystery has no answer.** The case timeline contradicts itself (found
   dead "shortly after 23:00", yet the phone call "minutes before his death"
   is at 11:47 PM), the only contradiction is announced by the suspect himself
   ("whatever the keycard log says…"), and the ending is a report card that
   never says what happened.
3. **The environment does not tell the story.** Nothing marks Daniel's office
   as a crime scene or tells the player where it is.

## Milestones

### M1 — Friction-free loop (UX integrity) — done

The player can get from spawn to Case Closed without confusion, overlap, or
soft-locks. No story changes.

- Briefing text fades in (currently invisible).
- Every transient panel closes without Escape: `[E]` continues past an evidence
  readout; a clickable close control; opening the Roblox menu closes panels.
  All on-screen key hints tell the truth.
- Objective checklist rows lay out correctly across objective transitions.
- "Investigation complete" banner no longer covers the `[Q]` call to action.
- Only one primary panel at a time (dialogue/accusation close the evidence
  readout).
- HUD and interaction prompt only appear during the investigation.
- Close-up examine camera hides the player's own avatar.

### M2 — The case has an answer (narrative) — done

Canon chosen: Victor Lane killed Daniel to stop the partnership's
dissolution; Daniel was found shortly after midnight. (Taken as the
recommended default; the product owner can redirect.)

- One consistent timeline across briefing, evidence, observations and
  dialogue.
- The contradiction is earned by evidence, not announced by the suspect.
- The suspects' unresolved hooks (Mara's phone records, the unanswered call)
  pay off in evidence the player can find.
- Accusation resolves to a verdict: the resolution screen tells the player
  whether they were right and what actually happened.

### M3 — The office tells the story (environment) — done

- Daniel's office reads as a crime scene (scene tape, outline, evidence
  markers), staged at runtime like the rest of `OfficeDetailing`.
- Wayfinding: Daniel's nameplate so "Investigate Daniel's office" is
  actionable without wandering. (Other rooms were left unsigned: the
  suspects are visible through the Meeting Room glazing, and no objective
  points anywhere else.)
- Lighting: kept as tuned in Phase 2L-A (Daniel's office is already the
  warmest, brightest room); no change needed.

### M4 — A complete session (flow & finish) — done

- The ending has a next step: `[E] Investigate again` resets the player's
  case and returns to the briefing.
- Fresh spawn-to-Case-Closed-to-replay playthrough: clean console, no stale
  UI between runs.
- Docs reconciled.

### M5 — The timeline is a mechanic (investigation depth) — done

- The timeline is no longer handed to the player pre-sorted: while it is
  unestablished it presents the discovered events in a deliberately jumbled
  authored order with the clock times hidden, and the player must put them in
  the order they happened.
- The server validates the order (`TimelineService.submitSequence`) against
  the canonical chronological order it computes; a wrong, incomplete,
  duplicated or invented order is rejected. Establishing is permanent and
  per-player.
- A new final objective gates on the established sequence, so the case
  cannot be closed by collecting objects alone — the player must both reason
  about the evidence and reconstruct the night. (Since renumbered to
  `OBJ-006` as M7-M9 inserted objectives ahead of it, and M9's
  `accusationRules.opensAfter` below now lets the accusation open well
  before this objective, or the case, is done — that is the point: accusing
  early is possible, and costs what it should.)

### M6 — Production presentation (looks and sounds like a game) — done

- **Audio**: rain + drone ambience and event cues (evidence, ticks, reasoning,
  verdict), ducked under dialogue and the closing screen; licensed library
  sounds only, each verified to load.
- **Suspect characters**: R15 avatars from verified catalog body/hair ids,
  idle animation, turn to face the player, face-framed conversation camera.
- **Title screen + intro camera**: shown once per session; replays skip it.
- **Props and skyline**: Daniel's desk settled onto the floor (the office
  asset has it 4 studs up, with the evidence floating beneath it), desk props
  dressed, lettered scene tape, the chalk outline moved into the office, and a
  code-built night city outside the windows.
- **Targeting**: the interaction prompt prefers what the player faces, so the
  crowded desk no longer hands the prompt to a neighbouring object.
- Verified with a spawn-to-verdict-to-replay run in Studio (correct verdict
  sting, ducking, replay without the title) and the full suite (258 tests).

### M7 — Interrogation and a lived-in office (story + visuals) — built, awaiting a Studio pass

- **Interrogation, not exposition**: conversations branch. The investigator
  picks questions; what is on offer depends on what they know (evidence,
  statements, contradictions) and on how earlier conversations went (flags,
  entry lines). Server-authoritative: the client only ever sees the words of
  the choices it may pick. Linear conversations still work unchanged.
- **CASE-001 rewritten** around the same culprit and ids: Sam Okafor, the
  night guard (a normal person, not a suspect); three new clues (two
  espressos at 11:31, a second cup on the visitor's side, the dead lobby
  cameras with Victor's note); Victor's alibi breaks on the badge log, his
  revised story breaks on the phone, and a confrontation follows; Mara's alibi
  also breaks (a real contradiction with an innocent explanation), and
  whether you ask gently or accuse her changes what she does next.
- **Dialogue presentation**: letterbox, live speaker portrait, name and role,
  typewriter that pauses on punctuation, player lines set apart, the question
  echoed above the reply, choices by number key / mouse / touch / gamepad,
  newly opened questions marked NEW, depth of field while talking.
- **The office**: finishes by zone, a suspended ceiling, after-hours
  lighting that tells the story (Daniel's light on, most of the floor dark,
  the meeting room set for a midnight signing, a flickering records tube,
  city glow through the windows), and every block desk/chair/table replaced
  by furniture built from Roblox's own PBR materials (`PropKit`), plus room
  dressing and three new interactable flavour props. Characters get small
  wardrobe details (tie, scarf, security patch, lanyard, radio, watch).
- **Fixes found on the way**: the timeline's move buttons never reordered
  anything (since M5); re-examining a found clue did nothing; objective
  progress could be stranded if a clue was found before its objective became
  active; Daniel's office door opened into the pantry; the chalk "outline"
  was a filled silhouette; the meeting room's "glazing frame" was a solid
  slab covering the glass.
- **Verification so far (no Studio in the authoring environment):** 288 unit
  tests and an 81-check scripted playthrough (real server + real client
  scripts, driven only through player inputs) under the headless shim in
  `tools/headless`, luau-lsp type checks, and layout previews. **Still needs a
  Studio playtest** for everything the shim cannot see: the look under
  Realistic lighting, performance, camera/collision feel, fonts and UI
  layout on real screens, NPC animation with the wardrobe details.
- **No third-party models were used.** The environment could not reach the
  Roblox Creator Store to find, license-check or inspect assets, so all new
  furniture is built from parts and built-in materials. See "Known
  follow-ups".

### M8 — Stabilise and polish — built, awaiting a Studio pass

- **Cinematic case briefing**: the dark centred panel is gone. The briefing
  is a slow shot across Daniel's office (chalk outline, desk lamp still on,
  the second cup, the taped door) with a small type stack in the lower left
  (case number, title, a two-sentence hook, time and place) and a real
  Begin investigation button. The hook was tightened to match the case.
- **Character stays put during cinematics** (title and briefing).
- **Cleanup**: a stale copy of the old case, with its solution, lived in the
  base place's `ReplicatedStorage`, readable by clients. Rojo now removes it.
  Unused remotes, config values, hooks and a prop builder were removed (see
  ARCHITECTURE "Stabilisation (M8)").
- **Verification**: 288 unit tests, a 92-check scripted playthrough (now
  covering the briefing, its Begin button, the camera handoff and the
  replay), and a luau-lsp type check. **Not played in Roblox Studio**: the
  authoring environment has no Studio. See the Studio checklist in the PR.

### M9 — The detective decides (player-driven reasoning) — built, awaiting a Studio pass

- **Contradictions are claimed.** A contradiction authored with `claim`
  never unlocks by itself. The player pairs the two facts in the Case File,
  or shows the evidence to the person who said the other thing (a presenting
  dialogue choice whose outcome `claims` it). All four CASE-001
  contradictions work both ways.
- **Deductions are answered.** A deduction with a `question` becomes an open
  question once its facts are known, and only the right answer unlocks it.
  Misses (pairings that don't conflict, wrong answers) are counted and
  briefly lock out the next try. Showing someone the wrong thing is not a
  miss.
- **Showing evidence in conversation.** A `present` choice holds the line
  and lists what the player has found. The first matching outcome wins;
  anything else gets the character's shrug.
- **Accusation as a case.** `accusationRules = { opensAfter = "OBJ-002",
  requiresCase = true }`: accusing opens once both suspects have been spoken
  to, and needs a motive (an established deduction) and a proof (an
  established contradiction). The verdict is graded Solved, Unproven or
  Wrong, each with its own epilogue, and the close reports the missteps.
  (Later, P7: a Solved case where Victor was pushed until he broke gets its
  own epilogue; accusing early with a case that holds is still Solved.)
- **Objective text gives leads, not answers** (OBJ-003..OBJ-005 reworded).
- **Old behaviour is kept** for anything without `claim`, `question` or
  `accusationRules`: the frozen legacy case and its mechanism tests are
  unchanged.
- **Verification:** 299 unit tests (11 new) and a 168-check scripted
  playthrough with two routes, both through the real UI buttons. The first
  run solves the case properly. The second misses a pairing, gets a question
  wrong, is locked out, shows Victor the wrong thing, and accuses Mara
  early, which grades as Wrong. **Not played in Roblox Studio** (not available
  in the authoring environment).

### M10 — Studio verification & polish — in progress

- **Floor z-fighting eliminated.** The authored `Shell.Floor` and the runtime
  carpet sat within 0.075 studs of each other across the same 59×47 footprint,
  flickering in the depth buffer. The shell floor is now sunk 0.10 studs below
  the carpet; room finish slabs sit a clear gap above it; every pair is
  separated by ≥0.03 studs. The shell's occluded 16-stud warehouse ceiling is
  removed.
- **Examine close-up frames from the player's side.** The camera now positions
  itself between the player and the object (like `faceSubject` already does
  for conversations), so evidence is shown against the room rather than the
  nearest wall. A slight side offset gives a three-quarter view.
- **Evidence panel offset.** The panel shifts from dead-centre to the left
  edge, so the examined object is visible beside it.
- **Headless tests on Windows without VS build tools.** A pure-JS shim
  (`tools/headless/lz4-shim.js`) replaces the native `lz4` bindings so
  `rbxm-parser` works without Visual Studio C++ build tools. The existing
  `build.js` works unchanged; the shim is applied by patching
  `node_modules/lz4/lib/utils.js` after `npm install --ignore-scripts`.
- **Verification:** 299 unit tests and a 168-check scripted playthrough,
  both green. **Awaiting a Roblox Studio playtest** for rendering, camera
  feel, collision, UI layout, NPC animation, and audio.

### Phase 3 — Release readiness — in progress

- **R1, panels fit small screens.** Case Closed (620×580), Timeline
  (520×500) and the Evidence panel (470×310) were fixed-size and would clip
  on a phone held sideways. They now shrink to the viewport through a shared
  `Components.fitToViewport`, as the Accusation and Case File panels already
  did. Verified in Studio: at a 1530×576 viewport the Case Closed panel,
  previously cut off at the top, now fits at 0.92.
- **R2, one investigator per server.** `SessionGuard` turns a second player
  away with a message. A safety net only: set **Max Players = 1** in Game
  Settings when publishing (Game Settings needs the place published first).
- **R6, "Leads followed".** The closing stats count objectives as leads
  followed rather than "Objectives n/7", which read as a failure on a solved
  case.
- **R3, replay verified in Studio** after a Solved ending with the P7
  epilogue: empty case file and timeline, first objective, accusing closed,
  Victor meets the detective fresh.
- **R4, full touch pass in the phone emulator.** Found and fixed a severe
  bug: with 5-6 dialogue choices open, the choice list's fixed 9-slot
  height needed far more room than a landscape phone has below the
  letterbox bars. On an iPhone 17 Pro / Samsung Galaxy A06 (Studio's
  device simulator), most choices rendered above the top of the screen --
  reachable by neither touch nor mouse. The panel and the choice list now
  each carry their own `UIScale` (kept in sync), sized against the real
  content height, and shrink together to fit under the letterbox; a
  separate, real bug was found and worked around along the way -- once
  anything in an `IgnoreGuiInset` screen carries a `UIScale`, it renders
  `GetGuiInset().Y` pixels higher than its declared offset. Verified on
  both devices (all 6 choices land on-screen and are tappable) and at a
  normal desktop viewport (no regression: scale clamps to 1, panel renders
  at the exact position it always did). The rest of the touch pass (title,
  briefing, talking, showing evidence, ending) held up on both devices.
- **R5, performance baseline.** Measured with LibMP in the Samsung Galaxy
  A06 device simulator (a low-end phone profile), standing in the open
  office with the skyline and most interior lights in view: ~17ms CPU /
  ~24-25ms GPU per frame (2,811 parts, 22 lights) -- GPU-bound, not CPU-
  bound. Toggling all 7 shadow-casting lights off changed nothing outside
  noise (24.45ms / 25.58ms / 25.30ms across on-off-on): shadows are not
  the cost here, so per the proposal's own scope, no shadow change was
  made. Studio's Play-mode numbers aren't a real phone's, but they're a
  fair baseline for comparing future changes against.
- **R7, the timeline puzzle is rewarded.** The closing stats end with
  "Timeline reconstructed" when the player put the night in order
  (`CaseClosedSummary.timelineReconstructed`). Shown only when earned,
  never as a missed-it callout, and it never changes the grade. The
  stats separators went from three spaces a side to two so the credit
  clears the "Investigate again" hint on the same row. Verified in Studio.
- **R8, not done: the desk is still corrected at runtime.** Rewriting
  `assets/Office.rbxm` with `rbxm-parser` (the only tool available that
  writes the binary format) was tried against a scratch copy: the output
  grew from 13 KB to 46 KB and then hung when read back, so it was not
  trusted with the real asset. The asset is untouched and
  `OfficeDetailing.settleDanielsDesk` stays. The safe way to do this is in
  Studio by hand (see "Known follow-ups").

## Pre-production roadmap (after Phase 3)

The order follows the owner's priority list (`DESIGN_DECISIONS.md` OD-10):

1. finish CASE-001 QA;
2. story bible;
3. intro;
4. narrative payoff;
5. CASE-002 concept;
6. a small connected proof of concept;
7. only then expand.

Items 2, 3 and 5 exist as design documents for review. Every phase starts with
a proposal the owner reviews before implementation (OD-12).

### Phase 4 — CASE-001 v1 release QA

| | |
|---|---|
| **Goal** | Ship the current case cleanly on PC |
| **Player-facing** | A polished, published CASE-001 v1 |
| **Work** | Merge the Phase 3 PR; Max Players = 1 at publish; one real-gamepad pass; **a real-client PC performance baseline** (Studio's numbers carry editor overhead); R8 by hand in Studio if wanted |
| **Depends on** | — |
| **Complexity** | Low |
| **Risks** | None significant |
| **Not yet** | Any v2 content |

### Phase 5 — CASE-001 v2 and the intro

| | |
|---|---|
| **Goal** | The first 20 minutes feel like a real game with its own identity |
| **Player-facing** | The cinematic opening (cold open, city, Nora, the lift); a Malaysian cast and firm; the phone-unlock payoff; the watch data; *Nobody Told Him*; a dawn outro |
| **Work** | Localisation per `CASE_001_V2_STORY_BIBLE.md` §5; new evidence EV-008 to 012, CONTRA-005/006, DEDUCT-005/006; the continuity fixes; the capabilities in `WORLD_SCALABILITY.md` A9 (`revealWhen`, `grantsEvidence`, a cinematic sequencer); intro sets after the animatic test |
| **Depends on** | Phase 4; owner review of the story bible and screenplay |
| **Complexity** | Medium |
| **Risks** | Intro scope creep; set art; a localisation review |
| **Not yet** | Hub, districts, new tools |

**Owner decisions (2026-09-29):**
- D-05, D-07/08 and D-27 are approved.
- D-10 is revised: the phone's evidence must stay reachable by investigation.
  The two-route design ("two ways into the phone") is approved, with its clue,
  question, Meera line and engine option (`DESIGN_DECISIONS.md` D-10).
- Step 5.1 is approved as built, including its defaults: only code-built props
  can be gated; handed-over evidence gets an in-conversation notice; a scene is
  skipped with two presses.
- v2 replaces v1 as the playable CASE-001. v1 lives on in git history only.
- The new proofs and motives join the accusation choices. The verdict
  thresholds stay unless the new story logic concretely contradicts them.
- No new scoring, XP, meters or RPG mechanics.

**Steps.** Each one is reviewed before the next starts.

| Step | What | Status |
|---|---|---|
| 5.0 | Owner sign-off on the story items | Done (above) |
| 5.1 | Engine capabilities: `revealWhen`, `grantsEvidence` and the cutscene player; no story content (`ARCHITECTURE.md`, "Story engine capabilities") | **Approved (built and tested)** |
| 5.2 | Localisation and continuity fixes, same case structure (`CASE_001_V2_LOCALISATION_SHEET.md`) | **Done and synced (362 unit, 179 playthrough, 76 engine checks; Studio Play Mode verified).** Timing decision C applied (badge-out 10:28, lift 10:29). Briefing shot left for 5.5 (D4B) |
| 5.3 | v2 content that doesn't need the phone: EV-008 to EV-010, three new statements, CONTRA-005, DEDUCT-005/006, the badge log printed on request, the accusation's new motive and proof (`CASE_001_V2_CONTENT_SHEET_5_3.md`) | **Proposed; the sheet and five decisions await approval; nothing applied** |
| 5.4 | The payoff: the phone (per revised D-10) with EV-011/012, the 11:48 and 11:49 events, CONTRA-006 and the drawer-photo clue; the ending variants; the dawn outro | Not started |
| 5.5 | Intro: an animatic in a throwaway place first, then the sets | Not started |
| 5.6 | v2 release QA | Not started |

### Phase 6 — Connected-world proof of concept (Pelangi Square slice)

| | |
|---|---|
| **Goal** | Prove that "evidence moves you through places" feels good, before committing to a full case or city |
| **Player-facing** | A 10–15 minute playable slice: the Residensi Pelangi guardhouse, the Seri Pagi mamak, the back lane; a short lead chain using the **phone camera, "show anyone", CCTV review and address pins** (the opening act of CASE-002) |
| **Work** | `WORLD_SCALABILITY.md` A3 (locations and anchors), minimal A5 (two or three Tier-2 locals), A8 (camera, CCTV, pins), the first mesh kit (A4), a streaming test, PC profiling |
| **Depends on** | Phase 5 |
| **Complexity** | Medium–high |
| **Risks** | Art throughput; the camera check's feel; performance |
| **Not yet** | Persistence, the hub, the full CASE-002, transit |

### Phase 7 — Foundations (mostly invisible)

| | |
|---|---|
| **Goal** | Make a game of many cases possible |
| **Player-facing** | Progress saves; cases can be chosen |
| **Work** | A1 (per-player session and hub phase), A2 (progression, world state, checkpoint persistence), A6 (case folders), A7 (Case File filters) |
| **Depends on** | Phase 6's lessons |
| **Complexity** | Medium |
| **Risks** | Save and migration bugs; regressions in tested systems |
| **Not yet** | New districts |

### Phase 8 — CASE-002 and the SCU hub

| | |
|---|---|
| **Goal** | The first complete connected case, and a home base |
| **Player-facing** | *Seventeen-Seven* in full; Balai Lama's SCU office with the case board |
| **Work** | CASE-002 content per `CASE_002_CONCEPT.md`; the full A5 character registry; the hub interior |
| **Depends on** | Phases 6 and 7 |
| **Complexity** | High |
| **Risks** | Writing volume; pacing between places |
| **Not yet** | Transit, a second district |

### Phase 9 — The city grows

| | |
|---|---|
| **Goal** | Variety, memory and a second district |
| **Player-facing** | Kota Lama; LRT travel between two districts; side mysteries; CASE-003 (Records Request, Kunang's first tag); CASE-004 (a self-contained case, UV torch) |
| **Depends on** | Phase 8 |
| **Complexity** | High |
| **Not yet** | Driving, simulation systems |

### Phase 10 — Season 1 finale

| | |
|---|---|
| **Goal** | Pay off *Titik Buta* |
| **Player-facing** | CASE-005 (dashcams, scene reconstruction); CASE-006 finale; the Dossier's payoff |
| **Depends on** | Phase 9; owner approval of `LONG_TERM_MYSTERY.md` as canon |
| **Complexity** | High |

## Known follow-ups (not blocking)

- **Creator Store assets.** The office furniture is code-built (PropKit)
  because Creator Store access wasn't available when M7 was made. Swapping
  hero props (chairs, monitors, plants, the espresso machine) for inspected,
  script-free Creator Store meshes would raise fidelity; PropKit's builders
  are the places to swap, one prop type at a time.

- ~~**Examine close-up framing** points from the object's own facing, which
  often frames a wall; the centered evidence panel also covers the object.
  Frame from the player's side and move the panel off-center.~~ Resolved in
  M10: examine now frames from the player's side; evidence panel offset left.
- **The office asset itself still has Daniel's desk 4 studs up**; M6 corrects
  it at runtime. Fixing `assets/Office.rbxm` directly would let that
  correction be removed. (Phase 3 R8 tried a scripted rewrite and backed
  out; see above.) The runtime fix only runs on a fresh bake, so it costs
  nothing in the shipped place. To fix the source by hand: import
  `assets/Office.rbxm` into an empty place, move `Furniture.DanielDesk`,
  `DanielChair`, `DanielMonitor`, `DanielLamp` and `DanielGlow` exactly as
  `settleDanielsDesk` does (desk and chair down 4.00 studs, chair also 3
  studs south; monitor and lamp onto the desk top at y = 2.62), save it
  back with Studio's own "Save to File", then delete the desk, chair,
  monitor, lamp and glow moves from `settleDanielsDesk` (keep the coffee
  cup placement, which is a gameplay choice, not the height fix).
- **Suspect faces are Roblox's default dynamic head.** Classic face decals map
  poorly onto it, so none is applied; distinct faces need dynamic-head assets.
- ~~Keyboard only.~~ Resolved: touch buttons and gamepad bindings, with
  hints that follow the active device (see README "Controls").
- **Gamepad input verified by binding, not by a physical controller.**
  Studio's input tool cannot emulate a real pad; the bindings, hints and
  picker selection were checked in-engine. Worth one pass with real
  hardware before release.
- **Single-player scope.** The phase machine is server-wide, so a second
  player in the same server shares one briefing/investigation/closing phase.
  Fine for a 1-player server; per-player phases are needed for more.
  (Phase 3: `SessionGuard` now turns a second player away.)
- **Running the unit suite inside a live play session** drives that shared
  phase and broadcasts it to the real client; restart Play afterwards.

## Testing strategy

- Server logic: unit/integration tests in the existing `RunUnitTest` harness,
  run after every change (full suite, not just the touched file). The same
  suite also runs headlessly without Studio (`tools/headless`, see its
  README), along with a scripted end-to-end playthrough through the real
  client scripts.
- Client UI: verified in a real Studio play session: screenshots plus
  inspection of live GUI state (text, transparency, layout), since the harness
  is server-side.
- Every milestone ends with a fresh spawn-to-Case-Closed playthrough and a git
  checkpoint.
- Note: running the unit suite inside a live play session drives the
  server-wide phase singleton (`GameStateService_Test`) and broadcasts it to the
  real client. Restart Play before judging the live experience.
- **Run the Studio suite through `ServerScriptService.UnitTestRunner`**
  (enable it, then Play), not by `require`-ing `RunUnitTest` from the command
  bar or an MCP call:
  - Those contexts get their own, never-started copies of the server modules.
  - Tests that depend on listeners registered at boot (for example, a
    contradiction claimed by showing evidence) then fail for the wrong reason.
- **Unit tests never wait in real time.** A full run in Studio floods the
  Output with the expected mock-player errors, which stalls the engine. Time
  goes through a seam instead (`CutsceneService.useClock`).
- **Phase 5.1 adds `tools/headless/entry_engine.luau`:** the new engine
  capabilities, end to end through the real client, on a fixture case.
