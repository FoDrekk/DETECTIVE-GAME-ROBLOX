# Session Report — 3 October 2026

Branch: `phase56-port` · 6 commits, all pushed to `origin/phase56-port` · working tree clean.

## Commits

| Commit | Title |
|---|---|
| `2f510e2` | Phase 5.6: midnight pass, Arif Rahman, R15 extras, builder v13 |
| `fbf917e` | Cutscene quality pass: midnight everywhere, lobby lift bank, street detail |
| `b2e416f` | 5.6 regression pass: wall-sign mounting, whiteboard notes, builder v14 |
| `3e77178` | Polish pass: spatial ambience, living NPCs, window rain, camera feel |
| `e232ff9` | Office audit fix: wall-clipping ficus, builder v16 |
| `fe272ea` | Cutscene audit fix: BED-WIDE camera passes through the south wall |

## 1. Phase 5.6 completion

- Full repo audit; PR #10/#11 confirmed merged; branch state preserved.
- English-only content: removed leftover Malay/Manglish particles; signage
  relabelled (EXIT, NO SMOKING, Tap access card, VISITORS' BOOK, quiet room);
  English dispatch and reader screens.
- Arif Rahman rename completed everywhere — dialogue, statements, deductions,
  printout ("A. RAHMAN"), flavour text; 10+ docs aligned; old phase sheets
  marked historical.
- Rota → "week 3 — Priya"; open-plan desk detail (papers, second mugs, loose
  sheets); glow-only desk lamps (real light count stays at baseline).
- R15 constable + mamak rider with block-figure fallback
  (`SetKit.figureDouble`).
- Deleted `headless.project.json` (referenced retired `assets/Office.rbxm`).
- Bake v13 saved and independently verified from the reopened file.

## 2. Cutscene quality

- Midnight atmosphere: Bedroom and City sky gradients replaced (sunset orange
  → cool blue night); window spill, rain beads and the Bedroom lighting
  preset regraded.
- Modern car: contemporary sedans (metallic body, glasshouse cabin, grille,
  lamp bar) plus Malaysian plates `W 144 SCU`.
- Lobby arrival: real lift bank (three bays, "9" over the centre), entrance
  doors and matting; LOBBY-ACCESS reframed to track the crossing to the lift.
- Forecourt: patrol light bar strobes red/blue. Street: NO PARKING sign,
  bike headlamp, sodium glints under the kerb lamps.

## 3. Regression and pattern investigation (the whiteboard complaint)

- Measured every world text label — the whiteboard text itself fits
  (236.8 of 250 usable px).
- Real culprit: sticky notes positioned off the board — fixed.
- Shared pattern found: `PropKit.sign`'s −0.03 plate offset buried wall
  signs inside walls — PANTRY and NO SMOKING invisible, TAP ACCESS CARD
  edge-on through the wall, QUIET ROOM inside the door surround — all fixed
  at the source, bake v14.

## 4. Game-wide polish

- Spatial audio: rain from the north windows, city hum from the floor's
  centre (positioned emitters with roll-off).
- Window rain: beads running down the office glass (runtime particles).
- Living NPCs: per-suspect slow weight shift (verified live, 1.3° roll).
- Examine drift: hand-held sway on held close-ups (measured 0.012
  studs over 1.2 s).
- Responsive prompts: rescan on movement and look between fixed ticks.
- Records room document trolley; bake v15.

## 5. Office audit

Eight systematic checks (prop seating, prop-vs-prop, wall planes, glass,
ceilings, evidence seating, reachability, name tags). One defect: ficus
foliage clipped 0.23 studs through the west wall — trees moved, bake v16.

## 6. Cutscene audit

All six sets and 21 shots: geometry, sightline occlusion (segment/AABB),
timing, actions/presets/cues. One defect: BED-WIDE started outside the
bedroom and dollied through the south wall — fixed and verified live.
Lift doors verified blocking during the ride; mirror reflection geometry
confirmed. Kept as intentional: the aerial shots' mid-frame tower and
guideway, the lobby reader sign, the TOWER-NINTH lobby-glass opening.

## Verification status

- Headless: 471/471 unit tests, 377-check playthrough, 76-check cutscene
  engine — all green at every step.
- Studio: intro plays end to end with zero client/server errors; handoff
  position correct; unit suite 471/471 in Play.
- Performance: ~16.5 ms average frame / 60 fps / worst 23 ms (PC) across
  office, city and street views.
- Saved `.rbxl`: reopened and verified at each bake (v13 → v16); signs
  flush, notes on the board, no foliage clipping.

## Outstanding

- Footsteps: deferred — no licensed-library (ProSoundEffects/APM) carpet
  footstep exists; the project rule blocks unknown-creator uploads.
- Phase 6 proposal (Release Hardening: persistence, settings, mobile QA,
  publish pipeline): drafted, on hold awaiting approval.
