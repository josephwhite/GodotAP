extends "res://addons/gut/test.gd"
## Tests for the NetworkSlot class.


func _make_json(overrides = {}):
	var json = {
		"class": "NetworkSlot",
		"name": "Alice",
		"game": "Test",
		"type": 1,
		"group_members": [1, 2],
	}
	json.merge(overrides, true)
	return json


func test_from_copies_fields():
	var slot = NetworkSlot.from(_make_json())
	assert_eq(slot.name, "Alice")
	assert_eq(slot.game, "Test")
	assert_eq(slot.type, 1)
	assert_eq_deep(slot.group_members, [1, 2])


func test_from_wrong_class_returns_null():
	assert_null(NetworkSlot.from(_make_json({"class": "NetworkPlayer"})))


## Group members must be copied so later changes to the packet do not leak in.
func test_from_duplicates_group_members():
	var json = _make_json()
	var slot = NetworkSlot.from(json)
	json["group_members"].append(3)
	assert_eq_deep(slot.group_members, [1, 2])


func test_to_string_contains_fields():
	var slot = NetworkSlot.from(_make_json())
	var text = str(slot)
	assert_string_contains(text, "Alice")
	assert_string_contains(text, "Test")
	assert_string_contains(text, "type 1")
	assert_string_contains(text, "[1, 2]")
