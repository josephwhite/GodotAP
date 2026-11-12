extends "res://addons/gut/test.gd"
## Tests for the NetworkHint class.

var _ap


func before_each():
	_ap = Engine.get_main_loop().get_root().get_node("Archipelago")


func after_each():
	var caches = _ap._data_caches
	caches.erase("Test")
	_ap.conn = null


func _make_json(overrides = {}):
	var json = {
		"class": "Hint",
		"item": 1,
		"location": 2,
		"finding_player": 3,
		"receiving_player": 4,
		"item_flags": 1,
		"found": false,
		"status": 30,
		"entrance": "Door",
	}
	json.merge(overrides, true)
	return json


## Connection with one player and a fake item/location cache.
func _setup_conn():
	var conn = ConnectionInfo.new()
	conn.player_id = 1
	var slot = NetworkSlot.new()
	slot.name = "Alice"
	slot.game = "Test"
	conn.slots = [slot]
	var plyr = NetworkPlayer.new()
	plyr.name = "Alice"
	plyr.slot = 1
	conn.players = [plyr]
	_ap.conn = conn
	var caches = _ap._data_caches
	caches["Test"] = DataCache.from(
		{
			"item_name_to_id": {"Sword": 1},
			"location_name_to_id": {"Chest": 2},
		}
	)
	return conn


func test_from_found_overrides_status():
	var hint = NetworkHint.from(_make_json({"found": true}))
	assert_eq(hint.status, NetworkHint.Status.FOUND)
	assert_eq(hint.entrance, "Door")
	assert_eq(hint.item.id, 1)
	assert_eq(hint.item.loc_id, 2)
	assert_eq(hint.item.src_player_id, 3)
	assert_eq(hint.item.dest_player_id, 4)
	assert_eq(hint.item.flags, 1)


func test_from_uses_status_and_coerces_float():
	var hint = NetworkHint.from(_make_json({"status": 30.0}))
	assert_eq(hint.status, NetworkHint.Status.PRIORITY)
	assert_true(hint.status is int)


func test_from_missing_status_defaults_not_found():
	var json = _make_json()
	json.erase("status")
	var hint = NetworkHint.from(json)
	assert_eq(hint.status, NetworkHint.Status.NOT_FOUND)


func test_from_missing_entrance_defaults_empty():
	var json = _make_json()
	json.erase("entrance")
	var hint = NetworkHint.from(json)
	assert_eq(hint.entrance, "")


func test_from_wrong_class_returns_null():
	assert_null(NetworkHint.from(_make_json({"class": "NetworkItem"})))


func test_is_local_delegates_to_item():
	var hint = NetworkHint.from(_make_json({"finding_player": 1, "receiving_player": 1}))
	assert_true(hint.is_local())
	hint = NetworkHint.from(_make_json({"finding_player": 1, "receiving_player": 2}))
	assert_false(hint.is_local())


func test_status_names_cover_all_statuses():
	var expected = {
		NetworkHint.Status.FOUND: "Found",
		NetworkHint.Status.UNSPECIFIED: "Unspecified",
		NetworkHint.Status.NON_PRIORITY: "No Priority",
		NetworkHint.Status.AVOID: "Avoid",
		NetworkHint.Status.PRIORITY: "Priority",
		NetworkHint.Status.NOT_FOUND: "Not Found",
	}
	assert_eq_deep(NetworkHint.status_names, expected)


func test_to_string_contains_fields():
	var hint = NetworkHint.from(_make_json())
	assert_eq(str(hint), "HINT(3 1 4 2 30)")


func test_as_plain_string():
	_setup_conn()
	var hint = NetworkHint.from(
		_make_json(
			{
				"finding_player": 1,
				"receiving_player": 1,
				"status": NetworkHint.Status.PRIORITY,
			}
		)
	)
	assert_eq(
		hint.as_plain_string(),
		"Alice will find 'Sword' (Progression) for Alice at 'Chest'"
	)


func test_make_status_returns_label():
	var part = autofree(NetworkHint.make_hint_status(NetworkHint.Status.FOUND))
	assert_eq(part.text, "Found")
	assert_eq(part.rich_color, APColors.RichColor.GREEN)


func test_update_hint_status_sets_text_and_color():
	var part = autofree(ConsoleLabel.new())
	NetworkHint.update_hint_status(NetworkHint.Status.AVOID, part)
	assert_eq(part.text, "Avoid")
	assert_eq(part.rich_color, APColors.RichColor.SALMON)
