# Godot 4.x → 3.6 Downpatch Reference

This section is for generic downpatch migration from Godot 4.x (4.4 in practice) to Godot 3.6.

Never infer availability from 4.x behavior.

### TabContainer API Differences (3.6)
- `set_tab_hidden(tab_idx, hidden)` in 3.6 **always advances `current_tab` to the next available tab** (tab_container.cpp, `TabContainer::set_tab_hidden`) — even when `hidden=false`. In 4.x unhiding never changes the current tab. Save the previous tab and restore it afterwards.
- `is_tab_hidden()` / `select_next_available()` / `get_tab_idx_from_control()` do **not** exist in 3.6. Bound API: `get_tab_hidden(i)`, `get_tab_disabled(i)`, `get_current_tab_control()`, `get_tab_control(i)`, `set_current_tab(i)`. Reimplement `select_next_available` as a manual wrap-around search from the previous tab index.
- A GDScript call to a nonexistent method (e.g. `tabs.is_tab_hidden(...)`) **aborts the current function silently** mid-way — statements after the offending line never run, and the error may not reach stderr. `tabs.has_method("is_tab_hidden")` guards don't help once you've already removed the method; use the bound name directly.

### `custom_minimum_size` Property
`custom_minimum_size` is **not** a Godot 3.6 `Control` property (introduced in 4.0). 3.6 uses `rect_min_size`. A tscn property like `custom_minimum_size = Vector2(200, 33)` is silently ignored at runtime → node sizes to its native minimum (e.g. LineEdit 70×38). Convert all `custom_minimum_size` → `rect_min_size` in `.tscn` and `.gd`.

### `theme_constants/` Prefix in Scenes
Godot 3.6 scene loader/`Control::_set` (control.cpp) ignores the `theme_constants/<name>` property prefix → `get_constant()` returns 0. Use `custom_constants/<name>` instead, which populates `data.constant_override` and is read by `Control::get_constant()`.

### Project Config (`project.godot`)
- `config_version=5` → `config_version=4`
- `config/features=PackedStringArray("4.4", ...)` → `config/features=PoolStringArray("3.6", ...)`
- `window/subwindows/embed_subwindows=false` → remove (not in 3.6)
- `gui/theme/custom="uid://..."` → `gui/theme/custom="res://path"`
- `renderer/rendering_method="gl_compatibility"` → `quality/driver/driver_name="GLES3"`

### WebSocket Overhaul
Godot 4 uses `WebSocketPeer` (direct poll API). Godot 3 uses `WebSocketClient` (signal-based).

**4.x pattern**:
```
var _socket: WebSocketPeer
_socket = WebSocketPeer.new()
_socket.inbound_buffer_size = N
_socket.connect_to_url(url)
_socket.poll()
_socket.get_ready_state()  # STATE_OPEN, STATE_CLOSED, STATE_CONNECTING, STATE_CLOSING
_socket.get_available_packet_count()
_socket.get_packet()
_socket.send_text(data)
_socket.close()
```

**3.6 replacement:**
```
var _client: WebSocketClient
_client = WebSocketClient.new()
_client.connect("connection_established", self, "_on_ws_connected")
_client.connect("connection_closed", self, "_on_ws_closed")
_client.connect("connection_error", self, "_on_ws_error")
_client.connect("data_received", self, "_on_ws_data")
_client.connect_to_url(url)
# Poll each frame:
_client.poll()
# Send via peer 1 (peer only exists after connection):
var _peer = _client.get_peer(1)
if _peer and _peer.has_method("set_write_mode"):
    _peer.set_write_mode(0)  # WRITE_MODE_TEXT — put_packet sends binary by default
_peer.put_packet(data.to_utf8())
# Receive (from data_received signal):
var packet = _client.get_peer(1).get_packet()
# Close:
_client.disconnect_from_host()
```

**State enum mapping:**
| 4.x `WebSocketPeer.State` | 3.6 `WebSocketClient` |
|---|---|
| `STATE_OPEN` | connection_established signal fired |
| `STATE_CLOSED` | connection_closed signal fired |
| `STATE_CONNECTING` | connection_error signal on failure |
| `STATE_CLOSING` | after `disconnect_from_host()` |

### File I/O: `FileAccess` → `File`
- `FileAccess.open(path, FileAccess.READ)` → `var f = File.new(); f.open(path, File.READ)`
- `FileAccess.WRITE` / `FileAccess.READ` → `File.WRITE` / `File.READ`
- `f.get_var(true)` → `f.get_var()` (remove bool arg)
- `f.store_var(val, true)` → `f.store_var(val)` (remove bool arg)
- `File.file_exists(p)` is a **static** method in both 4.x and 3.6 — no change needed
- `DirAccess.make_dir_recursive_absolute(p)` → `var d = Directory.new(); d.make_dir_recursive(p)`
- `DirAccess.remove_absolute(p)` → `var d = Directory.new(); d.remove(p)`
- `Directory.make_dir_recursive(path)` is an INSTANCE method in Godot 3 — must call on a `Directory.new()` instance, not as a static call

### `static func` Restrictions
In Godot 3.6, `static func` cannot call non-instance methods like `emit_signal()`, `add_child()`, etc. without an explicit instance reference.

| 4.x (works in static func) | 3.6 (fix) |
|---|---|
| `emit_signal("name", arg)` | `AP.emit_signal("name", arg)` via autoload singleton |
| `if Singleton:` check | `if Singleton: Singleton.method()` — must qualify call with singleton name |

```gdscript
# 4.x (works in static func):
static func _log(s):
    if Archipelago:
        emit_signal("_logged_message", msg)

# 3.6 (error - emit_signal non-instance from static):
static func _log(s):
    if Archipelago:
        emit_signal("_logged_message", msg)

# 3.6 (fix):
static func _log(s):
    if AP:
        AP.emit_signal("_logged_message", msg)
```

