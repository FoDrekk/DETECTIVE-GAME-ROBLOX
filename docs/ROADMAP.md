# Mystery Case — Development Roadmap

Written after a full audit of the repository (Phase 2O, 222/222 tests) and a
real Studio playthrough from spawn to Case Closed. Supersedes the phase-by-phase
"out of scope" lists in `ARCHITECTURE.md` as the forward plan; those sections
remain the record of what each phase deliberately did and did not build.

## The game

**Mystery Case** is a short (10–15 minute), single-player, single-location
detective game. It is night; Daniel Reyes has been found dead in his office.
The player is the investigator who arrives at the scene.

Core loop:

```
BRIEFING → EXPLORE → EXAMINE → EVIDENCE (timeline grows)
        → QUESTION SUSPECTS → STATEMENTS
        → CROSS-REFERENCE (contradictions / deductions in the Case File)
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

### M1 — Friction-free loop (UX integrity)

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

### M2 — The case has an answer (narrative)

Requires a canon decision from the product owner (who killed Daniel, and the
corrected time of death) before implementation.

- One consistent timeline across briefing, evidence, observations and
  dialogue.
- The contradiction is earned by evidence, not announced by the suspect.
- The suspects' unresolved hooks (Mara's phone records, the unanswered call)
  pay off in evidence the player can find.
- Accusation resolves to a verdict: the resolution screen tells the player
  whether they were right and what actually happened.

### M3 — The office tells the story (environment)

- Daniel's office reads as a crime scene (scene tape, outline, evidence
  markers), staged at runtime like the rest of `OfficeDetailing`.
- Wayfinding: room signage and Daniel's nameplate so "Investigate Daniel's
  office" is actionable without wandering.
- Lighting draws the eye to the desk and the reception evidence.

### M4 — A complete session (flow & finish)

- The ending has a next step (replay the case) instead of a dead end.
- Final cross-cutting polish pass from a fresh playthrough.
- Docs reconciled; performance spot-check.

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
