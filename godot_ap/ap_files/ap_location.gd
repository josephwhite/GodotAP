class_name APLocation

var id
var name
var hint_status

static func make(locid):
	var ret = Util._ap_load("ap_files/ap_location.gd").new()
	ret.id = locid
	ret.name = Util._get_ap().conn.get_gamedata_for_player().get_loc_name(locid)
	return ret
static func nil():
	var ret = Util._ap_load("ap_files/ap_location.gd").new()
	ret.id = -9999
	ret.name = "INVALID"
	ret.hint_status = NetworkHint.Status.UNSPECIFIED
	return ret

func _to_string():
	return "LOCATION(%d '%s',Hint '%s')" % [id, name, _get_nh().status_names[hint_status]]

const _NH_state = {"ref": null}
static func _get_nh():
	if _NH_state.ref == null:
		_NH_state.ref = Util._ap_load("ap_files/network_hint.gd")
	return _NH_state.ref
