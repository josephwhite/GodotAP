class_name ConsoleLabel extends Label

static func _get_scene():
	return Util._ap_load("ui/console/console_label.tscn")

const _RICH_COLOR_NIL = 0

signal clicked(index)
signal changed_rich_color(color)

const _console_label_fonts_state = {"v": null}
static func get_console_label_fonts():
	return _console_label_fonts_state.v
static func set_console_label_fonts(val):
	_console_label_fonts_state.v = val

func _get_color():
	return APColors.get_rich_color(self, rich_color)

var bold = false setget set_bold, get_bold
func set_bold(val):
	if bold == val: return
	bold = val
	_notification(NOTIFICATION_THEME_CHANGED)
func get_bold():
	return bold

var italic = false setget set_italic, get_italic
func set_italic(val):
	if italic == val: return
	italic = val
	_notification(NOTIFICATION_THEME_CHANGED)
func get_italic():
	return italic

var wrapping = true setget set_wrapping, get_wrapping
func set_wrapping(val):
	if wrapping == val: return
	wrapping = val
	autowrap = true
	if val:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	refresh_size()
func get_wrapping():
	return wrapping

var rich_color = null setget set_rich_color, get_rich_color
var color_override = ""

func get_rich_color():
	return rich_color
func set_rich_color(c):
	rich_color = c
	refresh_color()
	emit_signal("changed_rich_color", c)

func _init():
	theme_type_variation = "Console_Label"
	color_override = ""
	rich_color = _RICH_COLOR_NIL
	_notification(NOTIFICATION_THEME_CHANGED)

func _ready():
	refresh_color()
	refresh_size()
func refresh_color():
	if color_override.empty():
		if rich_color == APColors.RichColor.NIL:
			if has_color_override("font_color"):
				remove_color_override("font_color")
				update()
		elif (not has_color_override("font_color") or get_color("font_color") != _get_color()):
			var col = _get_color()
			if col != null:
				add_color_override("font_color", col)
				update()
	else:
		var c = APColors.color_from_name(self, color_override)
		if get_color("font_color") != c:
			add_color_override("font_color", c)
			update()
func refresh_size():
	var minsz = Vector2()
	if not wrapping:
		minsz = get_font("font").get_string_size(text)
		if rect_global_position.x + minsz.x > _parent_global_rect.end.x:
			minsz.x = _parent_global_rect.end.x - rect_global_position.x
		if rect_global_position.y + minsz.y > _parent_global_rect.end.y:
			minsz.y = _parent_global_rect.end.y - rect_global_position.y
	if not minsz.is_equal_approx(rect_min_size):
		rect_min_size = minsz
func set_content(new_text, new_ttip = ""):
	text = new_text
	hint_tooltip = new_ttip
	refresh_size()

static func make(txt, ttip = ""):
	var ret = _get_scene().instance()
	ret.set_content(txt, ttip)
	return ret

static func make_rich(txt, col, ttip = ""):
	var ret = make(txt, ttip)
	ret.rich_color = col
	return ret
static func make_special(txt, col, ttip = ""):
	var ret = make(txt, ttip)
	ret.rich_color = APColors.special_to_rich_color(col, ret.rich_color)
	return ret
static func make_custom(txt, col, ttip = ""):
	var ret = make(txt, ttip)
	ret.color_override = str(col)
	return ret
static func make_col(txt, col, ttip = ""):
	if col == null:
		return make(txt, ttip)
	if col.rich != null:
		return make_rich(txt, col.rich, ttip)
	if col.special != null:
		return make_special(txt, col.special, ttip)
	return make_custom(txt, col.plain, ttip)
func set_color(col):
	color_override = ""
	if col.rich:
		rich_color = col.rich
	elif col.special:
		rich_color = APColors.special_to_rich_color(col.special)
	else:
		color_override = str(col.plain)

var __theme_changing = false
func _notification(what):
	if what == NOTIFICATION_THEME_CHANGED and not __theme_changing:
		__theme_changing = true
		remove_font_override("font")
		var clf = get_console_label_fonts()
		if clf and (bold or italic):
			add_font_override("font", clf.get_font(bold, italic))
		refresh_color()
		refresh_size()
		__theme_changing = false

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [BUTTON_LEFT,BUTTON_RIGHT]:
			emit_signal("clicked", event.button_index)
			accept_event()

func centered():
	align = HALIGN_CENTER
	return self

var _parent_global_rect
func handle_sizing(parent):
	_parent_global_rect = parent.get_global_rect()
	if parent is Container:
		wrapping = false
		autowrap = false
	refresh_size()

func make_dupe():
	var dupe = duplicate()
	dupe.text = ""
	dupe.rich_color = rich_color
	dupe.bold = bold
	dupe.italic = italic
	dupe.wrapping = wrapping
	dupe._notification(NOTIFICATION_THEME_CHANGED)
	return dupe

