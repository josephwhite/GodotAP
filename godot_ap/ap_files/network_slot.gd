class_name NetworkSlot

var name
var game
var type
var group_members = []

static func from(json):
	if json["class"] != "NetworkSlot":
		return null
	var v = Util._ap_load("ap_files/network_slot.gd").new()
	v.name = json["name"]
	v.game = json["game"]
	v.type = json["type"]
	v.group_members = json["group_members"].duplicate()
	return v

func _to_string():
	return "SLOT(%s[%s],type %d,members %s)" % [name,game,type,group_members]
