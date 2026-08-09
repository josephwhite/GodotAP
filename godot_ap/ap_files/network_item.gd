class_name NetworkItem

var id
var loc_id
var src_player_id
var dest_player_id
var flags

const _AP_state = {"ref": null}
const _BC_state = {"ref": null}
static func _get_ap():
	if _AP_state.ref == null:
		_AP_state.ref = Util._get_ap()
	return _AP_state.ref
static func _get_bc():
	if _BC_state.ref == null:
		_BC_state.ref = Util._ap_load("ui/console/base_console.gd")
	return _BC_state.ref

func get_classification():
	return _get_ap().get_item_classification(flags)
static func from(json, recv):
	if json["class"] != "NetworkItem":
		return null
	var v = Util._ap_load("ap_files/network_item.gd").new()
	v.id = json["item"]
	v.loc_id = json["location"]
	v.src_player_id = json["player"] if recv else _get_ap().conn.player_id
	v.dest_player_id = _get_ap().conn.player_id if recv else json["player"]
	v.flags = int(json["flags"])
	return v
static func from_hint(json):
	if json["class"] != "Hint":
		return null
	var v = Util._ap_load("ap_files/network_item.gd").new()
	v.id = json["item"]
	v.loc_id = json["location"]
	v.src_player_id = json["finding_player"]
	v.dest_player_id = json["receiving_player"]
	v.flags = int(json["item_flags"])
	return v

func is_local():
	return src_player_id == dest_player_id
func is_prog():
	return flags & _get_ap().ItemClassification.PROG

func get_name():
	return _get_ap().conn.get_gamedata_for_player(dest_player_id).get_item_name(id)
func _to_string():
	return "ITEM(%d at %d,player %d->%d,flags %d)" % [id,loc_id,src_player_id,dest_player_id,flags]
func output():
	return _get_bc().make_item(id, flags, _get_ap().conn.get_gamedata_for_player(dest_player_id))
