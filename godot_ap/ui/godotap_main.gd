class_name GodotAPMain extends ColorRect
## Directly opens the CommonClient Console in the current SceneTree
## Used for standalone client applications

const _ap_state = {"ref": null}
static func _get_ap():
	if _ap_state.ref == null:
		_ap_state.ref = Util._get_ap()
	return _ap_state.ref

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
	_get_ap().load_packed_console_as_scene(get_tree(), Util._ap_load("ui/common_client.tscn"))

func _on_creds_updated(creds):
	save_connection(creds)

static func load_connection():
	var conn_info_file = Util._file_open("user://ap/connection.dat", File.READ)
	if not conn_info_file: return
	var ip = conn_info_file.get_line()
	var port = conn_info_file.get_line()
	var slot = conn_info_file.get_line()
	_get_ap().creds.update(ip, port, slot, "")
	conn_info_file.close()
static func save_connection(creds):
	Util._make_dir_recursive("user://ap/")
	var conn_info_file = Util._file_open("user://ap/connection.dat", File.WRITE)
	if not conn_info_file: return
	conn_info_file.store_line(creds.ip)
	conn_info_file.store_line(creds.port)
	conn_info_file.store_line(creds.slot)
	conn_info_file.close()