### `static var` Removal
Godot 3.6 has **no** `static var` at class scope or inside inner classes. `static func` works fine.

| 4.x | 3.6 replacement | Rationale |
|---|---|---|
| `static var x = {…}` (dict/array literal) | `const x = {…}` | Const reference, content-mutable at runtime |
| `static var x = null` (mutable scalar) | `const _x_state = {"v": null}` + `_x_state.v` | Dict wrapper holds the mutable value |
| `static var x` (no init) | `const _x_state = {"v": null}` | Same as above |
| Inner class: `static var NIL := expr` | Remove; use `null` as sentinel | Inner class can't have static or computed const |

**Why works:** `const` only prevents variable reassignment. Dict/array contents are mutable at runtime.

**Mutable scalar example (logging file):**
```gdscript
# 4.x:
static var logging_file = null
static func open_logger():
    logging_file = File.new()
    logging_file.open(...)

# 3.6:
const _log_state = {"file": null}
static func open_logger():
    _log_state.file = File.new()
    _log_state.file.open(...)
```

**Immutable dict example (color maps):**
```gdscript
# 4.x:                              
static var status_names = {         
    Status.FOUND: "Found",              
}                                    
status_names[Status.NEW] = "New"   
# 3.6:
const status_names = {
    Status.FOUND: "Found",
}
status_names[Status.NEW] = "New"  # both work
```

**Grep checklist:**
```
rg '^\s*static\s+\w+\s+' --include '*.gd'  # find all static var/const
```

#### Inline Property Setters (`:` syntax → `setget`)
Godot 4's colon-suffix inline setter syntax is **not available** in 3.6. Use `setget` keyword + separate functions.

```gdscript
# 4.x (invalid in 3.6):
var x:
    set(val): x = val
    get: return x

# 3.6:
var x setget set_x, get_x
func set_x(val): x = val
func get_x(): return x
```

**Variations:**
```gdscript
# Setter only:
var x setget set_x
func set_x(val): x = val

# Getter only:
var x setget , get_x
func get_x(): return x

# Export + setter:
export var x = "" setget set_x
func set_x(val): x = val; refresh()

# Default value + setter:
var x = false setget set_x
func set_x(val): x = val; update()
```

**Grep checklist:**
```
rg '^\s*(export\s+)?var\s+\w+.*:\s*$' --include '*.gd'
```

#### `setget` Setter NOT Called on Internal Assignment
In Godot 3, a `setget` setter fires **only on external access** (`self.x = v`, or assignment from another script/object). A plain `x = v` inside the same script **bypasses the setter entirely** (4.x calls setters on internal assignment — a silent behavior change when downporting). Code that relies on the setter to sync UI/state must call the setter explicitly.

```gdscript
# 4.x (setter runs on internal assign):
var is_open = false setget set_is_open
func set_is_open(v):
    if is_open != v:
        is_open = v
        handle_label.text = "▶" if is_open else "◀"
func slide_to(open):
    is_open = open  # setter runs, glyph updates

# 3.6 (silent bug — setter NEVER runs, glyph frozen):
func slide_to(open):
    is_open = open  # no setter call → handle_label.text never updated

# 3.6 (fix — call the setter explicitly):
func slide_to(open):
    if open == is_open: return
    set_is_open(open)
    _slide()
```

Also affects `_ready()`-time initialization (`is_open = true` must become `set_is_open(true)`). Grep for assignments to `setget` vars inside the declaring script and check each one intentionally calls the setter.

#### `export var` Requires Default Value
Bare `export var x` errors: `"Type-less export needs a constant expression assigned to infer type."`

|4.x:|3.6 (error):|Fix:|
|---|---|---|
|export var x          |export var x            |export var x = null   |
|export var items      |export var items        |export var items = [] |
|export var text       |export var text         |export var text = ""  |

**Grep:**
```
rg '^\s*export\s+var\s+\w+\s*$' --include '*.gd'
```

**Note:** `export var x = null` also fails when Godot can't infer the type — `"Can't accept a null constant expression for inferring export type."` For node references, use `export(NodePath) var x` instead. The `export(Type)` syntax only works for `Resource` subtypes, not `Node` types:

```gdscript
# 4.x (works):
export var scroll_cont = null

# 3.6 (error):
export var scroll_cont = null

# 3.6 (fix):
export(NodePath) var scroll_cont
```

In the scene file, add the variable name to `node_paths` so the NodePath auto-resolves to the actual node at runtime:
```
[node name="..." type="..." node_paths=PoolStringArray("scroll_cont")]
scroll_cont = NodePath("path/to/node")
```

#### NodePath Auto-Resolution Fails at Runtime
`export(NodePath)` + `node_paths` in scene file should auto-resolve at `_ready()` time, but **fails** in:
- `tool` scripts during `--quit` / editor mode (no scene tree)
- Before `_ready()` fires (e.g. setter called during scene construction)
- `Notification` callbacks like `NOTIFICATION_SORT_CHILDREN`, `NOTIFICATION_THEME_CHANGED`

**Pattern:** Resolve at every call site:
```gdscript
var pc = parts_cont
if pc is NodePath:
    pc = get_node(pc)
if pc:
    pc.add_child(child)
# instead of:
parts_cont.add_child(child)  # ERROR if NodePath not resolved
```

Same for property access:
```gdscript
var sc = scroll_cont
if sc is NodePath:
    sc = get_node(sc)
if sc:
    sc.scroll_vertical = 0
    var bar = sc.get_v_scrollbar()
```

**`onready` NodePath trap:** Same problem applies when `onready` reads a property that is itself an exported NodePath:
```gdscript
# WRONG — hint_console may be NodePath, not Node:
onready var hint_console = $Console.console

# Same resolution at call site:
var hc = get_node(hint_console) if hint_console is NodePath else hint_console
```

