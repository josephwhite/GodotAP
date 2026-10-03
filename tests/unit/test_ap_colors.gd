extends "res://addons/gut/test.gd"
## Tests for the APColors class.


func test_as_rich():
	var c = APColors.ComplexColor.as_rich(APColors.RichColor.RED)
	assert_eq(c.rich, APColors.RichColor.RED)
	assert_eq(c.special, null)
	assert_eq(c.plain, null)


func test_as_special():
	var c = APColors.ComplexColor.as_special(APColors.SpecialColor.ITEM)
	assert_eq(c.special, APColors.SpecialColor.ITEM)
	assert_eq(c.rich, null)
	assert_eq(c.plain, null)


func test_as_plain_str():
	var c = APColors.ComplexColor.as_plain_str("red")
	assert_eq(c.plain, "red")
	assert_eq(c.rich, null)
	assert_eq(c.special, null)


func test_as_plain_col():
	var c = APColors.ComplexColor.as_plain_col(Color(1, 0, 0))
	assert_eq(c.plain, str(Color(1, 0, 0)))
	assert_eq(c.rich, null)
	assert_eq(c.special, null)


func test_setters_reject_wrong_type():
	var c = APColors.ComplexColor.new()
	c.rich = "nope"
	assert_eq(c.rich, null)
	c.special = "nope"
	assert_eq(c.special, null)
	c.plain = 5
	assert_eq(c.plain, null)


func test_rich_color_from_name():
	assert_eq(APColors.rich_color_from_name("red"), APColors.RichColor.RED)
	assert_eq(APColors.rich_color_from_name("bogus"), APColors.RichColor.NIL)


func test_is_rich_color_name():
	assert_true(APColors.is_rich_color_name("red"))
	assert_true(APColors.is_rich_color_name("slateblue"))
	assert_false(APColors.is_rich_color_name("nil"))
	assert_false(APColors.is_rich_color_name("bogus"))


func test_special_to_rich_color():
	assert_eq(
		APColors.special_to_rich_color(APColors.SpecialColor.ITEM_TRAP), APColors.RichColor.SALMON
	)
	assert_eq(APColors.special_to_rich_color(999), APColors.RichColor.NIL)
	assert_eq(
		APColors.special_to_rich_color(999, APColors.RichColor.WHITE), APColors.RichColor.WHITE
	)


## Make a themed node
func _node_with_rich(colors):
	var node = autofree(Control.new())
	var theme = Theme.new()
	for key in colors:
		theme.set_color("rich_%s" % key, "Console_Label", colors[key])
	node.theme = theme
	return node


func test_get_rich_color_default():
	var node = _node_with_rich({"red": Color(0.2, 0.1, 0.3), "green": Color(0.4, 0.5, 0.6)})
	var def = Color(0.1, 0.2, 0.3)
	assert_eq(APColors.get_rich_color(node, APColors.RichColor.RED, def), Color(0.2, 0.1, 0.3))
	assert_eq(APColors.get_rich_color(node, APColors.RichColor.GREEN, def), Color(0.4, 0.5, 0.6))
	assert_eq(APColors.get_rich_color(node, APColors.RichColor.NIL, def), def)
	assert_eq(APColors.get_rich_color(node, 999, def), def)


func test_get_special_color_default():
	var node = _node_with_rich({"yellow": Color(0.9, 0.8, 0.1)})
	var def = Color(0.1, 0.2, 0.3)
	assert_eq(
		APColors.get_special_color(node, APColors.SpecialColor.ANY_PLAYER, def),
		Color(0.9, 0.8, 0.1)
	)
	assert_eq(APColors.get_special_color(node, 999, def), def)


func test_color_from_name_fallback():
	var node = _node_with_rich({"orange": Color(0.7, 0.6, 0.1)})
	assert_eq(APColors.color_from_name(node, "orange"), Color(0.7, 0.6, 0.1))
	assert_eq(APColors.color_from_name(node, "purple"), Color(0.5, 0, 0.5))
	assert_eq(APColors.color_from_name(node, "#ff0000"), Color(1, 0, 0))
	var def = Color(0.1, 0.2, 0.3)
	assert_eq(APColors.color_from_name(node, "bogus", def), def)
