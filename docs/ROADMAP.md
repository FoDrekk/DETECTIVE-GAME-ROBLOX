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

## Known follow-ups (not blocking)

- **Examine close-up framing** points from the object's own facing, which
  often frames a wall; the centered evidence panel also covers the object.
  Frame from the player's side and move the panel off-center.
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
  run after every change (full suite, not just the touched file).
- Client UI: verified in a real Studio play session: screenshots plus
  inspection of live GUI state (text, transparency, layout), since the harness
  is server-side.
- Every milestone ends with a fresh spawn-to-Case-Closed playthrough and a git
  checkpoint.
- Note: running the unit suite inside a live play session drives the
  server-wide phase singleton (`GameStateService_Test`) and broadcasts it to the
  real client. Restart Play before judging the live experience.