**Grep checklist:**
```
rg 'export\(NodePath\)' --include '*.gd'   # find all exported NodePaths
rg '(parts_cont|scroll_cont)\.(add_child|get_children|get_v_scrollbar|scroll_vertical)' --include '*.gd'  # unguarded calls
```

#### Preload Self-Reference Cycle
Preloading a `.tscn` that references the same `.gd` as its script = parse-time cycle in 3.6.

Error: *"Using own name in class file is not allowed (creates a cyclic reference)"*

**Fix:** Replace `const _scene = preload(...tscn)` with `load()` at call site:
```gdscript
# 4.x (cycle in 3.6):
const _scene = preload(...)
func make():
    return _scene.instance()
# 3.6:
func make():
    return load("...tscn").instance()
```

`load()` runs at call time, not parse time — breaks the cycle. Godot caches result.

#### Default Parameter Cross-Class Cycle
Default parameter values referencing an enum/const from another `class_name` class create a parse-time dependency. If that other class also references this class, circular load fails:

Error: *"The class 'X' was found in global scope, but its script couldn't be loaded."*

```gdscript
# 4.x (cycle in 3.6):
func resolve_status(loc_id, default = OtherClass.SomeEnum.VALUE):

# 3.6 (fix):
func resolve_status(loc_id, default = null):
    if default == null:
        default = OtherClass.SomeEnum.VALUE
```

Function body refs are deferred to runtime — only default parameter values and `const`/`preload` at class scope cause the cycle.

#### `var` Initializer Cross-Class Cycle
`var` initializers referencing another `class_name`'s enum/const also execute at parse time. Same fix: default to `null`, assign real value in `_init()`.

```gdscript
# 4.x (cycle in 3.6):
var my_color = OtherClass.EnumVals.NIL setget set_my_color, get_my_color

# 3.6 (fix):
var my_color = null setget set_my_color, get_my_color

func _init():
    my_color = OtherClass.EnumVals.NIL  # runtime — class already loaded
```

Note: direct `var` initializer bypasses the setter, but `_init()` assignment does NOT — the setter fires. Ensure setter is safe to call during `_init()` (no connected listeners, no tree-dependent logic).

### Missing Node: `HFlowContainer`
`console_hflow.gd` extends `HFlowContainer` which does **not exist** in Godot 3.6. Replace with custom `Container`-based flow layout. The `add_text_split()` method's word-level layout needs a reimplementation:

```gdscript
# 4.x (HFlowContainer — does not exist in 3.6):
class_name ConsoleHFlow extends HFlowContainer

# 3.6 replacement — Container with manual flow layout:
class_name ConsoleHFlow extends Container

func _notification(what):
    match what:
        NOTIFICATION_SORT_CHILDREN:
            var line_h := 0.0
            var x := 0.0
            var y := 0.0
            for child in get_children():
                var c := child as Control
                if not c: continue
                var ms := c.get_combined_minimum_size()
                if x + ms.x > rect_size.x and x > 0:
                    y += line_h
                    x = 0
                    line_h = 0
                c.position = Vector2(x, y)
                c.rect_size = ms
                x += ms.x
                line_h = max(line_h, ms.y)
```

### Theme Override API Rename
Every `add_theme_*_override("name", val)` → `add_*_override("name", val)`:
| 4.x | 3.6 |
|---|---|
| `add_theme_constant_override` | `add_constant_override` |
| `add_theme_color_override` | `add_color_override` |
| `add_theme_font_override` | `add_font_override` |
| `add_theme_stylebox_override` | `add_stylebox_override` |
| `get_theme_constant` | `get_constant` |
| `get_theme_color` | `get_color` |
| `get_theme_font` | `get_font` |
| `get_theme_font_size` | Use `get("font_size/font_size")` instead |
| `has_theme_color` | `has_color` |
| `has_theme_color_override` | `has_color_override` |
| `remove_theme_color_override` | `remove_color_override` |
| `queue_redraw()` | `update()` |

### Font Method: `get_string_size()`
| 4.x | 3.6 |
|---|---|
| `font.get_string_size(text, alignment, width, font_size)` | `font.get_string_size(text)` |

Godot 4 added alignment, width, and font_size parameters. Godot 3.6 only accepts the text string.

### Theme Overrides in Scenes
- `theme_override_constants/separation = N` → `theme_constants/separation = N`
- `theme_override_fonts/font = ...` → `theme_fonts/font = ...`
- `theme_override_colors/font_color = ...` → `theme_colors/font_color = ...`
- `theme_override_styles/panel = ...` → `theme_styles/panel = ...`

### Theme System Mechanics (3.6)
Verified against `control.cpp` / `theme.cpp` 3.6 source. Behavior is identical to 4.x — differences in rendering were downport artifacts, not theme bugs.

- `set_theme()` on an ancestor Control → `_propagate_theme_changed()` walks **all** Control descendants: assigns `data.theme_owner`, sends `NOTIFICATION_THEME_CHANGED`, invalidates color/font/style/icon caches. **Propagation STOPS at any descendant that has its own `.theme` set.**
- Theme item lookup order: nearest ancestor `theme_owner` chain → project default theme → built-in default. Colors/styleboxes resolve against the **nearest** ancestor theme, not the project theme.
- `theme_type_variation` base-type chain is built from **`Theme::get_project_default()`** (project.godot `gui/theme/custom`), not the applied theme → a variation's `base_type` must also exist in the project theme or the chain lookup breaks.

### Control Properties
- `size` → `rect_size`
- `position` → `rect_position`
- `global_position` → `rect_global_position`
- `custom_minimum_size` → `rect_min_size`
- `tooltip_text` → `hint_tooltip`
- `horizontal_alignment` → `align` (use `HALIGN_*` enum instead of `HORIZONTAL_ALIGNMENT_*`)

  Grep for missed call sites:
  ```
  rg '\.horizontal_alignment\s*=' -g '*.gd'
  ```
