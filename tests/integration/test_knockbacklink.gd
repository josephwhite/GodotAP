extends "res://addons/gut/test.gd"
## KnockbackLink tag, packet, self-skip, and conversion tests.

const FAKE = preload("res://tests/fixtures/fake_socket.gd")

var _ap
## Logged messages
var _logged = []
## Fired count of the unconditional `ConnectionInfo.bounce` signal
var _bounced = 0
## KnockbackLink signals captured as dictionaries
var _knockbacks = []


func _setup_conn():
	var conn = ConnectionInfo.new()
	conn.slot_locations = {}
	conn.connect("bounce", self, "_on_bounce")
	_ap.conn = conn


## Connection with a resolvable player, for the send paths.
func _setup_conn_with_player():
	_setup_conn()
	var plyr = NetworkPlayer.new()
	plyr.name = "Alice"
	_ap.conn.players = [plyr]
	_ap.conn.player_id = 1


func _setup_fake_socket():
	_ap._socket = FAKE.FakeSocket.new()


func _last_sent():
	if _ap._socket.peer.sent.size() == 0:
		return {}
	return parse_json(_ap._socket.peer.sent[_ap._socket.peer.sent.size() - 1])[0]


func _receive_from_server(s):
	_ap._socket.peer.incoming.append(s)
	_ap._on_ws_data()


## Sends a KnockbackLink `Bounced` packet with the given data.
func _receive_knockback(data):
	_receive_from_server(
		'{"cmd":"Bounced","tags":["KnockbackLink"],"data":%s}' % to_json(data)
	)


func _on_logged(msg):
	_logged.append(msg)


func _on_knockbacklink(source, cause, value, uuid, json):
	_knockbacks.append(
		{
			"source": source,
			"cause": cause,
			"value": value,
			"uuid": uuid,
			"json": json,
		}
	)


func _on_bounce(_json):
	_bounced += 1


func before_each():
	_ap = Engine.get_main_loop().get_root().get_node("Archipelago")
	_logged = []
	_bounced = 0
	_knockbacks = []
	_ap.connect("_logged_message", self, "_on_logged")
	_setup_fake_socket()


func after_each():
	if _ap.is_connected("_logged_message", self, "_on_logged"):
		_ap.disconnect("_logged_message", self, "_on_logged")
	_ap._queue_reconnect = false
	_ap._set_status(0)  # APStatus.DISCONNECTED
	if _ap._tags_update_pending:
		_ap._flush_tags_update()
	_ap.AP_GAME_TAGS.clear()
	_ap._is_nongame_client = false
	_ap.conn = null
	_ap._socket = null


#region Tags


func test_knockbacklink_default_not_enabled():
	assert_false(_ap.is_knockbacklink())


func test_knockbacklink_default_tag():
	assert_eq(_ap.get_knockbacklink_tag(), "KnockbackLink")


## KnockbackLink has no group variants, so the bare tag is preserved as-is.
func test_set_misc_tags_preserves_knockbacklink():
	_ap.set_knockbacklink(true)
	_ap.set_misc_tags(["TextOnly"])
	assert_true(_ap.has_tag("KnockbackLink"))
	assert_true(_ap.has_tag("TextOnly"))


func test_set_misc_tags_erases_inactive_knockbacklink():
	_ap.set_misc_tags(["TextOnly"])
	assert_false(_ap.has_tag(_ap.get_knockbacklink_tag()))
	assert_eq_deep(_ap.AP_GAME_TAGS, ["TextOnly"])


#endregion

#region Bounce - Receives


func test_bounce_knockbacklink_signal():
	_setup_conn()
	_ap.conn.connect("knockbacklink", self, "_on_knockbacklink")
	_receive_knockback(
		{
			"time": 10.0,
			"source": "Alice",
			"cause": "boom",
			"uuid": "other",
			"value": {"x": 1, "y": 2, "z": 3},
		}
	)
	assert_eq(_knockbacks.size(), 1)
	assert_eq(_knockbacks[0]["source"], "Alice")
	assert_eq(_knockbacks[0]["cause"], "boom")
	assert_eq(_knockbacks[0]["value"], Vector3(1, 2, 3))
	assert_eq(_knockbacks[0]["uuid"], "other")
	assert_eq(_bounced, 1)


## 2D senders may omit unused axes; missing components default to zero.
func test_bounce_knockbacklink_partial_value():
	_setup_conn()
	_ap.conn.connect("knockbacklink", self, "_on_knockbacklink")
	_receive_knockback({"source": "Bob", "value": {"x": 4, "y": -2}})
	assert_eq(_knockbacks.size(), 1)
	assert_eq(_knockbacks[0]["value"], Vector3(4, -2, 0))


func test_bounce_knockbacklink_invalid_value_logs_and_skips():
	_setup_conn()
	_ap.conn.connect("knockbacklink", self, "_on_knockbacklink")
	_receive_knockback({"source": "Bob", "value": "nope"})
	assert_eq(_knockbacks.size(), 0)
	assert_eq(_bounced, 1)
	assert_true(_logged.size() > 0)
	assert_true(_logged[0].find("KnockbackLink") >= 0)


