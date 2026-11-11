extends "res://addons/gut/test.gd"
## Tests for ConnectionInfo helper methods.


## Connection with the given player names; ids are 1-based.
func _make_conn(pid, names):
	var conn = ConnectionInfo.new()
	conn.player_id = pid
	var players = []
	var slots = []
	for i in range(names.size()):
		var plyr = NetworkPlayer.new()
		plyr.slot = i + 1
		plyr.name = names[i]
		players.append(plyr)
		var slot = NetworkSlot.new()
		slot.name = names[i]
		slot.game = "Test"
		slots.append(slot)
	conn.players = players
	conn.slots = slots
	return conn


## The default id must resolve to the current player, not print "-1".
func test_get_player_name_uses_current_player_for_default_id():
	var conn = _make_conn(1, [""])
	assert_eq(conn.get_player_name(), "Player 1")


## Explicit ids keep using the requested id in the fallback name.
func test_get_player_name_explicit_unnamed_player():
	var conn = _make_conn(1, ["Alice", ""])
	assert_eq(conn.get_player_name(2), "Player 2")


func test_get_player_name_resolves_name():
	var conn = _make_conn(1, ["Alice"])
	assert_eq(conn.get_player_name(), "Alice")


## Incoming KnockbackLink values are always exposed as a Vector3.
func test_knockback_value_to_vector3_full():
	var vec = Vector3(1, 2, 3)
	assert_eq(
		ConnectionInfo.knockback_value_to_vector3({"x": 1, "y": 2, "z": 3}),
		vec
	)


func test_knockback_value_to_vector3_partial():
	var vec = Vector3(1, 2, 0)
	assert_eq(
		ConnectionInfo.knockback_value_to_vector3({"x": 1, "y": 2}),
		vec
	)


func test_knockback_value_to_vector3_invalid():
	assert_null(ConnectionInfo.knockback_value_to_vector3("nope"))
	assert_null(ConnectionInfo.knockback_value_to_vector3({"x": "nope"}))
	assert_null(ConnectionInfo.knockback_value_to_vector3(null))


func test_knockback_value_to_dict_vector3():
	var vec = Vector3(1, 2, 3)
	assert_eq_deep(
		ConnectionInfo.knockback_value_to_dict(vec),
		{"x": 1.0, "y": 2.0, "z": 3.0}
	)


func test_knockback_value_to_dict_vector2():
	var vec = Vector2(1, 2)
	assert_eq_deep(
		ConnectionInfo.knockback_value_to_dict(vec), {"x": 1.0, "y": 2.0, "z": 0.0}
	)


func test_knockback_value_to_dict_dictionary():
	assert_eq_deep(
		ConnectionInfo.knockback_value_to_dict({"x": 1, "z": 3}),
		{"x": 1.0, "y": 0.0, "z": 3.0}
	)


func test_knockback_value_to_dict_invalid():
	assert_null(ConnectionInfo.knockback_value_to_dict("nope"))
	assert_null(ConnectionInfo.knockback_value_to_dict({"x": "nope"}))
