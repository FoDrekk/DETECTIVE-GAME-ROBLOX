# Headless verification (no Roblox Studio)

Roblox Studio is the real test bench for this game. These tools exist for the
times it isn't available (CI, a cloud container, a quick check before opening
Studio): they run the game's own Luau against a small stand-in for the engine
API, and type-check it against Roblox's API definitions.

They do **not** replace a Studio playtest: there is no rendering, physics,
networking, real asset loading or input. They catch logic errors, runtime
errors (nil indexing, wrong property names, bad requires), broken case data
and regressions in the test suite.

## What's here

| File | Purpose |
|------|---------|
| `RobloxShim.luau` | Headless stand-in for the engine API the game uses: data types (Vector3, CFrame, Color3, UDim2, ...), the instance tree with attributes/tags/signals, a virtual-time `task` scheduler with deferred `BindableEvent` delivery, tweens, ray casts against part boxes, R15 rig generation, `RemoteEvent` recording. |
| `build.js` | Recreates the Rojo project (`default.project.json`) on top of the shim, including `assets/Office.rbxm` converted to instances, and appends an entry script. Output is one Luau file. |
| `entry_tests.luau` | Entry: runs the server bootstrap (as Studio Play would), then the unit-test suite (`tests/cases`). |
| `entry_playthrough.luau` | Entry: a scripted end-to-end playthrough: the real server and client scripts together, driven only through player inputs (prompt targeting, the interact key, dialogue choice buttons, timeline buttons, ACCUSE). Prints a transcript. |
| `entry_scene_dump.luau` | Entry: boots the server and prints every visible part and light (for layout previews). |
| `render_scene.py` | Rough layout previews from a scene dump: a top-down plan and a few ray-cast perspective shots (numpy + pillow). Not Roblox's renderer: boxes, no shadows, flat materials -- for catching floating/overlapping/misplaced props, not for judging the look. |
| `sourcemap.js` | Writes a Rojo-compatible `sourcemap.json` so `luau-lsp analyze` can resolve Roblox-style requires without Rojo. |

## Requirements

- A `luau` CLI build (https://github.com/luau-lang/luau, `cmake` target `Luau.Repl.CLI`).
- Node.js, and `npm install rbxm-parser` (reads `assets/Office.rbxm`; point
  `RBXM_PARSER` at it if it isn't resolvable from here).
- Optional, for type checking: `luau-lsp` (https://github.com/JohnnyMorganz/luau-lsp)
  and its `scripts/globalTypes.d.luau`.

## Usage

```sh
# Unit tests (prints [PASS]/[FAIL] lines and a RESULT summary)
node tools/headless/build.js tools/headless/entry_tests.luau /tmp/tests.luau
luau /tmp/tests.luau

# End-to-end playthrough through the remotes
node tools/headless/build.js tools/headless/entry_playthrough.luau /tmp/play.luau
luau /tmp/play.luau

# Layout previews
node tools/headless/build.js tools/headless/entry_scene_dump.luau /tmp/dump.luau
luau /tmp/dump.luau > /tmp/scene.txt
python3 tools/headless/render_scene.py /tmp/scene.txt /tmp/previews

# Type check
node tools/headless/sourcemap.js > sourcemap.json
luau-lsp analyze --sourcemap=sourcemap.json --definitions=globalTypes.d.luau src
```

The unit tests use plain tables as mock players; the server's remote bridges
then `FireClient` them, which errors in Studio as well. The shim counts those
separately from genuine errors in its `RESULT` line.
