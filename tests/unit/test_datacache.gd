extends "res://addons/gut/test.gd"
## Tests for the DataCache class.


func _make_cache(item_map, loc_map):
	return DataCache.from({"item_name_to_id": item_map, "location_name_to_id": loc_map})


func _make_loc_cache(loc_map):
	return DataCache.from({"location_name_to_id": loc_map})


func test_get_loc_id_returns_int():
	var cache = _make_loc_cache({"Boss": 7})
	var id = cache.get_loc_id("Boss")
	assert_eq(id, 7)
	assert_true(id is int)


func test_get_loc_id_unknown_returns_minus_one():
	assert_eq(_make_loc_cache({"Boss": 7}).get_loc_id("Nope"), -1)


func test_get_loc_id_float_values_coerced():
	var cache = _make_loc_cache({"Boss": 7.0})
	assert_eq(cache.get_loc_id("Boss"), 7)
	assert_true(cache.location_name_to_id.values()[0] is int)


func test_get_loc_name_reverse():
	assert_eq(_make_loc_cache({"Boss": 7}).get_loc_name(7), "Boss")


func test_get_loc_name_float_id_matches():
	assert_eq(_make_loc_cache({"Boss": 7}).get_loc_name(7.0), "Boss")


func test_get_loc_name_special_ids():
	var cache = DataCache.new()
	assert_eq(cache.get_loc_name(-1), "Server")
	assert_eq(cache.get_loc_name(-2), "Starting Inventory")
	assert_eq(cache.get_loc_name(-3), "??? #-3")


func test_get_loc_name_missing_returns_id_str():
	assert_eq(_make_loc_cache({"Boss": 7}).get_loc_name(99), "99")


func test_from_defaults_and_checksum():
	var empty = DataCache.new()
	assert_eq(empty.location_name_to_id.size(), 0)
	assert_false(empty.is_valid())
	var checksum_only = DataCache.from({"checksum": "abc"})
	assert_true(checksum_only.is_valid())
	assert_eq(checksum_only.location_name_to_id.size(), 0)


func test_item_location_maps_independent():
	var cache = DataCache.from(
		{
			"item_name_to_id": {"Sword": 1},
			"location_name_to_id": {"Boss": 2},
		}
	)
	assert_eq(cache.get_loc_id("Sword"), -1)
	assert_eq(cache.get_item_id("Boss"), -1)
