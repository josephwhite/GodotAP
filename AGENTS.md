# GodotAP for Godot 3

A file for [guiding coding agents](https://agents.md/).

## Session & Repo Guidelines

- Never commit/push/open PRs/open issues.
- Maintain `commit.txt` as a final-state changelog:
    - One [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/#specification) bullet per committed change, in final overview form. 
    - No intermediate/journey states and iteration history.
- Branch name must match `downpatch-3.6.0*` for CI.

## Project Goals
1. **Archipelago library + WebSocket client for Godot 3.6.**
    - Highest priority is fulfilling requirements for any Archipelago client and library.
    - Handle Websocket connect/send/receive flows to/from Archipelago servers. 
2. **Library for existing games.**
    - Must work as a reusable library in existing/pre-built games, not just custom games built around GodotAP.
    - Must utilize the Godot Mod Loader. Other modding platforms for Godot games may also be in scope.
    - Use relative paths in favor of absolute paths.
    - While targeting Godot 3.6, bug fixes and compatibility for other Godot 3.x versions are good.
3. [**Feature parity with upstream.**](#upstream-tracking)

### Upstream Tracking
- [Upstream branch](https://github.com/EmilyV99/GodotAP/tree/main)
- Latest commit reviewed: `4dfa95a`
    - As of: 2026-10-04
- Do not merge upstream. We are too far off for merges to cleanly apply.
- Re-review procedure when upstream is a remote repo: `git fetch [upstream-repo]`, then `git log --oneline`, and diff each commit with comments and whitespace stripped (`git show <sha> -w --unified=0`) to separate real behavior changes from reformatting.
- If an upstream feature can't be reasonably reimplemented due to a Godot 3.6 limitation, drop it.
- Include the upstream SHA in commit bullets with `(upstream [SHA])`

## Code Style
- Follow Godot's GDScript style guide for all GDScript code.

## GodotAP-Specific Fixes & Lessons

### Connect-Failure Invariants
- Give-up → `DISCONNECTED` (not DISCONNECTING), emits `connect_step` + `connect_failed` + `disconnected` (embedded hosts reset UI).
- `_on_ws_closed`: already-`DISCONNECTED` = no-op — never triggers accidental reconnect.
- Every wss/ws retry loop caps via `_advance_retry()` at `MAX_CONNECT_CYCLES = 5`.
- Watchdog: one-shot 7s (`CONNECT_WATCHDOG_SECS`), disarmed on connected/closed/error/give-up/disconnect.
- Expected noise: TLS `-29184` handshake error during `_process()` = wss→ws fallback, unsilenceable in 3.6 — not a bug.

### Relative Resource Paths
- All `.gd` preloads plus `.tscn`/`.tres` `ext_resource` refs are folder-relative or resolved from the runtime base dir (`archipelago.gd:_ap_base_dir` from `get_script().resource_path`). The `godot_ap/` folder therefore installs at any depth — `res://godot_ap/`, `res://addons/godot_ap/`, `res://mods-unpacked/<ModID>/…`.
- Exception: `project.godot`: autoload/theme/class registration is always absolute (engine requirement)
- **Editor resave absolutizes** `ext_resource` paths in `.tscn`/`.tres` the moment the Godot editor saves them. Enforce relative paths using pre-commit and CI.

### Location-Check Validation
- Server drops the connection on `LocationChecks`/`LocationScouts` for location ids not in this slot.
- `connection_info.slot_locations` does not include locations excluded by player settings.
- `location_exists(loc_id)` as a simple check.
- Datapackage alone is not authoritative.
- `AP_VALIDATE_LOCATION_CHECKS` adds guards for collecting/scouting locations.

### Tag-Update Coalescing
- Multiple `ConnectUpdate`s in one frame crash the server.
`_tags_update_pending` + `call_deferred` flush → one per idle frame.


### GDScript
- `Color("#rrggbbaa")` parses 8-digit hex as **ARGB** in 3.6 but **RGBA** in Godot 4 — don't assume hex colors round-trip through `Color()` / `Color.to_html()`. 3.6 ports must parse 8-digit hex manually to match Godot 4 (reference-client) semantics.
- `parse_json` returns floats for every number — `int()` at ingestion, never feed JSON numbers into dict lookups (see [DOWNPATCH.md §parse_json](docs/DOWNPATCH.md)).

## Tools
- pwsh
- [`pre-commit`](\.pre-commit-config.yaml)

### Commands

```bash
# Setup pre-commit
pip install pre-commit
pre-commit install
pre-commit install-hooks # pre-build the gdtoolkit 3.6.0 env

# Run pre-commit
pre-commit run
```

## Tests

- **GUT version: 7.4.3** (Godot 3.x).
- Configuration: [`.gutconfig.json`](.gutconfig.json)
- Rules:
    - Do not use real Archipelago servers. Mocks in integration tests should use a duck-typed fake socket.
    - Do not use real Archipelago datapackages. Mock `DataCache` in tests with fake locations and items.
    - Assert on captured signals for error logging, not stderr. Connect the signal under test in `before_each`, collect into an array, assert after the action.

### Commands
```bash
# Run tests headless on Godot 3.6
Godot_v3.6.exe --no-window --path . -s addons/gut/gut_cmdln.gd -gexit
```

## Directory Structure
```perl
.github/                    # GitHub config.
└── workflows/              # CI pipelines.
addons/                     # Godot add-ons.
docs/                       # Documentation.
godot_ap/                   # Library root (installable at any depth).
├── ap_files/               # AP data classes.
├── autoloads/              # Archipelago autoload singleton.
├── managers/               # Command/config/GUI/save managers.
├── ui/                     # Console.
│   ├── console/            # Widgets and messages.
│   ├── custom_containers/  # GUI containers.
│   └── themes/             # Themed Fonts/Textures/Images.
│       └── graphics/       # Themed assets.
└── util/                   # Helpers.
hooks/                      # CI tooling.
licenses/                   # Third-party/upstream licenses.
tests/                      # All tests for GUT.
├── fixtures/               # Shared mock classes.
├── integration/            # Autoload/Signal tests.
├── results/                # Test results.
└── unit/                   # Class/Method tests.
```

## References

### GodotAP
- [GodotAP Upstream (Godot 4)](https://github.com/EmilyV99/GodotAP)
- [Engine Oddities in Custom Godot Builds (per-game build oddities and solutions)](docs/ENGINE_ODDITIES.md)
### Archipelago
- [Archipelago Network Protocol](https://github.com/ArchipelagoMW/Archipelago/blob/main/docs/network%20protocol.md)
### Godot
- [Godot 3.6 Docs](https://docs.godotengine.org/en/3.6)
    - [GDScript Style Guide](https://docs.godotengine.org/en/3.6/tutorials/scripting/gdscript/gdscript_styleguide.html)
- [Godot 3.6 Source Code](https://github.com/godotengine/godot/tree/3.6)
- [Our full generic downpatch reference](docs/DOWNPATCH.md)
### Godot Addons/Libs/Tools
- [GUT: Godot Unit Test](https://github.com/bitwes/Gut/tree/godot_3x)
    - [GUT Docs](https://gut.readthedocs.io/en/godot_3x/)
- [GDScript Toolkit](https://github.com/Scony/godot-gdscript-toolkit/tree/3.x)
    - [gdlint Docs](https://github.com/Scony/godot-gdscript-toolkit/wiki/3.-Linter) (linter only; no formatter is run)

