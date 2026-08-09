class_name Util

const MOUSE_OFFSET = Vector2(0,-2)
const GAMMA = 0.0001

# Compatibility wrappers for Godot 4 → 3.6
static func _file_open(path, mode):
	var f = File.new()
	var err = f.open(path, mode)
	if err != OK:
		return null
	return f

static func _make_dir_recursive(path):
	var d = Directory.new()
	return d.make_dir_recursive(path)

## Returns the Archipelago autoload node, if present.
static func _get_ap():
	return Engine.get_main_loop().get_root().get_node("Archipelago")

## Returns the base directory of the GodotAP install, from the AP node if
## available, else falling back to `res://godot_ap`.
static func _ap_base_dir():
	var ap = _get_ap()
	if ap and ap.has_method("get_ap_base_dir"):
		return ap.get_ap_base_dir()
	return "res://godot_ap"

## Loads a resource by path relative to the GodotAP install base directory.
## Use this instead of `load("res://godot_ap/...")` so the module can be
## loaded from anywhere (e.g. inside a mod's unpacked folder).
static func _ap_load(path):
	return load(_ap_base_dir().plus_file(path))

const _color_names = {
	"red": Color(1, 0, 0),
	"green": Color(0, 1, 0),
	"blue": Color(0, 0, 1),
	"yellow": Color(1, 1, 0),
	"cyan": Color(0, 1, 1),
	"magenta": Color(1, 0, 1),
	"white": Color(1, 1, 1),
	"black": Color(0, 0, 0),
	"gray": Color(0.5, 0.5, 0.5),
	"orange": Color(1, 0.65, 0),
	"purple": Color(0.5, 0, 0.5),
}
static func _color_from_string(col, default):
	if col.begins_with("#"):
		if col.length() == 7 or col.length() == 9:
			return Color(col)
	else:
		var c = _color_names.get(col.to_lower())
		if c != null: return c
	return default

static func get_mag(v):
	return sqrt(abs(v.x) * abs(v.x) + abs(v.y) * abs(v.y))

static func current_scene(tree):
	if Engine.is_editor_hint():
		return Engine.get_editor_interface().get_edited_scene_root()
	else:
		return tree.current_scene

static func for_all_nodes(node, target, method, extra_args = []):
	if target.callv(method, [node] + extra_args):
		return node
	if node != null:
		for child in node.get_children():
			var ret = for_all_nodes(child, target, method, extra_args)
			if ret: return ret
	return null

const _log_state = {"file": null}
static func open_logger():
	_log_state.file = _file_open("user://logs/log.log", File.WRITE)
static func close_logger():
	if _log_state.file:
		_log_state.file.close()
		_log_state.file = null
static func log(s):
	if _log_state.file:
		_log_state.file.store_line(str(s))
		if OS.is_debug_build(): _log_state.file.flush()
	print("%s" % str(s))
static func dblog(s):
	if not OS.is_debug_build(): return
	log(s)

static func freeze_popup(tree, title, text, cancel = true):
	return freeze_sub_popup(tree.root, title, text, cancel)
static func freeze_sub_popup(node, title, text, cancel = true):
	var popup = AcceptDialog.new()
	node.add_child(popup)
	var tree = node.get_tree()
	popup.title = title
	popup.dialog_text = text
	popup.transient = true
	popup.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.paused = true
	popup.connect("confirmed", popup, "queue_free")
	popup.connect("canceled", popup, "queue_free")
	popup.connect("tree_exited", tree, "set_paused", [false])
	if cancel:
		popup.add_cancel_button("Cancel")
	popup.rect_min_size = Vector2(200, 0)
	return popup

static func standard_popup(tree, title, text, cancel = true):
	return standard_sub_popup(tree.root, title, text, cancel)
static func standard_sub_popup(node, title, text, cancel = true):
	var popup = AcceptDialog.new()
	node.add_child(popup)
	popup.title = title
	popup.dialog_text = text
	popup.transient = true
	popup.process_mode = Node.PROCESS_MODE_ALWAYS
	popup.connect("confirmed", popup, "queue_free")
	popup.connect("canceled", popup, "queue_free")
	if cancel:
		popup.add_cancel_button("Cancel")
	popup.rect_min_size = Vector2(200, 0)
	return popup

