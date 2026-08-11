class_name ThemeManager extends MarginContainer

static func _get_ap():
	return Util._get_ap()

signal update_theme(new_theme)

export var themes = []
export(NodePath) var default_theme

func _ready():
	var def = default_theme
	if def is NodePath:
		def = get_node(def)
	for themebox in themes:
		var tb = get_node(themebox) if themebox is NodePath else themebox
		tb.connect("set_theme", self, "set_console_theme")
		tb.set_pressed_no_signal(tb.target_theme_path == _get_ap().config.window_theme_path)
	var stored = _get_ap().config.window_theme_path
	if stored.empty():
		def.set_pressed(true)
	elif not _theme_resolvable(stored):
		push_warning("Stale theme path in config, resetting to default: " + stored)
		_get_ap().config.window_theme_path = ""
		def.set_pressed(true)
	else:
		refresh_console_theme()

func set_console_theme(path):
	if path.empty(): return
	var theme_res = _load_theme(path)
	if not theme_res is Theme: return
	var target = self
	while target.get_parent() is Control:
		target = target.get_parent()
	target.theme = theme_res
	_get_ap().config.window_theme_path = path
	emit_signal("update_theme", theme_res)

func refresh_console_theme():
	set_console_theme(_get_ap().config.window_theme_path)

## Resolves a theme path that may be module-relative (e.g. "themes/dark_theme.tres")
## against the GodotAP install base dir, handling a stale absolute res://godot_ap/...
## value persisted by an older session.
func _load_theme(path):
	if path.begins_with("res://godot_ap/"):
		return Util._ap_load(path.substr(14))
	if path.begins_with("res://"):
		return load(path)
	return Util._ap_load(path)

## Mirrors _load_theme() resolution to produce the absolute res:// path for a
## candidate theme path, for existence checks that must not emit load errors.
func _resolve_theme_path(path):
	if path.begins_with("res://godot_ap/"):
		return Util._ap_base_dir().plus_file(path.substr(14))
	if path.begins_with("res://"):
		return path
	return Util._ap_base_dir().plus_file(path)

## True if the given path (module-relative, absolute res://, or a stale legacy
## res://godot_ap/... value) points at a loadable theme resource.
func _theme_resolvable(path):
	return ResourceLoader.exists(_resolve_theme_path(path))
