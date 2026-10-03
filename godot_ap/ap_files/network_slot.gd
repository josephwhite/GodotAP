class_name NetworkSlot
## Information about a slot in the multiworld.
##
## @tutorial(Archipelago Documentation): https://github.com/ArchipelagoMW/Archipelago/blob/main/docs/network%20protocol.md#networkslot

## The name of the slot.
var name: String
## The game played on the slot.
var game: String
## Type of slot (spectator = 0x00, player = 0x01, group = 0x02)
var type: int
## If the slot is for a group, the IDs of the players in the group.
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
	return "SLOT(%s[%s],type %d,members %s)" % [name, game, type, group_members]
