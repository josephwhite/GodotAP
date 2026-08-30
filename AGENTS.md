# GodotAP for Godot 3

A file for [guiding coding agents](https://agents.md/).

## Session & Repo Guidelines

- Never commit/push/open PRs/open issues.
- Maintain `commit.txt` as a final-state changelog:
    - One [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/#specification) bullet per committed change, in final form. 
    - No intermediate/journey states and iteration history.
- Branch name must match `downpatch-3.6.0*` for CI.

## Project Goals
1. **Archipelago library + WebSocket client for Godot 3.6.**
    - Highest priority is fulfilling requirements for any Archipelago client and library.
    - Handle Websocket connect/send/receive flows to/from Arhipelago servers. 
2. **Library for existing games.**
    - Must work as a reusable library in existing/pre-built games, not just custom games built around GodotAP.
    - Use relative paths in favor of absolute paths.
3. **Feature parity with upstream.**
    - Upstream: https://github.com/EmilyV99/GodotAP
    - If an upstream feature can't be reasonably reimplemented due to Godot 3.6 limitation, drop it.

## Downpatch Reference (Godot 4 → 3.6)

[Full generic downpatch reference](docs/DOWNPATCH.md).

## GodotAP-Specific Fixes & Lessons

This section is repo-specific application/integration notes of the DOWNPATCH rules.

### WebSocket Refactor

#### `_poll()` Control Flow Mapping

4.x `_poll()` state machine → 3.6 signal handlers:

| 4.x Code | 3.6 Equivalent |
|---|---|
| `SOCKET_CONNECTING`: `connect_to_url()`, wait `STATE_OPEN` | `_socket.connect_to_url(url)` + `connection_established` signal → `_on_ws_connected()` |
| `STATE_CLOSED` → initiate `connect_to_url()` | `ap_reconnect()` / `_on_ws_error()` retry calls `connect_to_url()` directly |
| `STATE_CONNECTING` → poll → STATE_CLOSED: retry with `_wss` toggle | `connection_error` signal → `_on_ws_error()` with retry |
| `STATE_OPEN` → `get_available_packet_count()` loop | `data_received` signal → `_on_ws_data()` (fires once per message) |
| `STATE_CLOSING` → poll until closed | `disconnect_from_host()` then `connection_closed` fires |
| `send_text(data)` | `_socket.get_peer(1).put_packet(data.to_utf8())` |
| `send_command()` → `_socket.send_text(s)` | `send_command()` → `_socket.get_peer(1).put_packet(s.to_utf8())` |
| `send_packet()` → `JSON.stringify` + `send_text` | `send_packet()` → `to_json()` + `put_packet` |
| `inbound_buffer_size` | **No 3.6 equivalent** — WebSocketClient doesn't expose buffer size |

Refactor `_poll()` entirely. Replace state-machine polling with signal-driven approach.

`WebSocketClient` requires `poll()` each frame for signals to fire. Add `_process(delta)`:
```gdscript
func _process(delta):
    if _socket:
        _socket.poll()
```

**Known expected error noise:** `_do_handshake: TLS handshake error: -29184` (`MBEDTLS_ERR_SSL_INVALID_RECORD`) during `_process()` — expected wss→ws fallback: upstream is wss-first, `archipelago.gd` toggles `_wss` in `_on_ws_error` and retries `ws://`. **Not a bug, not a 3.6 regression** — 4.x suppresses this print, 3.6 `ERR_PRINT`s it (stream_peer_mbedtls.cpp, `StreamPeerMbedTLS::_do_handshake`), unsilenceable from GDScript. Verify-safe: the failed-handshake path (`WSLClient::_do_handshake`) `disconnect_from_host()`s then only `connection_error` fires — no `connection_closed` conflict with `ap_reconnect()`.

### Theme Fixes

#### Ghost Overlay: `Console_Bar_Back`/`_Front` + `show_behind_parent`
- `Console_Bar_Back`/`Console_Bar_Front` are variation types: they override some items and inherit the rest (stylebox, font_color) from their `base_type` in the **same** theme — basis of the ghost-overlay design behind `show_behind_parent`.
- `typing_bar.tscn` AutofillText must keep `show_behind_parent = true`. Without it, the full-rect ghost `LineEdit` draws ON TOP of the parent typing bar, and its inherited opaque light-theme `Console_Bar` stylebox covers the typed text (invisible in Light Mode).

#### `dark_theme.tres` Stylebox Collapse (connect box transparency)
Do not collapse all dark-theme styleboxes into one 30%-alpha `StyleBoxFlat` (upstream has ~15 distinct) — the connect box renders transparent/ghosted. Restore sub-resources:
- id=2 `Console_BG` opaque `Color(0,0,0,1)`
- id=3 `StyleBoxEmpty` for `Console_Bar` focus + `Console_Bar_Front`
- id=4 `Console_Bar` normal `Color(0.145098,0.145098,0.145098,1)`
- id=5 `Panel`/`PanelContainer` `Color(0.174028,0.174028,0.174028,1)` (connect box)
- id=6 `TooltipPanel` `Color(0.235294,0.235294,0.235294,1)`
- id=7 `TabContainer` empty
- `load_steps` 12→18

Button/CheckBox/OptionButton/MenuButton intentionally left at collapsed state (not user-visible yet).

### Setget Setters
- `godot_ap/ui/slider_box.gd` (`is_open`) — call `set_is_open()` explicitly on internal writes, incl. `_ready()`-time init.
- `godot_ap/autoloads/archipelago.gd` (`output_console`) — setter also must sync the member var itself, since ~25 internal reads bypass the getter; internal writes in `_init_console()`/`close_console()` must call `set_output_console()` explicitly.
- **`godot_ap/autoloads/archipelago.gd` (`status`)** — all internal writes must call `_set_status(APStatus.X)` so `status_updated` fires (and `conn` is nulled + reconnect queue handled on DISCONNECTED). Grep: `rg 'status\s*=\s*APStatus'`.

### Fonts
- FontVariation features dropped.
- DynamicFont fallbacks in `.tres`: `fallback/N`, not `fallbacks = [...]`.

### Relative Resource Paths
- All `.gd` preloads plus `.tscn`/`.tres` `ext_resource` refs are folder-relative or resolved from the runtime base dir (`archipelago.gd:_ap_base_dir` from `get_script().resource_path`). The `godot_ap/` folder therefore installs at any depth — `res://godot_ap/`, `res://addons/godot_ap/`, `res://mods-unpacked/<ModID>/…`.
- Exception: `project.godot`: autoload/theme/class registration is always absolute (engine requirement)
- **Editor resave absolutizes** `ext_resource` paths in `.tscn`/`.tres` the moment the Godot editor saves them. Enforce relative paths using pre-commit and CI.

### Connect-Failure Ladder
- Raw-TCP preflight disabled because empty handshake logged HTTP 400s; kept `## UNUSED` for diagnostics. Dead targets fall through to `connect_to_url` → engine `connection_error` → ladder.
- `_on_ws_error()` gives up after `MAX_CONNECT_CYCLES = 5` full wss/ws cycles (was 50 — ~2-minute hang); the retry cycle in `_advance_retry()` caps at the same limit. Every give-up routes through `_give_up_connecting(msg, tip)`: tears down socket, sets `DISCONNECTED` (**not** DISCONNECTING), emits **`connect_step(msg)`, `connect_failed(msg)`, and `disconnected`** so embedded hosts reset their UI.
- Stuck-connect watchdog: `CONNECT_WATCHDOG_SECS = 7.0` one-shot `SceneTreeTimer` armed on every dial (`ap_reconnect` async-ok + `_retry_dial`), disarmed on connected/closed/error/give-up/disconnect. Stock `WSLClient` has **no connect timeout** — silent/unanswering targets hang in `SOCKET_CONNECTING` forever; watchdog forces `_give_up_connecting` so `connect_failed` always fires. Late timer fires no-op via the `SOCKET_CONNECTING` status gate.
- Retries paced by one-shot `SceneTreeTimer(0.25 * _connect_attempts)` → `_retry_dial()` (no-op unless still-`SOCKET_CONNECTING`); scheme flips + cycle counting live in shared `_advance_retry()`, used by both the error-event path and instant `connect_to_url` failures so every loop terminates at the cap.
- `_on_ws_closed`: already-`DISCONNECTED` status = no-op — late close events after give-up must not trigger the accidental-reconnect branch.

## Tools
- [`pre-commit`](\.pre-commit-config.yaml)

## References

### GodotAP
- [Engine Oddities in Custom Godot Builds (per-game build oddities and solutions)](docs/ENGINE_ODDITIES.md)
- [GodotAP Upstream (Godot 4)](https://github.com/EmilyV99/GodotAP)
### Godot
- [Godot 3.6 Docs](https://docs.godotengine.org/en/3.6)
- [Godot 3.6 Source Code](https://github.com/godotengine/godot/tree/3.6)
### Godot Addons/Libs
- [GUT — Godot Unit Test](https://github.com/bitwes/Gut)
### Archipelago
- [Archipelago Network Protocol](https://github.com/ArchipelagoMW/Archipelago/blob/main/docs/network%20protocol.md)
