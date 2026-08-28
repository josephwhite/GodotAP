class_name APConfigManager extends Node

signal config_changed
const CFG_VERSION = 2
const CONFIG_HEADER = "GodotAP Settings File"

var _pause_saving = false
var window_theme_path = "" setget set_window_theme_path
func set_window_theme_path(val):
	if val != window_theme_path:
		window_theme_path = val
		save_cfg()
		emit_signal("config_changed")
var uuid = "" setget set_uuid
func set_uuid(val):
	if val != uuid:
		uuid = val
		save_cfg()
		emit_signal("config_changed")

static func _randi_range(min_val, max_val):
	return min_val + randi() % (max_val - min_val + 1)

const _HEX_CHARS = "0123456789abcdef"
static func _rand_hex():
	return _HEX_CHARS.substr(_randi_range(0, 15), 1)

static func generate_uuid():
	var ret = ""
	for q in range(8):
		ret += _rand_hex()
	ret += "-"
	for q in range(4):
		ret += _rand_hex()
	ret += "-"
	ret += "4"
	for q in range(3):
		ret += _rand_hex()
	ret += "-"
	ret += _HEX_CHARS.substr(_randi_range(8, 11), 1)
	for q in range(3):
		ret += _rand_hex()
	ret += "-"
	for q in range(12):
		ret += _rand_hex()
	return ret

func _ready():
	load_cfg()
	if not uuid:
		uuid = generate_uuid()

func load_cfg():
	Util._make_dir_recursive("user://ap/")
	var file = Util._file_open("user://ap/settings.dat", File.READ)
	if not file:
		return false
	_pause_saving = true
	var ret = _load_cfg(file)
	file.close()
	_pause_saving = false
	return ret
func save_cfg():
	if _pause_saving: return
	Util._make_dir_recursive("user://ap/")
	var file = Util._file_open("user://ap/settings.dat", File.WRITE)
	_save_cfg(file)
	file.close()

func _load_cfg(file):
	if file.get_pascal_string() != CONFIG_HEADER:
		return false
	var vers = file.get_32()
	if vers < 2:
		file.get_8() # old trackerpack vars
	window_theme_path = file.get_pascal_string()
	if vers >= 1:
		uuid = file.get_pascal_string()
	return true
func _save_cfg(file):
	file.store_pascal_string(CONFIG_HEADER)
	file.store_32(CFG_VERSION)
	file.store_pascal_string(window_theme_path)
	# CFG_VERSION >= 1
	file.store_pascal_string(uuid)