- `clip_contents` → remove
- `show_behind_parent` → KEEP — valid Godot 3.6 `CanvasItem` property (draws this node behind its parent). 4.x `CanvasItem.show_behind_parent`/`show_on_top` both exist in 3.6 with identical semantics.

### Window Properties

#### Property Renames
- `Window.popup_window = true` → `Window.popup = true`
- `Window.unresizable = true` → `Window.resizable = false`
- `Window.exclusive = true` → remove (not in 3.6)
- `Window.initial_position` → remove
- `Window.gui_embed_subwindows` → remove
- `Vector2i(...)` → `Vector2(...)`

#### `Window.new()` → `PopupPanel` (Dropdown Popups)
Godot 3.6 `Window` is the root viewport type — **not instantiatable** as a GUI popup.

Use `PopupPanel` (or `Popup`/`WindowDialog`) instead.

```gdscript
# 4.x (popup window):
var window := Window.new()
window.min_size = Vector2.ZERO
window.transient = true
window.exclusive = true
window.unresizable = true
window.borderless = true
window.popup_window = true
window.focus_exited.connect(window.queue_free)
window.close_requested.connect(window.queue_free)

# 3.6 replacement (PopupPanel):
var popup := PopupPanel.new()
popup.rect_min_size = Vector2.ZERO
popup.exclusive = true
popup.connect("focus_exited", popup, "queue_free")
popup.connect("popup_hide", popup, "queue_free")
# No unresizable (default), no borderless (default)
# Show via popup() instead of setting popup_window:
popup.popup(Rect2(some_position, some_size))
```

When you need a popup that fills the viewport:
```gdscript
# 4.x:
window.popup_window = true
# 3.6:
popup.popup()  # show at default position
popup.rect_position = Vector2.ZERO
popup.rect_size = get_viewport().rect.size
```

#### `get_window()` Removal (4.x only)
`get_window()` is **not available** in Godot 3.6 `Node` class. `get_window()` only exists on `Window`/`Viewport` in 3.6.

| 4.x | 3.6 Replacement |
|---|---|
| `get_window().min_size` | `OS.min_window_size` (property, set directly) |
| `get_window().title` | `OS.set_window_title("...")` |
| `get_window().rect_size` | `get_tree().get_root().size` |
| `get_window().rect_size.x` | `get_tree().get_root().size.x` |
| `get_window().size_changed` | `get_viewport().connect("size_changed", ...)` |
| `get_window().close_requested` | `get_tree().quit()` or `popup_hide` signal for popups |
| `get_window().theme = x` | `get_tree().get_root().get_child(0).theme = x` (set on root scene node) |

### Timer/AcceptDialog
Both exist in 3.6:
- `get_tree().create_timer(N)` ✓
- `AcceptDialog` ✓ (same API)
- `keep_title_visible` / `extend_to_title` → remove (not in 3.6)
- `Node.PROCESS_MODE_ALWAYS` ✓

### SceneTree API
| 4.x | 3.6 |
|---|---|
| `tree.edited_scene_root` | `Engine.get_editor_interface().get_edited_scene_root()` |
| `tree.change_scene_to_packed(scene)` | `tree.change_scene_to(scene)` |
| `await tree.process_frame` | `yield(get_tree(), "idle_frame")` |

### InputEvent API
| 4.x | 3.6 |
|---|---|
| `event.keycode` | `event.scancode` |

`InputEventKey` in 3.6 uses `scancode` property instead of `keycode`. Constant names (`KEY_*`) are the same.

### Signal Connections
Godot 4 callable style `sig.connect(target, "method")` works in 3.6.
Bare method name as value (`sig.connect(my_func)`) causes parse error — use `funcref(self, "my_func")` or string style.

`.bind(args)` works in 3.6.

`.unbind(n)` is **4.0+ only** — use wrapper lambdas instead:
```gdscript
# 4.x:
sig.connect(my_func.unbind(1))
# 3.6:
sig.connect(func(arg): my_func())
```

#### `child_entered_tree` Signal
Not available in 3.6 `Node`. Use `NOTIFICATION_CHILD_ENTERED_TREE`:
```gdscript
# 4.x:
parts_cont.child_entered_tree.connect(cb)
# 3.6:
func _notification(what):
    match what:
        NOTIFICATION_CHILD_ENTERED_TREE:
            cb(get_child(get_child_count() - 1))
```

#### `gui_input` Propagation Stops at First `MOUSE_FILTER_STOP` Ancestor
Godot 3's `Viewport::_gui_call_input` (viewport.cpp) walks from the deepest non-IGNORE control under the cursor UP the ancestor chain, but **`break`s after any ancestor with `mouse_filter == MOUSE_FILTER_STOP`**. IGNORE controls are skipped but don't stop the walk; PASS (1) processes and continues.

A decorative filler child (MarginContainer/Label/Panel) with the default STOP (0) swallows the click before the parent container's `gui_input` ever fires — the click "works" only on the few pixels where the deepest control is the container itself (e.g. the stylebox content-margin border). Symptom: "only the rightmost pixel of the button is clickable."

```gdscript
# 4.x / broken in 3.6 (children STOP by default):
# PanelContainer Handle
#   MarginContainer Margin   # STOP → eats clicks
#     Panel CustomLabel      # PASS doesn't help, STOP above breaks
# Handle.connect("gui_input", ...)  # never fires for most of the handle

# 3.6 fix — set IGNORE on decorative children so the container wins:
# [node name="Margin" type="MarginContainer" parent=".../Handle"]
#   mouse_filter = 2
# [node name="CustomLabel" type="Panel" parent=".../Handle/Margin"]
#   mouse_filter = 2
```

Leave real interactive controls (Buttons, LineEdits) at STOP. Verify by injecting `Input.parse_input_event(InputEventMouseButton)` (press+release pair — a bare press leaves `gui.mouse_focus` held and eats later clicks) across the whole control rect.

