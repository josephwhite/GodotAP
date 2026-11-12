extends "res://addons/gut/test.gd"
## Tests for the NetworkPlayer class.

var _ap


func before_each():
	_ap = Engine.get_main_loop().get_root().get_node("Archipelago")


func after_each():
	_ap.conn = null


func _make_json(overrides = {}):
	var json = {
		"class": "NetworkPlayer",
		"team": 0,
		"slot": 1,
		"name": "Alice",
	}
	json.merge(overrides, true)
	return json


func test_from_copies_fields_without_alias():
	var plyr = NetworkPlayer.from(_make_json())
	assert_eq(plyr.team, 0)
	assert_eq(plyr.slot, 1)
	assert_eq(plyr.name, "Alice")
	assert_eq(plyr.alias, "")


func test_from_keeps_distinct_alias():
	var plyr = NetworkPlayer.from(_make_json({"alias": "Al"}))
	assert_eq(plyr.alias, "Al")
	assert_eq(plyr.get_name(), "Al")


## The server may repeat the name as the alias; it should not be displayed twice.
func test_from_clears_alias_equal_to_name():
	var plyr = NetworkPlayer.from(_make_json({"alias": "Alice"}))
	assert_eq(plyr.alias, "")
	assert_eq(plyr.get_name(), "Alice")


func test_from_wrong_class_returns_null():
	assert_null(NetworkPlayer.from(_make_json({"class": "NetworkSlot"})))


func test_get_name_falls_back_to_name():
	var plyr = NetworkPlayer.new()
	plyr.name = "Alice"
	plyr.alias = ""
	assert_eq(plyr.get_name(), "Alice")
	assert_eq(plyr.get_name(false), "Alice")


func test_get_slot_uses_connection():
	var slot = NetworkSlot.new()
	slot.name = "Alice"
	_ap.conn = ConnectionInfo.new()
	_ap.conn.slots = [slot]
	var plyr = NetworkPlayer.new()
	plyr.slot = 1
	assert_eq(plyr.get_slot(), slot)


func test_to_string_contains_fields():
	var plyr = NetworkPlayer.from(_make_json({"alias": "Al"}))
	var text = str(plyr)
	assert_string_contains(text, "Alice")
	assert_string_contains(text, "Al")
	assert_string_contains(text, "team 0")
	assert_string_contains(text, "slot 1")
