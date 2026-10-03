extends "res://addons/gut/test.gd"
## Tests for util.gd functions.

const UTIL = preload("res://godot_ap/util/util.gd")


func test_ap_load():
	var s = UTIL._ap_load("util/util.gd")
	assert_ne(s, null)
	assert_eq(s.resource_path, "res://godot_ap/util/util.gd")


func test_find_break_paren():
	assert_eq(UTIL.find_break_paren(""), 0)
	assert_eq(UTIL.find_break_paren("foo"), 3)
	assert_eq(UTIL.find_break_paren("foo(bar)"), 8)
	assert_eq(UTIL.find_break_paren("foo(bar(baz)qux)"), 16)
	assert_eq(UTIL.find_break_paren("foo)"), 3)
	assert_eq(UTIL.find_break_paren("foo]"), 3)
	assert_eq(UTIL.find_break_paren("foo}"), 3)
	assert_eq(UTIL.find_break_paren("foo(bar]"), 7)


func test_split_args():
	assert_eq_deep(UTIL.split_args("a b c"), ["a", "b", "c"])
	assert_eq_deep(UTIL.split_args('a "b c" d'), ["a", '"b c"', "d"])
	assert_eq_deep(UTIL.split_args('"x y z"'), ['"x y z"'])


func test_is_zero_vec():
	assert_true(UTIL.is_zero_vec(Vector2(0, 0)))
	assert_true(UTIL.is_zero_vec(Vector2(0.00005, 0)))
	assert_false(UTIL.is_zero_vec(Vector2(1, 0)))


func test_approx_eq():
	assert_true(UTIL.approx_eq(1.0, 1.00005))
	assert_false(UTIL.approx_eq(1.0, 1.001))
	assert_true(UTIL.approx_eq_vec(Vector2(1, 2), Vector2(1.00005, 2)))
	assert_false(UTIL.approx_eq_vec(Vector2(1, 2), Vector2(1.001, 2)))


func test_get_mag():
	assert_true(UTIL.approx_eq(UTIL.get_mag(Vector2(3, 4)), 5.0))
	assert_true(UTIL.approx_eq(UTIL.get_mag(Vector2(-3, -4)), 5.0))


func test_reversed():
	var orig = [1, 2, 3]
	var rev = UTIL.reversed(orig)
	assert_eq_deep(rev, [3, 2, 1])
	assert_eq_deep(orig, [1, 2, 3])


func test_move_toward_directional():
	# Zero target: sign(0)=0 mismatches v1's sign, else-branch delta = abs(0)*.75 = 0,
	# so move_toward leaves the value untouched.
	assert_eq(
		UTIL.move_toward_directional(Vector2(10, 10), Vector2.ZERO),
		Vector2(10, 10),
		"zero target stays put"
	)
	# Same sign + |v1| > |v2| keeps the component; otherwise steps 75% toward v2.
	assert_eq(
		UTIL.move_toward_directional(Vector2(4, 4), Vector2(2, 1)),
		Vector2(4, 4),
		"same-sign larger magnitude keeps x and y"
	)
	assert_eq(
		UTIL.move_toward_directional(Vector2(4, -4), Vector2(2, -1)),
		Vector2(4, -4),
		"negative axis keeps both"
	)
	# Else-branch stepping (different sign on x, smaller magnitude on y).
	assert_eq(
		UTIL.move_toward_directional(Vector2.ZERO, Vector2(10, 10)),
		Vector2(7.5, 7.5),
		"zero origin steps 75% both axes"
	)
	assert_eq(
		UTIL.move_toward_directional(Vector2(2, 0), Vector2(4, 1)),
		Vector2(4, 0.75),
		"delta 3 clamps x at target 4, sign-flip y steps 0.75"
	)


func test_color_from_string():
	var fallback = Color(0, 0, 1)
	assert_eq(UTIL._color_from_string("#ff0000", fallback), Color(1, 0, 0))
	assert_eq(UTIL._color_from_string("#ff000080", fallback), Color(1, 0, 0, 128.0 / 255.0))
	assert_eq(UTIL._color_from_string("red", fallback), Color(1, 0, 0))
	assert_eq(UTIL._color_from_string("RED", fallback), Color(1, 0, 0))
	assert_eq(UTIL._color_from_string("gray", fallback), Color(0.5, 0.5, 0.5))
	assert_eq(UTIL._color_from_string("bogus", fallback), fallback)
	assert_eq(UTIL._color_from_string("", fallback), fallback)