#### `Viewport.input()` Bypass Skips Everything After First Handled Event
Calling `get_viewport().input(ev)` directly from GDScript does **not** reset the SceneTree's global `input_handled` flag (only the `Input.parse_input_event` / MainLoop path resets it per event). After one GUI event marks input handled, every later direct `Viewport::input()` call no-ops. There is also no `push_input` in 3.6. Use `Input.parse_input_event(ev)` to simulate real input in tests.

### Packed Array Types
- `PackedByteArray` → `PoolByteArray`
- `PackedStringArray` → `PoolStringArray`
- `Array[int]`/`Array[String]` (typed) → `Array` (untyped)
- `Dictionary[K, V]` → `Dictionary`

### Math
- `absf(x)` → `abs(x)`
- `ceili(x)` → `ceil(x)`
- `roundi(x)` → `round(x)`
- `maxf(a, b)` → `max(a, b)`
- `randi_range(min, max)` → `min + randi() % (max - min + 1)`
- `x ** 2` (power operator) — available since 3.5 but may require spaces: `x ** 2` not `x**2`. Safer: `x * x`
- `Color.a8` → `int(color.a * 255)` (3.6 `Color` lacks byte alpha property)

### Time
- `Time.get_unix_time_from_system()` → `OS.get_unix_time()`

### JSON
- `JSON.stringify(data)` → `to_json(data)` or `JSON.print(data)`
- `JSON.parse_string(str)` → `parse_json(str)`

#### `parse_json` Returns ONLY Floats
Godot 3.6's JSON parser produces **`REAL` for every number**, integer literals included (`json.cpp`: `String::to_double()` → `TK_NUMBER` → `REAL`).

Behavior matrix — what actually breaks and what does NOT:

| Operation | Behavior | Verdict |
|---|---|---|
| `1 == 1.0` | `True` — `Variant::operator==` numeric-coerces int/float | SAFE |
| `names[k] == 1.0` (manual `==` scan) | matches int key | SAFE — `_dict_find_key` style works |
| `dict.get(2.0)` / `dict.has(1.0)` / `dict[3.0]` | `Null`/`False`/miss — **hash-based lookup, NO int/float coercion** | **BROKEN** |
| `d[2.0] = v` (store float key) | **inserts a SEPARATE float key** alongside int key (dict size grows, `d.size()` dupes) | **BROKEN** |
| `arr[1.0]` / `arr[1.0] = v` | coerces to int, no error | SAFE |
| `arr.find(2.0)` / `arr.has(2.0)` | `-1` / `False` — strict | **BROKEN** |
| `store_32(42.0)` | truncates to 42 — typed-arg coercion | SAFE |

**Real trap:** any JSON float fed into a **Dictionary lookup** (`dict.get`, `dict.has`, `dict[key]`) or **Array membership** (`find`/`has`/`in`) silently misses, and writing `dict[float]` poisons the dict with duplicate float keys. `==`-based paths (`if x == 30`, `arr[float]` index, value scans) are fine.

```gdscript
# 4.x (JSON ints can match int enum keys in some engines):
hint.status = json.get("status", Status.NOT_FOUND)   # 30.0 float
status_names.get(hint.status, "Unknown")              # MISS -> "Unknown"

# 3.6 (fix — int() cast at ingestion):
hint.status = int(json.get("status", Status.NOT_FOUND))
status_names.get(hint.status, "Unknown")              # "Priority"
```

**Dict-key hygiene:** once an int-keyed dict receives float keys (e.g. `slot_locations` fed by JSON `checked_locations`), every later `.get(float)` misses AND the float keys leak into `.keys()` and get re-sent to the server as `"123.0"`. Fix at ingestion in `archipelago.gd`: `_remove_loc`/`collect_location`/`server_checked`/`location_exists`/`location_checked`/`on_removed_id` all `int()` their keys, `ReceivedItems` uses `idx = int(json["index"])`.

Grep for JSON-fed enum lookups: check every `dict.get(json[...])` / `status_names` / `_get_status_colors()` call where the value originates from `parse_json`.

### Enum Name Changes
| 4.x | 3.6 |
|---|---|
| `HORIZONTAL_ALIGNMENT_LEFT` | `HALIGN_LEFT` |
| `HORIZONTAL_ALIGNMENT_CENTER` | `HALIGN_CENTER` |
| `MOUSE_BUTTON_LEFT` | `BUTTON_LEFT` |
| `MOUSE_BUTTON_RIGHT` | `BUTTON_RIGHT` |
| `Control.FOCUS_ALL` | `Control.FOCUS_ALL` (same in 3.6) |
| `Control.FOCUS_NONE` | `Control.FOCUS_NONE` (same in 3.6) |
| `TextServer.AUTOWRAP_WORD_SMART` | remove, use `autowrap = true` (bool) |
| `CONNECT_ONE_SHOT` | `CONNECT_ONESHOT` (note: no underscore between ONE and SHOT) |

### Resource Files (`.tres`)
- Remove `uid=` from `[gd_resource]` headers and `[ext_resource]` lines
- `FontVariation` → `DynamicFont`
- `FontFile` → `DynamicFontData`
- `Array[Font]([...])` → `[ ... ]`
- `&"TypeName"` → `"TypeName"` (remove `&` prefix)
- `StyleBoxFlat.anti_aliasing` → remove (not in 3.6)
- Remove `opentype_features = {}`
- `LabelSettings` sub-resources → remove entirely

### Font System (GDScript)
Godot 3.6 uses `DynamicFont` / `DynamicFontData`. `FontVariation`, `SystemFont`, `TextServerManager` do not exist in 3.6.

```gdscript
# 4.x — NOT available in 3.6:
font is FontVariation
font is SystemFont
TextServerManager.get_primary_interface()
font.variation_opentype = {}
font.variation_embolden = 0.7
font.variation_transform = Transform2D(...)
font.get_supported_variation_list()

# 3.6: DynamicFont / DynamicFontData only
# Bold/italic synthesis via FontVariation is not portable.
# Drop opentype variation features; use separate DynamicFontData files.
```

