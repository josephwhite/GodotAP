class_name NetworkPlayer

var team
var slot
var alias = ""
var name

func get_slot():
	return Util._get_ap().conn.get_slot(slot)
func get_name(use_alias = true):
	var ret = ""
	if use_alias: ret = alias
	if not ret: ret = name
	return ret

static func from(json):
	if json["class"] != "NetworkPlayer":
		return null
	var v = Util._ap_load("ap_files/network_player.gd").new()
	v.team = json["team"]
	v.slot = json["slot"]
	v.name = json["name"]
	if json.has("alias"):
		v.alias = json["alias"]
		if v.alias == v.name:
			v.alias = ""
	return v

func _to_string():
	return "PLAYER(%s[%s],team %d,slot %d)" % [name,alias,team,slot]
func output():
	return BaseConsole.make_player(slot)
