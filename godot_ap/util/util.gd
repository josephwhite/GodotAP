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

## Get engine build quirk.
static func _casus(key):
	var ap = _get_ap()
	if ap:
		return ap.casus.get(key, false)
	return false

## Tests whether a flag bit is set.
static func has_flag(flags, bit):
	# Pow()-based math when the engine build crashes on bitwise operators.
	if _casus("DISABLE_BITWISE_OPERATIONS"):
		return int(flags / pow(2, bit)) % 2 == 1
	# Uses bitwise ops on stock engines.
	return (flags & (1 << bit)) != 0

static func unsigned_to_signed(unsigned, bits):
	if _casus("DISABLE_BITWISE_OPERATIONS"):
		var max_val = int(pow(2, bits))
		var half = int(pow(2, bits - 1))
		return int((unsigned + half) % max_val) - half
	return (unsigned + (1 << (bits-1))) % (1 << bits) - (1 << (bits-1))
static func unsigned_to_signed_8(unsigned):
	return unsigned_to_signed(unsigned, 8)
static func unsigned_to_signed_16(unsigned):
	return unsigned_to_signed(unsigned, 16)
static func unsigned_to_signed_32(unsigned):
	return unsigned_to_signed(unsigned, 32)

static func bit_count(val):
	var ret = 0
	if _casus("DISABLE_BITWISE_OPERATIONS"):
		for v in range(64):
			if int(val / pow(2, v)) % 2 == 1: ret += 1
	else:
		for v in range(64):
			if val & (1<<v): ret += 1
	return ret

## Probes raw TCP reachability of host:port without involving WebSocketClient.
## Can use before connecting since a refused/unreachable server is reported
## gracefully instead of routing through the engine's socket error path.
## Note: Godot 3's StreamPeerTCP accepts only a pre-resolved IP_Address (funny DNS lookup),
## so hostnames go through the IP resolver queue first.
## The async connect handshake is driven by re-invoking
## put_data(), which runs the internal connection poll.
## UNUSED: reach test disabled. Raw-TCP probes produce HTTP 400 Bad Request entries in server logs. Kept only for manual diagnostics.
## TODO: Either delete or move to some kind of "test tooling" file.
static func _tcp_probe(host, port, timeout_ms = 2500):
	var deadline = OS.get_ticks_msec() + timeout_ms
	var addr_str = host
	if not host.is_valid_ip_address():
		var qid = IP.resolve_hostname_queue_item(host, IP.TYPE_ANY)
		var done = false
		while OS.get_ticks_msec() < deadline:
			match IP.get_resolve_item_status(qid):
				IP.RESOLVER_STATUS_DONE:
					addr_str = IP.get_resolve_item_address(qid)
					done = true
					break
				IP.RESOLVER_STATUS_ERROR:
					done = false
					break
			OS.delay_msec(10)
		IP.erase_resolve_item(qid)
		if not done or not addr_str:
			return false
		deadline = OS.get_ticks_msec() + timeout_ms
	var tcp = StreamPeerTCP.new()
	tcp.connect_to_host(addr_str, port)
	var st = tcp.get_status()
	if st != StreamPeerTCP.STATUS_CONNECTING and st != StreamPeerTCP.STATUS_CONNECTED:
		tcp.disconnect_from_host()
		return false
	var ret = false
	while OS.get_ticks_msec() < deadline:
		tcp.put_data(PoolByteArray())
		st = tcp.get_status()
		if st == StreamPeerTCP.STATUS_CONNECTED:
			ret = true
			break
		if st == StreamPeerTCP.STATUS_ERROR:
			break
		OS.delay_msec(10)
	tcp.disconnect_from_host()
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
	for q in range(s.length()):
		match s.substr(q, 1):
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
	for x in range(ret.get_width()):
		for y in range(ret.get_height()):
			var px = ret.get_pixel(x, y)
			if int(px.a * 255) == 255:
				ret.set_pixel(x, y, px * col)
	return ret

static func grayscale(img):
	var ret = Image.new()
	ret.copy_from(img)
	for x in range(ret.get_width()):
		for y in range(ret.get_height()):
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
