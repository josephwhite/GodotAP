class_name NetworkPlayer
## A player in the multiworld.
##
## @tutorial(Archipelago Documentation): https://github.com/ArchipelagoMW/Archipelago/blob/main/docs/network%20protocol.md#networkplayer

## The ID of the team that the player is on.
var team: int
## The player's slot number.
var slot: int
## The player's alias.
var alias: String = ""
## The player's name.
var name: String


## Get the slot information for this player.
func get_slot():
	return Util._get_ap().conn.get_slot(slot)


## Get the name or alias for this player.
func get_name(use_alias = true):
	var ret = ""
	if use_alias:
		ret = alias
	if not ret:
		ret = name
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
	return "PLAYER(%s[%s],team %d,slot %d)" % [name, alias, team, slot]


## Create a label to display on a console.
func output():
	return BaseConsole.make_player(slot)
