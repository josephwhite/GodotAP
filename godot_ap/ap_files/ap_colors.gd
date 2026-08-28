class_name APColors

## Represents a color in one of multiple formats.
class ComplexColor:
	var rich setget _set_rich
	func _set_rich(val):
		if val is int: # RichColor is an enum (int in 3.6)
			rich = val
			special = null
			plain = null
		else: rich = null
	var special setget _set_special
	func _set_special(val):
		if val is int: # SpecialColor is an enum (int in 3.6)
			rich = null
			special = val
			plain = null
		else:
			special = null
	var plain setget _set_plain
	func _set_plain(val):
		if val is String:
			rich = null
			special = null
			plain = val
		elif val is Color:
			plain = str(val)
		else: plain = null
	static func as_rich(color):
		var ret = ComplexColor.new()
		ret.rich = color
		return ret
	static func as_special(color):
		var ret = ComplexColor.new()
		ret.special = color
		return ret
	static func as_plain_str(color):
		var ret = ComplexColor.new()
		ret.plain = color
		return ret
	static func as_plain_col(color):
		var ret = ComplexColor.new()
		ret.plain = color
		return ret
	const NIL = null

enum RichColor {
	NIL, RED, GREEN, YELLOW, BLUE,
	MAGENTA, CYAN, WHITE, BLACK, SLATEBLUE,
	PLUM, SALMON, ORANGE, GOLD,
}

enum SpecialColor {
	ANY_PLAYER, OWN_PLAYER, ITEM_PROG, ITEM, ITEM_USEFUL, ITEM_TRAP, ITEM_PROGUSEFUL,
	LOCATION, UI_MESSAGE, DEBUG,
}

const special_colors = {
	SpecialColor.ANY_PLAYER: RichColor.YELLOW,
	SpecialColor.OWN_PLAYER: RichColor.MAGENTA,
	SpecialColor.ITEM_PROG: RichColor.PLUM,
	SpecialColor.ITEM: RichColor.CYAN,
	SpecialColor.ITEM_USEFUL: RichColor.SLATEBLUE,
	SpecialColor.ITEM_TRAP: RichColor.SALMON,
	SpecialColor.ITEM_PROGUSEFUL: RichColor.GOLD,
	SpecialColor.LOCATION: RichColor.GREEN,
	SpecialColor.UI_MESSAGE: RichColor.GOLD,
	SpecialColor.DEBUG: RichColor.MAGENTA,
}

## Checks if a string matches a RichColor
static func is_rich_color_name(s):
	if s == "nil": return false
	var keys = RichColor.keys()
	for c in keys:
		if str(c).to_lower() == s:
			return true
	return false
## Gets a RichColor from a string. 'RichColor.NIL' is returned if the string is invalid.
static func rich_color_from_name(s):
	var keys = RichColor.keys()
	for i in range(keys.size()):
		if str(keys[i]).to_lower() == s:
			return RichColor.values()[i]
	return RichColor.NIL
static func _get_rich_color_name(node, s, default = Color(1, 1, 1)):
	if node.has_color("rich_%s" % s, "Console_Label"):
		return node.get_color("rich_%s" % s, "Console_Label")
	return default
## Gets a 'Color' represented by a 'RichColor'. Uses the 'Theme' of the specified node.
static func get_rich_color(node, c, default = Color(1, 1, 1)):
	if c == RichColor.NIL:
		return default
	var key = _richcolor_find_key(c)
	if key == null: return default
	return _get_rich_color_name(node, key.to_lower(), default)
static func _richcolor_find_key(c):
	for k in RichColor:
		if RichColor[k] == c: return k
	return null
## Gets a 'Color' represented by a 'SpecialColor'. Uses the 'Theme' of the specified node.
static func get_special_color(node, c, default = Color(1, 1, 1)):
	return get_rich_color(node, special_colors.get(c, RichColor.NIL), default)
## Returns the 'RichColor' that the specified 'SpecialColor' represents.
static func special_to_rich_color(c, default = RichColor.NIL):
	return special_colors.get(c, default)
## Gets a 'Color' from a 'String'. Will use a 'RichColor' if one matches, else falls back to Godot's 'Color.from_string()' implementation.
static func color_from_name(node, colname, def = Color(0, 0, 0, 0)):
	return _get_rich_color_name(node, colname, Util._color_from_string(colname, def))
