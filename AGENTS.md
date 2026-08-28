# GodotAP for Godot 3

A file for [guiding coding agents](https://agents.md/).

## Session & Repo Guidelines

- Never commit/push/open PRs/open issues.
- Append one brief [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/#specification) bullet to `commit.txt` for each code change, so the file reads as a running changelog summary. Track the change itself, not surrounding reasoning.

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

Full generic downpatch reference (API renames, GDScript syntax, scene/theme/resource rules, File I/O, WebSocket overhaul): **[docs/DOWNPATCH.md](docs/DOWNPATCH.md)**.

- **Verify Godot 3.6 functionality against official sources** — Godot 3.6 class docs for engine-behavior claims. Never infer availability from 4.x behavior.

## GodotAP-Specific Fixes & Lessons

This section is repo-specific application/integration notes of the DOWNPATCH rules.

### WebSocket Refactor

#### `_poll()` Control Flow Mapping

4.x `_poll()` state machine → 3.6 signal handlers:

| 4.x Code | 3.6 Equivalent |
|---|---|
| `SOCKET_CONNECTING`: `connect_to_url()`, wait `STATE_OPEN` | `_client.connect_to_url(url)` + `connection_established` signal → `_on_connected()` |
| `STATE_CLOSED` → initiate `connect_to_url()` | `ap_reconnect()` / `_on_error()` retry calls `connect_to_url()` directly |
| `STATE_CONNECTING` → poll → STATE_CLOSED: retry with `_wss` toggle | `connection_error` signal → `_on_error()` with retry |
| `STATE_OPEN` → `get_available_packet_count()` loop | `data_received` signal → `_on_data()` (fires once per message) |
| `STATE_CLOSING` → poll until closed | `disconnect_from_host()` then `connection_closed` fires |
| `send_text(data)` | `_client.get_peer(1).put_packet(data.to_utf8())` |
| `send_command()` → `_socket.send_text(s)` | `send_command()` → `_client.get_peer(1).put_packet(s.to_utf8())` |
| `send_packet()` → `JSON.stringify` + `send_text` | `send_packet()` → `to_json()` + `put_packet` |
| `inbound_buffer_size` | **No 3.6 equivalent** — WebSocketClient doesn't expose buffer size |

Refactor `_poll()` entirely. Replace state-machine polling with signal-driven approach.

`WebSocketClient` requires `poll()` each frame for signals to fire. Add `_process(delta)`:
```gdscript
func _process(delta):
    if _socket:
        _socket.poll()
```

**Known expected error noise:** `E 0:00:18.432 _do_handshake: TLS handshake error: -29184` from `modules/mbedtls/stream_peer_mbedtls.cpp` (`StreamPeerMbedTLS::_do_handshake`) during `_process()`. `-29184` = `MBEDTLS_ERR_SSL_INVALID_RECORD` — the target server answered plain HTTP to the initial `wss://` probe. This is the **expected** wss→ws fallback (wss-first is upstream `EmilyV99/GodotAP` behavior; `archipelago.gd` toggles `_wss` in `_on_ws_error` and retries over `ws://`). Connection succeeds on the fallback. **Not a bug, not a 3.6 regression** — 4.x suppresses this print, 3.6 hard-`ERR_PRINT`s it (stream_peer_mbedtls.cpp, `StreamPeerMbedTLS::_do_handshake`). Cannot be silenced from GDScript; a C++ `ERR_PRINT`. Verified safe: failed handshake path (wsl_client.cpp, `WSLClient::_do_handshake`) calls `disconnect_from_host()` (nulls `_connection`, so retry won't hit `ERR_ALREADY_IN_USE` in `WSLClient::connect_to_host` — wsl_client.cpp) then `_on_error()` → only `connection_error` fires, no `connection_closed` conflict with `ap_reconnect()`.

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

### Signals & SceneTree
- SceneTree API site conversions (`change_scene_to`, `create_timer`/`yield `idle_frame`) in `util.gd` and `archipelago.gd`.

### JSON Float-Key Hits
`parse_json` float trap (DOWNPATCH.md) applied at: `network_hint.gd` (hint status → "unknown"), `base_console.gd` (console status), `network_item.gd` (`flags` bitfield float `&` crash), `archipelago.gd` (slot_locations keys + `ReceivedItems` index).

### Fonts
- `godot_ap/util/font_storage.gd`, `godot_ap/util/util.gd` (`font_mod()`, `_get_supported_opentype_variants()`) — FontVariation features dropped.
- DynamicFont fallbacks in `.tres`: `godot_ap/ui/themes/symbols_font.tres`, `themes/basic_font.tres`, `ui/console_font.tres` — `fallback/N`, not `fallbacks = [...]`.

### Engine-Compat Settings (`casus` dict)
Custom engine builds can crash natively (0xc0000005) on constructs stock Godot handles fine — per-game build IDs, oddities, and downpatch solutions live in `docs/ENGINE_ODDITIES.md`.

- **Settings live in a `casus` Dictionary export on the `Archipelago` autoload** (not flat exports, not `AP_` prefix). All keys default `false` = stock behavior. Read via `Util._casus(key)` at call time so mods can set them before connecting.
- Key: `DISABLE_BITWISE_OPERATIONS` (route all bit tests through `Util.has_flag(flags, bit)` — gated `int(flags / pow(2, bit)) % 2 == 1`, else `flags & (1 << bit) != 0`).

### TCP Preflight & Connect-Failure Ladder
- `Util._tcp_probe(host, port, timeout_ms = 2500)` — raw `StreamPeerTCP` reachability check via `Archipelago._server_reachable()`, run before `connect_to_url` in `ap_reconnect()` and before each retry; verdict cached ~10s (`_probe_ok`/`_probe_time`, reset in `ap_connect()` on new target). Dead target → console error + graceful disconnect, WebSocketClient never touched — a **UX** guardrail, not crash protection.
- `_on_ws_error()` gives up after `MAX_CONNECT_CYCLES = 5` full wss/ws cycles (was 50 — ~2-minute hang). All give-up paths (too-many-cycles + server-unreachable) route through `_give_up_connecting(msg, tip)`: tears down socket, sets `DISCONNECTED` (**not** DISCONNECTING), emits **both** `connect_step(msg)` and `disconnected` so embedded hosts reset their UI.
- Retries paced by one-shot `SceneTreeTimer(0.25 * _connect_attempts)` → `_retry_dial()` (no-op unless still-`SOCKET_CONNECTING`); scheme flips + cycle counting live in shared `_advance_retry()`, used by both the error-event path and instant `connect_to_url` failures so every loop terminates at the cap.
- `_on_ws_closed`: already-`DISCONNECTED` status = no-op — late close events after give-up must not trigger the accidental-reconnect branch.

**Interim warning (custom builds):** set `AP.casus["DISABLE_BITWISE_OPERATIONS"] = true` before connecting (see `docs/ENGINE_ODDITIES.md`). Delete this warning once the vendored mod re-syncs past the commit adding these keys.

## Tools
- Check for Godot 3.x Engine/Editor installations for running a CLI `--editor --quit` test for parse/class-registration errors.

## References

### GodotAP
- [Engine Oddities in Custom Godot Builds (per-game build oddities and solutions)](docs/ENGINE_ODDITIES.md)
- [GodotAP Upstream (Godot 4)](https://github.com/EmilyV99/GodotAP)
### Godot
- [Godot 3.6 Docs](https://docs.godotengine.org/en/3.6)
    - [Godot 3.6 GDScript Basics](https://docs.godotengine.org/en/3.6/tutorials/scripting/gdscript/gdscript_basics.html)
    - [Godot 3.6 GDScript Exports](https://docs.godotengine.org/en/3.6/getting_started/scripting/gdscript/gdscript_exports.html)
    - [Godot 3.6 WebSocketClient](https://docs.godotengine.org/en/3.6/classes/class_websocketclient.html)
    - [Godot 3.6 WebSocketServer](https://docs.godotengine.org/en/3.6/classes/class_websocketserver.html)
    - [Godot 3.6 File class](https://docs.godotengine.org/en/3.6/classes/class_file.html)
    - [Godot 3.6 Directory class](https://docs.godotengine.org/en/3.6/classes/class_directory.html)
    - [Godot 3.6 Theme overrides](https://docs.godotengine.org/en/3.6/getting_started/step_by_step/gui_skinning.html)
    - [Godot 3.6 Signals](https://docs.godotengine.org/en/3.6/getting_started/step_by_step/signals.html)
    - [Godot 3.6 StreamPeerTCP](https://docs.godotengine.org/en/3.6/classes/class_streampeertcp.html)
    - [Godot 3.6 Array class](https://docs.godotengine.org/en/3.6/classes/class_array.html)
- [Godot 3.6 Source Code](https://github.com/godotengine/godot/tree/3.6)
### Godot Addons/Libs
- [GUT — Godot Unit Test](https://github.com/bitwes/Gut)
### Archipelago
- [Archipelago Network Protocol](https://github.com/ArchipelagoMW/Archipelago/blob/main/docs/network%20protocol.md)
