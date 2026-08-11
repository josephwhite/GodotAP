class_name GodotAPMain extends ColorRect
## Directly opens the CommonClient Console in the current SceneTree
## Used for standalone client applications

static func _get_ap():
	return Util._get_ap()

func _ready():
	if OS.is_debug_build():
		_get_ap().cmd_manager.debug_hidden = false

	_get_ap().AP_CLIENT_VERSION = Version.val(0,1,0) # GodotAP CommonClient version
	_get_ap()._log(_get_ap().AP_CLIENT_VERSION)
	_get_ap().set_tags(["TextOnly"])
	_get_ap().AP_ITEM_HANDLING = _get_ap().ItemHandling.ALL
	_get_ap().creds.connect("updated", self, "_on_creds_updated")
	load_connection()

	if _get_ap().output_console:
		_get_ap().close_console()
	OS.min_window_size = Vector2(750, 400)
	OS.set_window_title("AP Text Client")
	if _get_ap().load_packed_console_as_scene(get_tree(), Util._ap_load("ui/common_client.tscn")):
		hide()

func _on_creds_updated(creds):
	save_connection(creds)

static func load_connection():
	var conn_info_file = Util._file_open("user://ap/connection.dat", File.READ)
	if not conn_info_file: return
	_get_ap().creds.read(conn_info_file)
	conn_info_file.close()
static func save_connection(creds):
	Util._make_dir_recursive("user://ap/")
	var conn_info_file = Util._file_open("user://ap/connection.dat", File.WRITE)
	if not conn_info_file: return
	creds.write(conn_info_file)
	conn_info_file.close()