#### DynamicFont Fallbacks in `.tres` — `fallback/N`, NOT `fallbacks = [...]`
Godot 3.6 `DynamicFont::_set` has **no `fallbacks` array property** (dynamic_font.cpp). It uses per-index `fallback/0`, `fallback/1`. A 4.x-style `fallbacks = [ExtResource(...)]` in a `.tres` **silently fails** — the list deserializes to nothing and NO fallback fonts attach at runtime. A glyph that only exists in a fallback font then renders as tofu/box or is dropped entirely.

```ini
# 4.x (silently fails in 3.6):
[resource]
fallbacks = [ ExtResource( 2 ), ExtResource( 3 ) ]
# 3.6 (correct):
[resource]
fallback/0 = ExtResource( 2 )
fallback/1 = ExtResource( 3 )
```

`font_data` (primary) is a distinct property and serializes normally. Verify attachment at runtime with `get_fallback_count()` and `get_char_size(cp)` — a fallback-resolved glyph returns a larger size than the primary font's size for the same codepoint.

#### Viewport Texture Readback is Scrambled in 3.6 GLES3
`get_viewport().get_texture().get_data()` (and the `--write-movie` output) is **not ground truth** on 3.6 GLES3: the returned framebuffer can be vertically scrambled/offset (e.g. a 20×20 marker drawn at control position `(662,50)` appears at `(662,530)`; the tab bar band splits between the top 4 rows and the bottom rows). Markers for deep controls show while shallow ones vanish, and row content looks torn. This is a readback artifact, NOT a layout bug — `rect_global_position`/`rect_size` are reliable; the on-screen window is correct.

To verify what the user actually sees on Windows, capture the real window with `PrintWindow` (user32, PW_RENDERFULLCONTENT=2) into a Bitmap from PowerShell instead of reading the viewport texture.

### Scene Files (`.tscn`)
- Remove `uid=` from all header and ext_resource lines
- Remove `layout_mode = N` lines
- Remove `grow_horizontal = N` / `grow_vertical = N`
- Remove `clip_contents = true`
- Remove `caret_blink = true`
- Remove `keep_editing_on_text_submit = true`
- Remove `horizontal_scroll_mode = N` / `vertical_scroll_mode = N`
- Remove `tab_focus_mode = N`
- Remove `LabelSettings` / `label_settings`
- Remove `metadata/_tab_index` / `metadata/_custom_type_script`
- `autowrap_mode = N` → `autowrap = true`
- `horizontal_alignment = N` → `align = N` (different enum values)
- `theme_type_variation = &"Name"` → `theme_type_variation = "Name"`
- `node_paths=PackedStringArray(...)` → `node_paths=PoolStringArray(...)`
- `PackedStringArray(...)` → `PoolStringArray(...)`
- `button_pressed = true` → `pressed = true`
- `button_group = SubResource(...)` → `group = SubResource(...)`
- `Vector2i(...)` → `Vector2(...)`
- `size = Vector2i(...)` (Window) → `rect_size = Vector2(...)`
- `min_size = Vector2i(...)` (Window) → `rect_min_size = Vector2(...)`

### UID Files
Delete all `*.uid` files. 
UID system does not exist in Godot 3.6.
Before deleting, verify and replace any references of the uid to ensure the correct resources are being loaded. 

#### Import Files
Strip `uid=` lines from all `.import` files, or delete them and let Godot 3.6 re-import.

**Fonts: Godot 3.6 has NO font importer.** `ResourceImporterDynamicFont` does not exist in 3.6 (verified against `editor_node.cpp` full importer registration list: texture/layered/image/atlas/csv/wav/obj/scene/bitmap only). Any `.ttf.import` file carried from Godot 4 must be **DELETED**, not converted:
- With `.import` present, `ResourceFormatImporter::recognize_path()` (registered first in core) hijacks `.ttf` loads and remaps to `res://.import/<name>-<md5>.fontdata`, which can NEVER be generated → `Resource file not found`.
- Without `.import`, `ResourceFormatLoaderDynamicFont` loads the `.ttf` directly (sets `font_path`, reads lazily at render). No cache needed.
- `.tres` should reference the `.ttf` path directly: `[ext_resource type="DynamicFontData" path="res://.../x.ttf" id=1]`.
- `--quit-after` is **not a 3.6 flag** (only `-q`/`--quit`). Headless editor runs do not import reliably; do not rely on them.

#### `type="Texture2D"` → `type="Texture"` in ext_resources
Godot 3.6 has no `Texture2D` class (4.x rename); textures are plain `Texture`. A `.tres`/`.tscn` ext_resource header still saying `type="Texture2D"` fails to load: `ERROR: Cannot get class 'Texture2D'. (core/class_db.cpp)` per occurrence, and each referenced icon resolves to **null** (checkbox/radio/arrow icons silently invisible).

```ini
# 4.x (error in 3.6):
[ext_resource type="Texture2D" path="res://.../cbox_check.png" id=1]
# 3.6 (correct):
[ext_resource type="Texture" path="res://.../cbox_check.png" id=1]
```

**Grep:**
```
rg 'type="Texture2D"' -g '*.tres' -g '*.tscn' -g '*.import'
```

---

### GDScript Syntax Rules (3.6)

### Annotations
|4.x                      |3.6|
|---|---|
|@tool                    |tool|
|@export var x            |export var x|
|@onready var x           |onready var x|
|@export_range(a,b,c)     |export(int, a, b, c)  # export_range() does not exist in 3.6|
|@export_range(a,b,c,d)   |export(int, a, b, c)  # drop extra args + use export(int,...)|
|@export_range(a,b,c,d,e) |# NOT AVAILABLE; drop extra args. Float steps may fail — use ints: export(int, 0, 20, 1)|
|@export_group("X")       |# NOT AVAILABLE, remove|
|@export_subgroup("X")    |# NOT AVAILABLE, remove|
|@warning_ignore("x")     |# NOT AVAILABLE, remove|

