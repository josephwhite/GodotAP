extends "res://addons/gut/test.gd"
## Tests for the APLocation class.

var _ap


func before_each():
	_ap = Engine.get_main_loop().get_root().get_node("Archipelago")


func after_each():
	_ap.conn = null


## Minimal connection with `slot` players/slots, enough for location name lookup.
func _make_conn(slot):
	var conn = ConnectionInfo.new()
	conn.player_id = slot
	conn.team_id = 0
	conn.seed_name = "seed"
	var players = []
	players.resize(slot)
	for i in range(players.size()):
		var p = NetworkPlayer.new()
		p.team = 0
		p.slot = i + 1
		p.name = "P%d" % (i + 1)
		players[i] = p
	conn.players = players
	var slots = []
	slots.resize(slot)
	for i in range(slots.size()):
		var s = NetworkSlot.new()
		s.name = "S%d" % (i + 1)
		s.game = "Test"
		slots[i] = s
	conn.slots = slots
	return conn


## `hint_status` must default to a valid status key so `_to_string()` works.
## It was left untyped (null) in the port, unlike upstream's typed enum.
func test_new_location_to_string_does_not_error():
	var loc = APLocation.new()
	loc.id = 1
	loc.name = "Test Location"
	assert_string_contains(str(loc), "Test Location")


func test_make_location_to_string_does_not_error():
	_ap.conn = _make_conn(1)
	var loc = APLocation.make(42)
	assert_eq(loc.name, "42")  # no datacache for "Test" -> id fallback
	assert_string_contains(str(loc), "42")


func test_nil_location_to_string():
	var loc = APLocation.nil()
	assert_string_contains(str(loc), "INVALID")
