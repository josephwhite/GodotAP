extends "res://addons/gut/test.gd"
## Tests for the Version class.


func test_val():
	var v = Version.val(1, 2, 3)
	assert_eq(v.major, 1)
	assert_eq(v.minor, 2)
	assert_eq(v.build, 3)


func test_from():
	var v = Version.from({"class": "Version", "major": 1, "minor": 2, "build": 3})
	assert_eq(v.major, 1)
	assert_eq(v.minor, 2)
	assert_eq(v.build, 3)


func test_from_wrong_class():
	assert_eq(Version.from({"class": "NetworkItem", "major": 1}), null)


func test_to_string_format():
	assert_eq(Version.val(1, 2, 3)._to_string(), "VER(1.2.3)")


func test_compare_priority():
	# Major
	assert_eq(Version.val(2, 0, 0).compare(Version.val(1, 99, 99)), 1)
	# Minor
	assert_eq(Version.val(1, 3, 0).compare(Version.val(1, 2, 99)), 1)
	assert_eq(Version.val(1, 2, 5).compare(Version.val(1, 2, 3)), 2)
	# Build
	assert_eq(Version.val(1, 2, 3).compare(Version.val(1, 2, 5)), -2)
	assert_eq(Version.val(1, 2, 3).compare(Version.val(1, 2, 3)), 0)


func test_as_dicts():
	assert_eq_deep(
		Version.val(1, 2, 3)._as_ap_dict(), {"major": 1, "minor": 2, "build": 3, "class": "Version"}
	)
	assert_eq_deep(Version.val(1, 2, 3)._as_semver_dict(), {"major": 1, "minor": 2, "patch": 3})


## Negative numbers can still be valid, right?
func test_negative_versions():
	var val = Version.val(-1, 0, 0)
	assert_eq(val.major, -1)
	var from = Version.from({"class": "Version", "major": -2, "minor": 1, "build": 3})
	assert_eq(from.major, -2)
	assert_eq(Version.val(2, 0, 0).compare(Version.val(-1, 0, 0)), 3)
	var ver_to_string = Version.val(-1, 0, 0)._to_string()
	assert_eq(ver_to_string, "VER(-1.0.0)")