### Built-in Type Constants
Godot 4 added uppercase static constants to built-in types (`Color.WHITE`, `Color.TRANSPARENT`). Godot 3 uses lowercase equivalents or constructors:

| Godot 4 | Godot 3.6 |
|---|---|
| `Color.WHITE` | `Color(1, 1, 1)` or `Color.white` |
| `Color.BLACK` | `Color(0, 0, 0)` or `Color.black` |
| `Color.RED` | `Color(1, 0, 0)` or `Color.red` |
| `Color.TRANSPARENT` | `Color(0, 0, 0, 0)` (not available as const) |

```gdscript
# 4.x
Color.from_string(str, default)        # static — returns Color
Color.html(str)                        # static — returns Color from hex
# 3.6
Color(str)                             # constructor accepts "#rrggbb"/"#aarrggbb"
# NOTE: Color.html() and Color.named() exist in 3.6 but are INSTANCE methods
# that return String, not static constructors. Use Color(str) for hex,
# lookup dict for named colors.
const _color_names = {
	"red": Color(1, 0, 0), "green": Color(0, 1, 0), "blue": Color(0, 0, 1),
	"yellow": Color(1, 1, 0), "cyan": Color(0, 1, 1), "magenta": Color(1, 0, 1),
	"white": Color(1, 1, 1), "black": Color(0, 0, 0), "orange": Color(1, 0.65, 0),
}
func _color_from_string(str, default):
	if str.begins_with("#"):
		if str.length() == 7 or str.length() == 9:
			return Color(str)
	else:
		var c = _color_names.get(str.to_lower())
		if c != null: return c
	return default
```

### Type Hints
**All type hints must be removed** in 3.6:
```gdscript
# WRONG (4.x):
var x: int
var arr: Array[String]
var dict: Dictionary[String, int]
var socket: WebSocketPeer
func f(x: String) -> bool:
func g() -> void:

# CORRECT (3.6):
var x
var arr
var dict
var socket
func f(x):
func g():
```

### `is` Operator
Works in 3.6. `x is Dictionary`, `x is String`, `x is Array` all valid.

### `in` Operator
`in` works in 3.6 for arrays, dictionaries, and strings. Godot 3.6 has no `not in` compound operator — see below.

### `not in` Operator
`not in` is **not** available in Godot 3.6 (added in 4.0). Use `not (x in y)`:
```gdscript
# 4.x:
if x not in array:
# 3.6:
if not (x in array):
```

### `match` Statement
Works in 3.6 (since 3.1).

### String Methods (available in 3.6)
- `strip_edges()` ✓
- `begins_with()` ✓
- `contains()` — **NOT** in 3.6, use `find(substr) != -1`
- `is_valid_int()` ✓
- `to_lower()` ✓
- `to_upper()` ✓
- `lstrip()` ✓
- `substr()` ✓
- `str[i]` char indexing — **not portable**; some custom engine builds crash natively on it (see `docs/ENGINE_ODDITIES.md`). Always use safe forms unconditionally (no settings gate): `s[q]` → `match s.substr(q, 1)`, `msg[0]` → `msg.begins_with("/")`.
- `split()` ✓
- `count()` ✓
- `trim_prefix()` / `trim_suffix()` — **not** in 3.6, use `trim_left()` / `trim_right()`

### Signal Connections (3.6 style)
- Connect
  ```gdscript
  # 4.x (bare method name — PARSE ERROR in 3.6):
  button.pressed.connect(my_func)

  # 3.6 (string style — always safe):
  button.connect("pressed", self, "my_func")
  # 3.6 (signal object style):
  button.pressed.connect(self, "my_func")
  ```
  **Parse error:** `button.pressed.connect(my_func)` — Godot 3 parser rejects bare method name `my_func` as undeclared identifier. Only variable/Callable/FuncRef expressions are valid as `.connect()` arguments. Bare method names in `.is_connected()`, `.disconnect()`, and `.bind()` also fail.
- `Callable.bind()` — works in 3.6, no changes needed
- `Callable.unbind()` — **NOT** available, use lambda wrapper:
  ```gdscript
  # 4.x:
  sig.connect(my_func.unbind(2))
  # 3.6:
  sig.connect(func(arg1, arg2): my_func())
  ```
- Signal `.emit()` — **NOT** available in 3.6. Use `emit_signal("name", args)` instead:
  ```gdscript
  # 4.x:
  signal updated(creds)
  updated.emit(self)
  signal_name_on_other.emit(arg)
  
  # 3.6:
  signal updated(creds)
  emit_signal("updated", self)
  other.emit_signal("signal_name_on_other", arg)
  ```

### `const` and `enum`
- `const X = val` works in 3.6
- `enum Name { ... }` works in 3.6
- `static func` works in 3.6
- `class_name` works in 3.6

### Array & Dictionary Operations (3.6)
`Array.map`/`filter`/`reduce` are **Godot 4.0 additions** — and the 4.x idiom `arr.filter(self, "method")` does not exist either; such call sites **silently abort** a function mid-body with no error (seen: `/help` rendered empty). On 3.6 use a manual loop instead.

**Shared (same name on both, exist in 3.6):**
- `duplicate(deep=false)`, `empty()`, `has(v)`, `erase(v)`, `clear()`, `size()`, `hash()`

**Array-only (3.6):**
- `append` / `push_back`, `append_array`, `push_front` / `insert`, `remove`, `resize`, `fill(v)`, `slice(begin, end, step, deep)`
- `front` / `back`, `pop_front` / `pop_back`, `pop_at` (returns element), `invert()` (→ 4.x `reverse()` — in-place, returns nothing), `shuffle()`
- `count(v)`, `find(v, from)` / `find_last(v)` / `rfind(v, from)`
- `sort()`, `sort_custom(Object obj, String func)` — comparator takes TWO elements
- `bsearch(v, before)` / `bsearch_custom(v, obj, func, before)` — binary search on sorted arrays
- `max()` / `min()` / `pick_random()`

