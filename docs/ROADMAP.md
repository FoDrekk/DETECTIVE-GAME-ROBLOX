# Mystery Case — Development Roadmap

Written after a full audit of the repository and a real Studio playthrough
from spawn to Case Closed. Supersedes the phase-by-phase "out of scope" lists
in `ARCHITECTURE.md` as the forward plan; those sections remain the record of
what each phase deliberately did and did not build.

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
- A new final objective (`OBJ-005`) gates on the established sequence, so the
  case cannot be closed by collecting objects alone — the player must both
  reason about the evidence and reconstruct the night.

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

## Known follow-ups (not blocking)

- **Creator Store assets.** The office furniture is code-built (PropKit)
  because Creator Store access wasn't available when M7 was made. Swapping
  hero props (chairs, monitors, plants, the espresso machine) for inspected,
  script-free Creator Store meshes would raise fidelity; PropKit's builders
  are the places to swap, one prop type at a time.

- **Examine close-up framing** points from the object's own facing, which
  often frames a wall; the centered evidence panel also covers the object.
  Frame from the player's side and move the panel off-center. (Conversations
  already do this since M6 via `CameraController.faceSubject`.)
- **The office asset itself still has Daniel's desk 4 studs up**; M6 corrects
  it at runtime. Fixing `assets/Office.rbxm` directly would let that
  correction be removed.
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
