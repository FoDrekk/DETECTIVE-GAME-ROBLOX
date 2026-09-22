# Mystery Case — Architecture

Source lives on disk and is synced into Studio via Rojo. Server is authoritative
for gameplay/state/evidence/progression; the client handles input, camera and
presentation only.

## Layers

| Layer | Location | Responsibility |
|-------|----------|----------------|
| Server | `src/server` | Authoritative state, evidence, phases, world integration |
| Client | `src/client` | Input, camera, presentation, remote listeners |
| Shared | `src/shared` | Types, config, state machine, signals, contracts, logger, utilities |
| Config | `src/config` | Case data and the case registry (pure data) |
| UI | `src/ui` | Reusable theme-driven UI component factories |
| Tests | `tests/` | Headless unit tests (mapped under ServerStorage) |

Instances are mapped by `default.project.json`:

```
ReplicatedStorage.Shared      <- src/shared
ReplicatedStorage.Config      <- src/config
ReplicatedStorage.UI          <- src/ui      (requireable UI factories)
ServerScriptService.Server    <- src/server  (Script, children = services)
StarterPlayer...Client        <- src/client  (LocalScript, children = modules)
Workspace.Office              <- assets/Office.rbxm  (Studio-authored world)
ServerStorage.UnitTest        <- tests/      (RunUnitTest + Cases)
ServerScriptService.UnitTestRunner <- tests/UnitTestRunner.server.luau (Disabled)
```

## Foundation contracts (Phase 2E)

### Shared interactable contract
`src/shared/Interactable.luau` is the single source of truth for interactables.
Both `InteractionService` (server validation) and `InteractionController`
(client presentation) parse attributes through `Interactable.describe`, so the
two sides can never disagree. Attribute contract: `InteractionKind`,
`PromptLabel`, optional `EvidenceId`, optional `ReadableText`. Enabled kinds are
declared once in `Interactable.EnabledKinds`.

### Logging
`src/shared/Logger.luau` provides scoped, severity-based logging
(`DEBUG`/`INFO`/`WARN`/`ERROR`). Use `Logger.scoped("ServiceName")`; the minimum
severity comes from `Config.Logging.MinSeverity` (DEBUG suppressed by default).
Recoverable failures use `:warn`/`:error`; unrecoverable configuration errors use
`Logger.fatal`, which raises loudly. Never log hidden case/story data.

### Service lifecycle
Services expose a predictable `start()` and are initialised by
`init.server.luau` in dependency order: environment → remotes → stateless
services → event bridges → phase machine → player lifecycle → request handlers.
`init.server.luau` validates configuration up front (`Logger.fatal` if the active
case is not registered). Startup never fails silently.

### Signal naming
`CaseBriefingLoaded` carries a spoiler-safe `Types.CasePayload`
(`{ briefing: CaseBriefing }`). The older `CaseLoaded` name is gone — one signal,
one meaning.

### Tests
`tests/` maps to `ServerStorage.UnitTest`. Run headlessly in Play via:
`require(ServerStorage.UnitTest.RunUnitTest)(filter?, timeout?)`.
Results print `[PASS]`/`[FAIL]`/`[TIMEOUT]` plus a `[SUMMARY]` line.
`UnitTestRunner` is a disabled Script for manual runs.

## World vs. logic split

The office *environment* is Studio-authored and versioned as a binary model
(`assets/Office.rbxm`), mapped by Rojo to `Workspace.Office`. It owns geometry,
furniture, props, lighting fixtures and the spawn. Gameplay *logic* (evidence,
objectives, interaction, state, camera, UI) stays in Luau services.

`OfficeRoom.luau` no longer builds geometry. It only removes the default
Baseplate/SpawnLocation, applies the runtime evening lighting/atmosphere, and
validates that the authored interactables satisfy the gameplay contract.

## Server services

- **PlayerDataService** — in-memory `PlayerData` per player, `PlayerCaseState`.
- **CaseService** — case definitions + per-player progress payloads.
- **EvidenceService** — authoritative discovery; rejects duplicates. Reveals the
  matching timeline event on first discovery.
- **TimelineService** — data-driven case timeline. Events stay hidden until one
  of their source evidence items is discovered; ordered by `timeMinutes`.
- **ObjectiveService** — data-driven objective tracking. Evaluates generic
  evidence/interaction requirements from case data; owns completion.
- **InteractionService** — validates interaction requests and dispatches to
  per-kind handlers (Examine/Read/PickUp/Talk).
- **GameStateService** — shared phase machine (MainMenu/CaseBriefing/
  Investigation/CaseClosed), broadcasts phase changes.
- **OfficeRoom** — runtime lighting/spawn cleanup and authored-content validation
  for the Studio-built `Workspace.Office` environment.

## Client modules

- **InputController** — centralised input (E = interact, ESC = close).
- **InteractionController** — proximity scan, prompt data, request dispatch.
- **InteractionPromptView** — small `[E] Examine` prompt.
- **EvidencePanel** — dark investigative evidence panel.
- **CaseBriefingView** — cinematic case briefing overlay.
- **ObjectiveView** — minimal current-objective checklist + completion banner.
- **TimelineView** — case timeline overlay (discovered events only), T to open.
- **CameraController** — third-person explore + smooth examine framing.

## Data contracts

- Interactables are `CollectionService`-tagged `"Interactable"` with attributes
  `InteractionKind`, `PromptLabel`, optional `EvidenceId`; parsed exclusively via
  `src/shared/Interactable.luau`.
- Cases follow `Types.CaseDefinition`: id, title, description, suspects,
  locations, evidence, timeline, objectives.
- Evidence follows `Types.EvidenceDefinition`: id, name, description, location,
  importance, plus optional `details`, `timestamp`, `category`,
  `timelineEventId`, `relatedEvidenceIds` (plus runtime `discovered`).
- Timeline events follow `Types.TimelineEventDefinition`: id, timestamp,
  timeMinutes, title, description, sourceEvidenceIds. Only discovered events are
  ever sent to clients.
- `CaseService.buildClientPayload` returns only `Types.CaseBriefing` (id, title,
  description) so undiscovered evidence/timeline facts never reach the client.
- Objectives follow `Types.ObjectiveDefinition`: id, title, description,
  requiredEvidence, requiredInteractions, and generic `requirements`. Each
  requirement may key off `evidence` and/or `interaction` kind.
- Interaction kinds: `Examine`, `Read`, `PickUp`, `Talk`. Each maps to a handler
  in `InteractionService.HANDLERS` implementing the signature
  `(player, info) -> boolean`.

## Extension points (future phases)

Add cases by dropping `CaseNNN.luau` in `src/config`. Add interaction kinds by
adding a handler to `InteractionService.HANDLERS` and enabling it in
`Interactable.EnabledKinds`. Add objectives/timeline events by extending case
data only — services evaluate requirements generically.

## Deferred (documented, not implemented)

These are known future requirements, deliberately out of scope until their own
phase: persistence/DataStore with schema versioning, instanced per-session phase
machines for multiplayer, and automated CI wiring for the test harness.