**Dictionary-only (3.6):**
- `keys()`, `values()`, `get(key, default)`, `merge(other)`

**Deleted in 4.x → replacement (both types):**
| 4.x | 3.6 |
|---|---|
| `arr.assign(values)` | `arr.clear(); for v in values: arr.append(v)` |
| `arr.make_read_only()` | wrap in class with getter returning `arr.duplicate()` or make `const` if static |
| `arr.reverse()` / `arr.reversed()` | `arr.invert()` / `Util.reversed(arr)` (existing helper) |
| `arr.is_empty()` / `dict.is_empty()` | `empty()` — rename, not a removal |
| `dict.find_key(v)` | manual iteration: `for k in dict: if dict[k] == v: return k` |
| `dict.map` / `dict.filter` (4.x only) | manual loop |
| `str.validate_filename()` | manual sanitization needed (String-only stray, kept here for legacy) |

**Notes:**
- `arr.pop_at(i)` **exists** in 3.6 (NOT removed) — use it directly, not `arr.remove(i)`.
- `arr.map`/`filter`/`reduce` → manual loop.

### Loops (3.6)
```gdscript
for x in array:  # ✓
for key in dict:  # ✓
for i in range(n):  # ✓
while condition:  # ✓
```

- Bare-int iteration (`for i in n:`) — **not portable**: some custom engine builds fault natively (`0xC0000005`) when the count is `0` (zero-iteration int-loop; see `docs/ENGINE_ODDITIES.md`). Always write `for i in range(n):` — semantically identical on stock, Array-backed and safe everywhere. Applies to every int-valued RHS: literals, `.size()`, `.length()`, `get_width()`, `get_tab_count()`, etc.

### `yield` vs `await`
Godot 3 uses `yield`, Godot 4 uses `await`.
```gdscript
# 4.x:
await get_tree().process_frame
await some_signal

# 3.6:
yield(get_tree(), "idle_frame")
yield(some_signal)
```

Every `await` must become `yield` for 3.6:

```gdscript
# 4.x:
await tree.process_frame
await status_updated
await tree.node_added
await get_tree().create_timer(3).timeout

# 3.6:
yield(tree, "idle_frame")
yield(self, "status_updated")
yield(tree, "node_added")
yield(get_tree().create_timer(3), "timeout")
```

### `push_warning` / `push_error`
Available in 3.6 ✓

### `print` / `str`
Available in 3.6 ✓

### `assert`
Available in 3.6 ✓

### `@warning_ignore` annotations
Remove entirely. Not supported in 3.6.

### `funcref` — Method References

Godot 3 can't reference a method name as a value (no `Callable` type in GDScript). Pass `funcref(self, "method_name")` instead.

```gdscript
# 4.x (works):
.set_handler(_handle_command)

# 3.6 (parse error — bare method name):
.set_handler(_handle_command)

# 3.6 (correct):
.set_handler(funcref(self, "_handle_command"))
```

#### FuncRef.call() → FuncRef.call_func()
Godot 3 `FuncRef` does **not** override `Object.call()`. Using `.call()` on a FuncRef falls through to `Object.call(method_name, args...)`, which interprets the first arg as a method name String. Passing any non-String (Array, int, etc.) causes: *"Invalid type in function '[] (via call)' in base 'FuncRef'"*.

| 4.x / broken | 3.6 (correct) |
|---|---|
| `proc.call(arg)` | `proc.call_func(arg)` |
| `proc.call()` | `proc.call_func()` |
| `proc.call(a, b)` | `proc.call_func(a, b)` |

`call_funcv(args_array)` also available for dynamic arg lists.

**Do NOT change** `Object.call(method_name, args...)` on regular nodes/objects — that API is correct:
```gdscript
# CORRECT — Object.call() on regular target:
cmd.call_target.call(cmd.call_method, self, cmd, msg)
ht.cond_target.call(ht.cond_method)

# WRONG — falls through to Object.call() on FuncRef:
proc.call(vals[key])     # vals[key] is Array, not method name!

# CORRECT — use call_func on FuncRef:
proc.call_func(vals[key])
```

**Grep checklist:**
```
rg '\.call\(' --include '*.gd'  # review every .call() — is base a FuncRef?
```

### Chained Method Calls Across Lines

Chained builder patterns inside function arguments can cause `Expected ',' or ')'` parse errors in Godot 3, especially with inconsistent indentation. Prefer temp variable + separate statements:

```gdscript
# 4.x (works):
register_command(ConsoleCommand.new("/name")
    .add_help("", "text")
    .set_call(self, "_method"))

# 3.6 (may error):
register_command(ConsoleCommand.new("/name")
    .add_help("", "text")
    .set_call(self, "_method"))

# 3.6 (safe):
var cmd = ConsoleCommand.new("/name")
cmd.add_help("", "text")
cmd.set_call(self, "_method")
register_command(cmd)
```

### `String.num_int64(number, base, capitalize_hex)`
Available in 3.6. The third parameter in 3.6 is `capitalize_hex` (bool), in 4.x it is `prefix_sign` (bool). Passing `true` as third arg: 4.x adds `+`/`-` prefix, 3.x capitalizes hex letters. **Breaking difference** — review every call site.
```gdscript
# 4.x:
String.num_int64(255, 16, true)  # returns "+ff"
# 3.6:
String.num_int64(255, 16, true)  # returns "FF"
# To get same result in 3.6, don't pass true:
String.num_int64(255, 16)        # returns "ff"
```

### `move_toward(val, target, delta)`
Available in 3.6 (since 3.5) ✓

### `Transform2D(Vector2, Vector2, Vector2)`
Available in 3.6 ✓
## References

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
    - C++ citations in this doc reference tag `3.6-stable` (commit `de2f0f147`)