func test_bounce_knockbacklink_non_dict_data_logs_and_skips():
	_setup_conn()
	_ap.conn.connect("knockbacklink", self, "_on_knockbacklink")
	_receive_from_server('{"cmd":"Bounced","tags":["KnockbackLink"],"data":"nope"}')
	assert_eq(_knockbacks.size(), 0)
	assert_eq(_bounced, 1)
	assert_true(_logged.size() > 0)
	assert_true(_logged[0].find("KnockbackLink") >= 0)


## Our own per-session uuid means the knockback came from this client.
func test_bounce_knockbacklink_self_skipped_by_uuid():
	_setup_conn()
	_ap.conn.connect("knockbacklink", self, "_on_knockbacklink")
	_receive_knockback(
		{"source": "Alice", "uuid": _ap.knockbacklink_uuid, "value": {"x": 1}}
	)
	assert_eq(_knockbacks.size(), 0)
	assert_eq(_bounced, 1)


func test_bounce_knockbacklink_other_uuid_not_skipped():
	_setup_conn()
	_ap.conn.connect("knockbacklink", self, "_on_knockbacklink")
	_receive_knockback({"source": "Alice", "uuid": "other", "value": {"x": 1}})
	assert_eq(_knockbacks.size(), 1)


## Senders that omit the optional uuid are never mistaken for us.
func test_bounce_knockbacklink_missing_uuid_not_skipped():
	_setup_conn()
	_ap.conn.connect("knockbacklink", self, "_on_knockbacklink")
	_receive_knockback({"source": "Alice", "value": {"x": 1}})
	assert_eq(_knockbacks.size(), 1)
	assert_eq(_knockbacks[0]["uuid"], "")


## KnockbackLink has no group variants; only the exact tag matches.
func test_bounce_knockbacklink_group_variant_ignored():
	_setup_conn()
	_ap.conn.connect("knockbacklink", self, "_on_knockbacklink")
	_receive_from_server(
		'{"cmd":"Bounced","tags":["KnockbackLinkg2"],"data":{"source":"Alice","value":{"x":1}}}'
	)
	assert_eq(_knockbacks.size(), 0)
	assert_eq(_bounced, 1)


## Like DeathLink, the derived signal fires even when the local link is off.
func test_bounce_knockbacklink_fires_with_link_off():
	_setup_conn()
	_ap.conn.connect("knockbacklink", self, "_on_knockbacklink")
	_receive_knockback({"source": "Alice", "uuid": "other", "value": {"x": 1}})
	assert_eq(_knockbacks.size(), 1)


#endregion

#region Sends


func test_send_knockbacklink_packet():
	_setup_conn_with_player()
	_ap.set_knockbacklink(true)
	_ap.conn.send_knockbacklink(Vector3(10, 5, 1), "boom")
	var frame = _last_sent()
	assert_eq(frame["cmd"], "Bounce")
	assert_eq_deep(frame["tags"], ["KnockbackLink"])
	assert_eq(frame["data"]["source"], "Alice")
	assert_eq(frame["data"]["uuid"], _ap.knockbacklink_uuid)
	assert_eq(frame["data"]["cause"], "boom")
	assert_true(frame["data"].has("time"))
	assert_eq_deep(frame["data"]["value"], {"x": 10.0, "y": 5.0, "z": 1.0})


## Vector2 maps to x/y and leaves z at zero for 2D games.
func test_send_knockbacklink_vector2():
	_setup_conn_with_player()
	_ap.set_knockbacklink(true)
	_ap.conn.send_knockbacklink(Vector2(3, -4))
	var frame = _last_sent()
	assert_eq_deep(frame["data"]["value"], {"x": 3.0, "y": -4.0, "z": 0.0})
	assert_false(frame["data"].has("cause"))


## Dictionaries may provide only the axes the game supports.
func test_send_knockbacklink_dictionary():
	_setup_conn_with_player()
	_ap.set_knockbacklink(true)
	_ap.conn.send_knockbacklink({"x": 1, "z": 9})
	var frame = _last_sent()
	assert_eq_deep(frame["data"]["value"], {"x": 1.0, "y": 0.0, "z": 9.0})


func test_send_knockbacklink_blocked_when_off():
	_setup_conn_with_player()
	_ap.conn.send_knockbacklink(Vector3(1, 0, 0))
	assert_eq(_ap._socket.peer.sent.size(), 0)
	assert_true(_logged.size() > 0)
	assert_true(_logged[0].find("KnockbackLink") >= 0)


func test_send_knockbacklink_invalid_value_blocked():
	_setup_conn_with_player()
	_ap.set_knockbacklink(true)
	_ap.conn.send_knockbacklink("nope")
	assert_eq(_ap._socket.peer.sent.size(), 0)
	assert_true(_logged.size() > 0)
	assert_true(_logged[0].find("invalid value") >= 0)


#endregion
