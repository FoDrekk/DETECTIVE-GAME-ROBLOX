# Project audit and Phase 5.5 verification

Date: 2026-09-30
Scope: the `claude/audit-phase-5-5-979a2e` worktree, repository-tracked source,
the local `origin` refs, the Roblox Studio worktree place, and Phase 5.5.

## Findings and changes

- The office's source of truth had drifted into binary-place assumptions:
  `.gitignore`, README, architecture and headless instructions still described
  `assets/Office.rbxm`, even though the office had been replaced by the
  `OfficePlan` and room builders. Removed the obsolete ignore exception and
  parser instructions, updated documentation and stale Luau comments, and
  removed RBXM conversion from the headless bundler.
- The saved office bake could lag behind its builders. The code-built layout is
  now versioned by `Config.Environment.BuilderVersion`; stale bakes are rebuilt
  at runtime and Edit-mode baking is documented. The edited worktree place has
  the current bake; an opened Studio session must save that place to persist the
  bake.
- The office plan and layout tests now enforce continuous floor coverage,
  connected circulation, usable doorways, reachable evidence/interactables,
  and maximum furniture occupancy. All those checks passed in Studio.
- The manual Studio test runner's default five-second test ceiling timed out
  the full-case playthrough on this Studio run. Raised that runner's bounded
  ceiling to 15 seconds and made it print each failure; the full suite then
  completed with 466 passed and 0 failed.
- Added `.gitattributes` so Luau, JavaScript, Python, docs and data files use
  LF consistently, while Roblox binary place/model files remain binary.
- Phase 5.5 adds data-validated CASE-001 intro and dawn scenes, client-only
  scene sets, camera movement/easing/handheld and focus treatment, lighting
  presets, sound cues, captions/title cards, and hold-to-skip. It keeps the
  existing evidence progression and case interactions intact.

## Verification

- Roblox Studio `UnitTestRunner`: **466 run, 466 passed, 0 failed**.
- `OfficePlan_Test` and `OfficeLayout_Test` passed, including room reachability,
  doorway clearance, evidence placement, and furniture/circulation thresholds.
- Cutscene validation tests passed for every CASE-001 intro/outro shot and all
  referenced sets, lighting presets, audio cues and named actions.
- Studio Play verified the opening sequence and the hold-to-skip transition
  back into investigation. Client logs contained no intro errors.
- Studio source sync reported **108 in sync, 0 different, 0 missing, 0 extra,
  0 failed** after the final source changes.
- `node --check tools/headless/build.js` passed; the bundler emitted a 1.39 MB
  Luau test bundle from 123 mapped instances. The environment's Luau CLI reports
  `ERROR home directory not found`, so this bundle could not be executed with
  that local CLI here; the Roblox Studio suite supplies engine-backed tests.
- `git diff --check` passed. Windows Git emitted autocrlf notices; `.gitattributes`
  now declares LF for source/text and binary handling for Roblox place files.

## Repository and sync notes

- Work is isolated in the `claude/audit-phase-5-5-979a2e` branch. The office
  redesign checkpoint is committed locally; the Phase 5.5 and audit changes
  remain local until final review. Nothing has been pushed.
- The worktree source was synchronized to the specifically identified worktree
  Studio session. The main checkout and its Studio session were left untouched.
- The cached `origin/main` ref is `8a0043b` (2026-09-29), identical to the
  local `main` checkout at the audit baseline; this branch is one commit ahead
  of that base (`bf928d6`) plus the uncommitted implementation. A live
  `git ls-remote origin` check failed because GitHub credential negotiation
  returned `SEC_E_NO_CREDENTIALS`; the web view also could not fetch the repo.
  Therefore the live remote tip could not be confirmed from this environment.
  A successful local source sync is not evidence that GitHub accepts or
  publishes this work.

## Remaining release checks

- Save `MysteryCaseRoblox.rbxl` from the worktree Studio session to persist the
  current Edit-mode bake. Runtime stale-bake recovery remains in place if the
  saved file is older.
- Perform a final visual pass on target devices and verify the full intro
  completion path as well as the already-tested skip path.
- Test gamepad input on physical hardware; current verification is by binding
  and in-Studio input simulation.