static func on_closed(popup):
	if popup is AcceptDialog:
		popup.connect("confirmed", popup, "emit_signal", ["close_requested"])
		popup.connect("canceled", popup, "emit_signal", ["close_requested"])
	yield(popup, "close_requested")

static func load_new_scene(tree, path):
	load_scene(tree, load(path))
static func load_scene(tree, scene):
	tree.change_scene_to(scene)

static func is_zero_vec(vec):
	return abs(vec.x) < GAMMA and abs(vec.y) < GAMMA


static func unsigned_to_signed(unsigned, bits):
	return (unsigned + (1 << (bits-1))) % (1 << bits) - (1 << (bits-1))
static func unsigned_to_signed_8(unsigned):
	return unsigned_to_signed(unsigned, 8)
static func unsigned_to_signed_16(unsigned):
	return unsigned_to_signed(unsigned, 16)
static func unsigned_to_signed_32(unsigned):
	return unsigned_to_signed(unsigned, 32)

static func bit_count(val):
	var ret = 0
	for v in 64:
		if val & (1<<v): ret += 1
	return ret

static func approx_eq(v1, v2):
	return abs(v1-v2) < GAMMA
static func approx_eq_vec(v1, v2):
	var diff = abs(v1-v2)
	return diff.x < GAMMA and diff.y < GAMMA

static func move_toward_directional(v1, v2):
	var ret = Vector2.ZERO
	if sign(v1.x) == sign(v2.x) and abs(v1.x) > abs(v2.x):
		ret.x = v1.x
	else: ret.x = move_toward(v1.x, v2.x, abs(v2.x)*.75)
	if sign(v1.y) == sign(v2.y) and abs(v1.y) > abs(v2.y):
		ret.y = v1.y
	else: ret.y = move_toward(v1.y, v2.y, abs(v2.y)*.75)
	return ret

static func split_args(msg):
	var raw_args = msg.split(" ")
	var args = []
	var open_quote = false
	for s in raw_args:
		if open_quote:
			args[-1] += " " + s
		else: args.append(s)
		if s.count("\"") % 2:
			open_quote = not open_quote
	return args

static func reversed(arr):
	var dup = arr.duplicate()
	dup.reverse()
	return dup

static func find_break_paren(s):
	var paren = 0
	var bracket = 0
	var brace = 0
	for q in s.length():
		match s[q]:
			"(": paren += 1
			"[": bracket += 1
			"{": brace += 1
			")":
				paren -= 1
				if paren < 0: return q
			"]":
				bracket -= 1
				if bracket < 0: return q
			"}":
				brace -= 1
				if brace < 0: return q
	return s.length()

static func poll_timer(timer, dur):
	if timer.is_stopped():
		if dur > GAMMA:
			timer.start(dur)
		return true
	return false

static func modulate(img, col):
	var ret = Image.new()
	ret.copy_from(img)
	for x in ret.get_width():
		for y in ret.get_height():
			var px = ret.get_pixel(x, y)
			if int(px.a * 255) == 255:
				ret.set_pixel(x, y, px * col)
	return ret

static func grayscale(img):
	var ret = Image.new()
	ret.copy_from(img)
	for x in ret.get_width():
		for y in ret.get_height():
			var px = ret.get_pixel(x, y)
			if int(px.a * 255) == 255:
				ret.set_pixel(x, y, gray(px))
	return ret

static func gray(c):
	var g = (c.r * 0.299) + (c.g * 0.587) + (c.b * 0.114)
	return Color(g, g, g)

static func get_pascal_string_or(file, default):
	if not file or file.eof_reached(): return default
	if file.get_position() >= file.get_length(): return default
	return file.get_pascal_string()
static func get_8_or(file, default):
	if not file or file.eof_reached(): return default
	if file.get_position() >= file.get_length(): return default
	return file.get_8()
static func get_16_or(file, default):
	if not file or file.eof_reached(): return default
	if file.get_position() >= file.get_length(): return default
	return file.get_16()
static func get_32_or(file, default):
	if not file or file.eof_reached(): return default
	if file.get_position() >= file.get_length(): return default
	return file.get_32()

static func nil():
	pass

# Font stuff
static func font_mod(font, bold, italic):
	if font and (bold or italic):
		var _font = font.duplicate()
		if _font is DynamicFont:
			if bold and _font.has_method("set_bold"):
				_font.bold = true
			if italic and _font.has_method("set_italic"):
				_font.italic = true
		return _font
	return font
