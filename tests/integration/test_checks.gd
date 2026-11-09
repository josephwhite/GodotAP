extends "res://addons/gut/test.gd"

const FAKE = preload("res://tests/fixtures/fake_socket.gd")

var _ap
## Logged messages
var _logged = []
## Locations emitted via remove_location()
var _removed = []


## Check if Location was warned for not being valid
func _warned_for(lid):
	for entry in _logged:
		if (
			str(lid) in entry
			and ("not a valid location" in entry or "No active connection" in entry)
		):
			return true
	return false


func _setup_conn(locations):
	var conn = ConnectionInfo.new()
	conn.slot_locations = locations
	_ap.conn = conn


func _setup_fake_socket():
	_ap._socket = FAKE.FakeSocket.new()


func _last_sent():
	var peer = _ap._socket.peer
	if peer.sent.size() == 0:
		return {}
	return parse_json(peer.sent[peer.sent.size() - 1])[0]


## Get logged messages
func _on_logged(msg):
	_logged.append(msg)


func _on_removed(lid):
	_removed.append(lid)


func before_each():
	_ap = Engine.get_main_loop().get_root().get_node("Archipelago")
	_logged = []
	_removed = []
	_ap.connect("_logged_message", self, "_on_logged")
	_ap.connect("remove_location", self, "_on_removed")
	_setup_fake_socket()


func after_each():
	if _ap.is_connected("_logged_message", self, "_on_logged"):
		_ap.disconnect("_logged_message", self, "_on_logged")
	if _ap.is_connected("remove_location", self, "_on_removed"):
		_ap.disconnect("remove_location", self, "_on_removed")
	var caches = _ap._data_caches
	caches.erase("Test")
	_ap.conn = null
	_ap._socket = null
	_ap.AP_VALIDATE_LOCATION_CHECKS = true


## No connection should mean locations for slot are none
func test_loc_getters_null_conn_safe():
	_ap.conn = null
	assert_false(_ap.location_exists(1))
	assert_eq(_ap.location_checked(1, "def"), "def")
	assert_eq(_ap.location_list(), [])


#region Collect


func test_collect_location_valid_sends():
	_setup_conn({1: false})
	var sent = _ap.collect_location(1)
	assert_true(sent)
	var frame = _last_sent()
	assert_eq(frame["cmd"], "LocationChecks")
	assert_eq(frame["locations"], [1.0])
	assert_true(_ap.location_checked(1))


func test_collect_location_invalid_skips():
	_setup_conn({1: false})
	var sent = _ap.collect_location(9)
	assert_false(sent)
	assert_eq(_ap._socket.peer.sent.size(), 0)
	assert_false(_ap.conn.slot_locations.has(9))
	assert_true(_warned_for(9))


func test_collect_locations_filters_invalid():
	_setup_conn({1: false, 2: true, 3: false})
	var count = _ap.collect_locations([1, 9, 3])
	assert_eq(count, 2)
	var frame = _last_sent()
	assert_eq(frame["locations"], [1.0, 3.0])
	assert_false(_ap.conn.slot_locations.has(9))
	assert_true(_warned_for(9))
	assert_false(_warned_for(1))


func test_collect_valid_when_null_conn():
	_setup_conn({1: false})
	_ap.conn = null
	assert_false(_ap.collect_location(1))
	assert_eq(_ap.collect_locations([1, 3]), 0)
	assert_eq(_ap._socket.peer.sent.size(), 0)
	assert_true(_warned_for(1))


func test_collect_location_unvalidated_sends():
	_ap.AP_VALIDATE_LOCATION_CHECKS = false
	_setup_conn({1: false})
	var sent = _ap.collect_location(9)
	assert_true(sent)
	var frame = _last_sent()
	assert_eq(frame["cmd"], "LocationChecks")
	assert_eq(frame["locations"], [9.0])
	assert_false(_warned_for(9))


func test_collect_locations_unvalidated_sends_all():
	_ap.AP_VALIDATE_LOCATION_CHECKS = false
	_setup_conn({1: false, 2: true, 3: false})
	var count = _ap.collect_locations([1, 9, 3])
	assert_eq(count, 3)
	var frame = _last_sent()
	assert_eq(frame["locations"], [1.0, 9.0, 3.0])
	assert_true(_ap.conn.slot_locations.has(9))
	assert_false(_warned_for(9))


#endregion

#region Scout


func test_scout_invalid_skips():
	_setup_conn({1: false})
	var conn = _ap.conn
	conn.scout(9, false, null)
	assert_eq(_ap._socket.peer.sent.size(), 0)
	assert_true(_warned_for(9))


func test_scout_valid_sends():
	_setup_conn({1: false})
	var conn = _ap.conn
	conn.scout(1, false, null)
	var frame = _last_sent()
	assert_eq(frame["cmd"], "LocationScouts")
	assert_eq(frame["locations"], [1.0])


func test_scout_cached_skips_send():
	_setup_conn({1: false})
	var conn = _ap.conn
	conn._scout_cache[1] = NetworkItem.new()
	conn.scout(1, false, null)
	assert_eq(_ap._socket.peer.sent.size(), 0)


func test_scout_unvalidated_sends():
	_ap.AP_VALIDATE_LOCATION_CHECKS = false
	_setup_conn({1: false})
	var conn = _ap.conn
	conn.scout(9, false, null)
	var frame = _last_sent()
	assert_eq(frame["cmd"], "LocationScouts")
	assert_eq(frame["locations"], [9.0])
	assert_false(_warned_for(9))

#endregion

#region Pseudo-locations


## Connection with one slot/player so `_receive_item` can resolve a datacache.
func _setup_item_conn():
	var conn = ConnectionInfo.new()
	conn.player_id = 1
	conn.slot_locations = {}
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
			"item_name_to_id": {
				"Sword": 1
			},
			"location_name_to_id": {
				"Chest": 2
			}
		}
	)
	return conn


func _make_item(loc_id):
	var item = NetworkItem.new()
	item.id = 1
	item.loc_id = loc_id
	item.src_player_id = 1
	item.dest_player_id = 1
	item.flags = 0
	return item


func test_remove_loc_ignores_pseudo_locations():
	_setup_conn({1: false})
	_ap._remove_loc(-2)
	assert_false(_ap.conn.slot_locations.has(-2))
	assert_eq(_removed, [])


func test_receive_item_pseudo_location_not_added_to_location_list():
	var conn = _setup_item_conn()
	assert_true(_ap._receive_item(0, _make_item(-2)))
	assert_false(conn.slot_locations.has(-2))
	assert_eq(_ap.location_list(), [])
	assert_eq(_removed, [])

#endregion
