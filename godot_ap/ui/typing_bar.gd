tool class_name TypingBar extends LineEdit

export var clear_text_on_send = true
export var store_history = true
export var disabled = false setget set_disabled
func set_disabled(val):
	disabled = val
	editable = not val
	if val: _unfocus()
	update()
	focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL

export(NodePath) var autofill_rect
export(NodePath) var autofill_edit

var cmd_manager = null

const VMARGIN = 6
const HMARGIN = 6
const AUTOFILL_HMARGIN = 30

func calc_height():
	return get_font("font").get_height() + (2*VMARGIN)

signal send_text(msg)

var had_focus = false
var _tab_completions = []

var _history = []
var _hist_indx = 0
func history_step(by):
	if not store_history: return
	if by == 0 or (_hist_indx >= _history.size() if by > 0 else _hist_indx <= 0):
		return
	_hist_indx = clamp(_hist_indx+by, 0, _history.size())
	if _hist_indx < _history.size():
		update_text(_history[_hist_indx])
	else:
		update_text("")
func history_add(s):
	if not store_history: return
	if _history.size() == 0 or s != _history.back():
		_history.append(s)
	_hist_indx = _history.size()
func history_clear():
	_history.clear()
	_hist_indx = 0

var _autofill_rect_node = null
var _autofill_edit_node = null
func _ready():
	var ar = get_node(autofill_rect) if autofill_rect is NodePath else autofill_rect
	var ae = get_node(autofill_edit) if autofill_edit is NodePath else autofill_edit
	_autofill_rect_node = ar
	_autofill_edit_node = ae

	if not Engine.is_editor_hint():
		connect("focus_entered", self, "_focus")
		connect("focus_exited", self, "_unfocus")
		connect("text_entered", self, "_submit_text")
		connect("text_changed", self, "_on_text_changed")
		show_bar(visible)

	rect_min_size.y = calc_height()
	rect_min_size.x = rect_size.x
	yield(get_tree(), "idle_frame")
	if ar:
		ar.rect_position = Vector2(AUTOFILL_HMARGIN, 0)
		ar.rect_size = Vector2(rect_size.x - 2*AUTOFILL_HMARGIN, 0)
		ar.connect("clicked", self, "_on_autofill_clicked")

func _gui_input(event):
	if Engine.is_editor_hint(): return
	if disabled or not visible: return
	if event is InputEventKey:
		if event.pressed:
			match event.scancode:
				KEY_TAB:
					if _tab_completions:
						update_text(_tab_completions[0])
						accept_event()
						return
				KEY_UP:
					history_step(-1)
					accept_event()
					return
				KEY_DOWN:
					history_step(1)
					accept_event()
					return
	return


func _on_text_changed(_new_text):
	update()

func update():
	.update()
	if cmd_manager:
		if had_focus:
			_tab_completions = cmd_manager.autofill(text, 10)
			if _tab_completions and _tab_completions[0] == text:
				_tab_completions.clear()
		else:
			_tab_completions.clear()
		if _autofill_rect_node:
			_autofill_rect_node.set_strings(_tab_completions)

		if _tab_completions and _autofill_edit_node:
			_autofill_edit_node.text = _tab_completions[0]
		elif _autofill_edit_node:
			_autofill_edit_node.text = ""

func _focus():
	if Engine.is_editor_hint(): return
	if disabled or not visible: return _unfocus()
	if not had_focus:
		had_focus = true
		update()
		update()
func _unfocus():
	if Engine.is_editor_hint(): return
	if had_focus:
		had_focus = false
		update()
		update()

func show_bar(state):
	visible = state
	focus_mode = Control.FOCUS_ALL if state else Control.FOCUS_NONE

func _submit_text(submitted_text):
	history_add(submitted_text)
	emit_signal("send_text", submitted_text)
	if clear_text_on_send:
		update_text("")

func _on_autofill_clicked(indx):
	update_text(_tab_completions[indx])

func update_text(new_text):
	text = new_text
	caret_position = text.length()
	update()
