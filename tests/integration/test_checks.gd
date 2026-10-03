extends "res://addons/gut/test.gd"

const FAKE = preload("res://tests/fixtures/fake_socket.gd")

var _ap
## Logged messages
var _logged = []


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


func before_each():
	_ap = Engine.get_main_loop().get_root().get_node("Archipelago")
	_logged = []
	_ap.connect("_logged_message", self, "_on_logged")
	_setup_fake_socket()


func after_each():
	if _ap.is_connected("_logged_message", self, "_on_logged"):
		_ap.disconnect("_logged_message", self, "_on_logged")
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
