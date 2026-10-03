extends "res://addons/gut/test.gd"
## Tests for the APConfigManager class.

const CFG_PATH = "user://ap/_cfg_test.dat"

var _cfg_changed = []


func before_each():
	Util._make_dir_recursive("user://ap/")
	_cfg_changed = []


func _on_cfg_changed():
	_cfg_changed.append(true)


func _make_mgr():
	return autofree(APConfigManager.new())


func test_set_window_theme_path_emits():
	var mgr = _make_mgr()
	mgr._pause_saving = true
	mgr.connect("config_changed", self, "_on_cfg_changed")
	mgr.window_theme_path = "res://foo.tres"
	assert_eq(_cfg_changed.size(), 1)
	assert_eq(mgr.window_theme_path, "res://foo.tres")
	mgr.window_theme_path = "res://foo.tres"
	assert_eq(_cfg_changed.size(), 1)


func test_set_uuid_emits():
	var mgr = _make_mgr()
	mgr._pause_saving = true
	mgr.connect("config_changed", self, "_on_cfg_changed")
	mgr.uuid = "abc"
	assert_eq(_cfg_changed.size(), 1)
	assert_eq(mgr.uuid, "abc")
	mgr.uuid = "abc"
	assert_eq(_cfg_changed.size(), 1)


func test_generate_uuid_format():
	for n in range(20):
		var id = APConfigManager.generate_uuid()
		assert_eq(id.length(), 36)
		assert_eq(id[8], "-")
		assert_eq(id[13], "-")
		assert_eq(id[18], "-")
		assert_eq(id[23], "-")
		assert_eq(id[14], "4")
		assert_true(id[19] in "89ab")
		for q in range(36):
			if q in [8, 13, 18, 23]:
				continue
			assert_true(id[q] in "0123456789abcdef")


func test_randi_range_bounds():
	for n in range(200):
		var v = APConfigManager._randi_range(3, 7)
		assert_true(v >= 3)
		assert_true(v <= 7)


func test_save_load_roundtrip():
	var mgr = _make_mgr()
	mgr._pause_saving = true
	mgr.window_theme_path = "res://theme.tres"
	mgr.uuid = "cfg-uuid"
	var f = File.new()
	f.open(CFG_PATH, File.WRITE)
	mgr._save_cfg(f)
	f.close()
	var read = _make_mgr()
	f = File.new()
	f.open(CFG_PATH, File.READ)
	assert_true(read._load_cfg(f))
	f.close()
	assert_eq(read.window_theme_path, "res://theme.tres")
	assert_eq(read.uuid, "cfg-uuid")


func test_load_wrong_header_false():
	var f = File.new()
	f.open(CFG_PATH, File.WRITE)
	f.store_pascal_string("Not the header")
	f.close()
	var read = _make_mgr()
	f = File.new()
	f.open(CFG_PATH, File.READ)
	assert_false(read._load_cfg(f))
	f.close()


func test_load_v1_migration():
	var f = File.new()
	f.open(CFG_PATH, File.WRITE)
	f.store_pascal_string(APConfigManager.CONFIG_HEADER)
	f.store_32(1)
	f.store_8(0)  # old trackerpack var
	f.store_pascal_string("res://v1.tres")
	f.store_pascal_string("v1-uuid")
	f.close()
	var read = _make_mgr()
	f = File.new()
	f.open(CFG_PATH, File.READ)
	assert_true(read._load_cfg(f))
	f.close()
	assert_eq(read.window_theme_path, "res://v1.tres")
	assert_eq(read.uuid, "v1-uuid")
