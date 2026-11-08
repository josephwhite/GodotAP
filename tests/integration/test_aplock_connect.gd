extends "res://addons/gut/test.gd"
## Tests for APLock enforcement during the `Connected` handshake.

const FAKE = preload("res://tests/fixtures/fake_socket.gd")

var _ap
## Messages passed to `connect_step`
var _steps = []


func _on_connect_step(msg):
	_steps.append(msg)


func _setup_fake_socket():
	_ap._socket = FAKE.FakeSocket.new()


func _make_slot_json(slot_name):
	return {
		"class": "NetworkSlot",
		"name": slot_name,
		"game": "Test",
		"type": 1,
		"group_members": [],
	}


func _make_player_json(slot, name):
	return {"class": "NetworkPlayer", "team": 0, "slot": slot, "name": name}


func _make_connected_packet(slot, slot_name):
	return {
		"cmd": "Connected",
		"slot": slot,
		"team": 0,
		"slot_data": {},
		"players": [_make_player_json(slot, slot_name)],
		"slot_info": {str(slot): _make_slot_json(slot_name)},
		"missing_locations": [],
		"checked_locations": [],
	}


## Build a lock already bound to `slot`, matching what a loaded save would hold.
func _make_lock_for(slot, slot_name):
	var conn = ConnectionInfo.new()
	conn.player_id = slot
	conn.team_id = 0
	conn.seed_name = "seed1"
	var slots = []
	slots.resize(slot)
	for i in range(slots.size()):
		var s = NetworkSlot.new()
		s.name = slot_name
		s.game = "Test"
		slots[i] = s
	conn.slots = slots
	var lock = autofree(APLock.new())
	assert_eq(lock.lock(conn), [])
	return lock


func before_each():
	_ap = Engine.get_main_loop().get_root().get_node("Archipelago")
	_steps = []
	_ap._queue_reconnect = false
	_ap.aplock = null
	_ap.connect("connect_step", self, "_on_connect_step")
	_setup_fake_socket()


func after_each():
	if _ap.is_connected("connect_step", self, "_on_connect_step"):
		_ap.disconnect("connect_step", self, "_on_connect_step")
	_ap._queue_reconnect = false
	_ap.aplock = null
	_ap._stop_connect_watchdog()
	_ap._stop_datapack_watchdog()
	if _ap.hang_clock and _ap.hang_clock.is_inside_tree():
		_ap.hang_clock.stop()
	_ap._set_status(0)  # APStatus.DISCONNECTED
	_ap.conn = null
	_ap._socket = null


## A lock mismatch must tear the connection down even when no console is attached.
func test_aplock_mismatch_disconnects_without_console():
	_ap.aplock = _make_lock_for(1, "Alice")
	_ap.conn = ConnectionInfo.new()
	_ap._set_status(3)  # APStatus.CONNECTED
	_ap._handle_command(_make_connected_packet(2, "Bob"), [])
	assert_eq(_ap._socket.disconnects, 1, "mismatch must tear down the socket")
	assert_ne(_ap.status, 3, "must not stay connected on the wrong slot")
	assert_true(_steps.has("Connection Mismatch! Wrong slot for this save!"))
