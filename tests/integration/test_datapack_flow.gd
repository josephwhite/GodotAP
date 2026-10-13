extends "res://addons/gut/test.gd"
## Tests for workflows around DataPackages and websocket operation interations

const FAKE = preload("res://tests/fixtures/fake_socket.gd")

var _ap
## Messages passed to `connect_failed`
var _failures = []
## Count of `all_datapacks_loaded` emissions
var _loaded = 0


func _on_connect_failed(msg):
	_failures.append(msg)


func _on_loaded():
	_loaded += 1


func _capture_log(msg, captured):
	captured.append(msg)


func _setup_fake_socket():
	_ap._socket = FAKE.FakeSocket.new()


func _last_sent():
	var peer = _ap._socket.peer
	if peer.sent.size() == 0:
		return {}
	return parse_json(peer.sent[peer.sent.size() - 1])[0]


func before_each():
	_ap = Engine.get_main_loop().get_root().get_node("Archipelago")
	_failures = []
	_loaded = 0
	_ap._queue_reconnect = false
	_ap.connect("connect_failed", self, "_on_connect_failed")
	_setup_fake_socket()


func after_each():
	if _ap.is_connected("connect_failed", self, "_on_connect_failed"):
		_ap.disconnect("connect_failed", self, "_on_connect_failed")
	_ap._queue_reconnect = false
	_ap._stop_connect_watchdog()
	_ap._stop_datapack_watchdog()
	if _ap.hang_clock and _ap.hang_clock.is_inside_tree():
		_ap.hang_clock.stop()
	_ap._handshake_failures = 0
	_ap._datapack_pending = []
	_ap.websocket_inbuffer_mb = 50
	_ap.websocket_outbuffer_mb = 50
	_ap._set_status(0)  # APStatus.DISCONNECTED
	_ap.conn = null
	_ap._socket = null

## Tests related to websocket buffer size
#region Buffer application


func test_apply_socket_buffers_converts_mb_to_kb():
	_ap.websocket_inbuffer_mb = 5
	_ap.websocket_outbuffer_mb = 128
	_ap._apply_socket_buffers()
	assert_eq(_ap._socket.buffers, [5 * 1024, 1024, 128 * 1024, 1024])


## A backend without `set_buffers` must exit cleanly:
## No buffer-set log emitted means guard branch was taken.
func test_apply_socket_buffers_without_method_is_safe():
	var dummy = FAKE.FakePeer.new()  # lacks `set_buffers`
	_ap._socket = dummy
	var captured = []
	_ap.connect("_logged_message", self, "_capture_log", [captured])
	_ap._apply_socket_buffers()
	_ap.disconnect("_logged_message", self, "_capture_log")
	assert_eq(captured, [])


#endregion

## Tests related to websocket and datapackage interations
#region Datapackage watchdog


func test_send_datapack_request_arms_watchdog():
	_ap._datapack_pending = ["GameA"]
	_ap._send_datapack_request()
	assert_eq(_ap._datapack_pending.size(), 0)
	assert_ne(_ap._datapack_watchdog, null)
	var frame = _last_sent()
	assert_eq(frame["cmd"], "GetDataPackage")
	assert_eq_deep(frame["games"], ["GameA"])


func test_all_datapacks_loaded_fires_once_when_none_pending():
	_ap.handle_datapackage_checksums({})
	_ap.connect("all_datapacks_loaded", self, "_on_loaded")
	_ap._send_datapack_request()
	_ap.disconnect("all_datapacks_loaded", self, "_on_loaded")
	assert_eq(_loaded, 1)
	assert_eq(_ap._datapack_watchdog, null)


func test_datapack_timeout_gives_up_with_hint():
	_ap._set_status(3)  # APStatus.CONNECTED
	_ap._on_datapack_timeout()
	assert_eq(_failures.size(), 1)
	assert_string_contains(_failures[0], "websocket_inbuffer_mb")


func test_datapack_timeout_ignored_when_not_connected():
	_ap._set_status(0)  # APStatus.DISCONNECTED
	_ap._on_datapack_timeout()
	assert_eq(_failures.size(), 0)


#endregion

## Tests related to websocket counting connection attempts
#region Handshake retries


func test_handshake_drop_below_cap_reconnects():
	_ap._handshake_failures = 0
	_ap._set_status(3)  # APStatus.CONNECTED
	_ap._handle_handshake_drop("boom")
	assert_eq(_ap._handshake_failures, 1)
	assert_true(_ap._queue_reconnect)
	assert_eq(_failures.size(), 0)


func test_handshake_drop_at_cap_gives_up():
	_ap._handshake_failures = _ap.MAX_HANDSHAKE_CYCLES
	_ap._set_status(3)  # APStatus.CONNECTED
	_ap._handle_handshake_drop("boom")
	assert_eq(_failures.size(), 1)
	assert_string_contains(_failures[0], "websocket_inbuffer_mb")


func test_ws_closed_mid_handshake_counts():
	_ap._handshake_failures = 0
	_ap._set_status(3)  # APStatus.CONNECTED
	_ap._on_ws_closed()
	assert_eq(_ap._handshake_failures, 1)


func test_ws_error_mid_handshake_counts():
	_ap._handshake_failures = 0
	_ap._set_status(3)  # APStatus.CONNECTED
	_ap._on_ws_error()
	assert_eq(_ap._handshake_failures, 1)


func test_ws_closed_playing_reconnects_without_counting():
	_ap._queue_reconnect = false
	_ap._set_status(4)  # APStatus.PLAYING (resets the counter)
	_ap._handshake_failures = 3
	_ap._on_ws_closed()
	assert_eq(_ap._handshake_failures, 3)
	assert_true(_ap._queue_reconnect)


func test_handshake_failures_reset_on_playing():
	_ap._handshake_failures = 4
	_ap._set_status(4)  # APStatus.PLAYING
	assert_eq(_ap._handshake_failures, 0)


#endregion
