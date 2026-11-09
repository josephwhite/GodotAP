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
