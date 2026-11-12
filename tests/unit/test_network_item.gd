extends "res://addons/gut/test.gd"
## Tests for the NetworkItem class.

var _ap


func before_each():
	_ap = Engine.get_main_loop().get_root().get_node("Archipelago")
	_ap.conn = ConnectionInfo.new()
	_ap.conn.player_id = 3


func after_each():
	var caches = _ap._data_caches
	caches.erase("Test")
	_ap.conn = null


func _make_json(overrides = {}):
	var json = {
		"class": "NetworkItem",
		"item": 1,
		"location": 2,
		"player": 4,
		"flags": 1,
	}
	json.merge(overrides, true)
	return json


func _make_hint_json(overrides = {}):
	var json = {
		"class": "Hint",
		"item": 10,
		"location": 20,
		"finding_player": 1,
		"receiving_player": 2,
		"item_flags": 4,
	}
	json.merge(overrides, true)
	return json


func test_from_received_maps_src_and_dest():
	var item = NetworkItem.from(_make_json(), true)
	assert_eq(item.id, 1)
	assert_eq(item.loc_id, 2)
	assert_eq(item.src_player_id, 4)
	assert_eq(item.dest_player_id, 3)
	assert_eq(item.flags, 1)


func test_from_sent_maps_src_and_dest():
	var item = NetworkItem.from(_make_json(), false)
	assert_eq(item.src_player_id, 3)
	assert_eq(item.dest_player_id, 4)


func test_from_coerces_flags_to_int():
	var item = NetworkItem.from(_make_json({"flags": 5.0}), true)
	assert_eq(item.flags, 5)
	assert_true(item.flags is int)


func test_from_wrong_class_returns_null():
	assert_null(NetworkItem.from(_make_json({"class": "NetworkSlot"}), true))


func test_from_hint_maps_fields():
	var item = NetworkItem.from_hint(_make_hint_json())
	assert_eq(item.id, 10)
	assert_eq(item.loc_id, 20)
	assert_eq(item.src_player_id, 1)
	assert_eq(item.dest_player_id, 2)
	assert_eq(item.flags, 4)


func test_from_hint_wrong_class_returns_null():
	assert_null(NetworkItem.from_hint(_make_hint_json({"class": "NetworkItem"})))


func test_is_local():
	var item = NetworkItem.new()
	item.src_player_id = 1
	item.dest_player_id = 1
	assert_true(item.is_local())
	item.dest_player_id = 2
	assert_false(item.is_local())


func test_is_prog_checks_advancement_bit():
	var item = NetworkItem.new()
	item.flags = 1
	assert_true(item.is_prog())
	item.flags = 0
	assert_false(item.is_prog())
	item.flags = 2
	assert_false(item.is_prog())


func test_get_classification():
	var item = NetworkItem.new()
	item.flags = 1
	assert_eq(item.get_classification(), "Progression")
	item.flags = 3
	assert_eq(item.get_classification(), "Progression,Useful")


func test_get_name_uses_destination_cache():
	var slot = NetworkSlot.new()
	slot.game = "Test"
	_ap.conn.slots = [slot]
	var caches = _ap._data_caches
	caches["Test"] = DataCache.from({"item_name_to_id": {"Sword": 1}})
	var item = NetworkItem.new()
	item.id = 1
	item.dest_player_id = 1
	assert_eq(item.get_name(), "Sword")


func test_to_string_contains_fields():
	var item = NetworkItem.from(_make_json(), true)
	assert_eq(str(item), "ITEM(1 at 2,player 4->3,flags 1)")
