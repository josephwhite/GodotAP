tool
class_name StringBar extends Control

signal clicked(index)

const HMARGIN = 6
const HPADDING = 2
const VMARGIN = 4
const VPADDING = 2

var strings = [] setget set_strings, get_strings
var _hitboxes = []
var hov_ind = -1

func set_strings(arr):
	strings = arr
	visible = strings.size() > 0
	_hitboxes.clear()
	update()
func get_strings():
	return strings

func _draw():
	var font = get_cur_font()
	var by = rect_position.y+rect_size.y
	var fh = font.get_height()
	var lh = fh + 2*(VMARGIN+VPADDING)
	var sz = Vector2(rect_size.x,strings.size() * lh)
	rect_position.y = by-sz.y
	var y = sz.y-(VMARGIN+VPADDING)-fh
	draw_rect(Rect2(Vector2.ZERO,rect_size), get_bg_color())
	_hitboxes.clear()
	for q in range(strings.size()):
		_hitboxes.append(Rect2(HMARGIN,VMARGIN+(lh*(strings.size()-q-1)),sz.x-2*HMARGIN,lh-2*VPADDING))
	for q in range(strings.size()):
		var s = strings[q]
		if q == hov_ind:
			draw_rect(Rect2(HMARGIN,y-VPADDING,sz.x-(2*HMARGIN), lh-(2*VMARGIN)), get_sel_color())
		draw_string(font, Vector2(HMARGIN+HPADDING, y+font.get_ascent()), s, get_font_color())
		y -= lh
	set_deferred("rect_size",sz)

func _gui_input(event):
	if event is InputEventMouseButton:
		if hov_ind > -1 and event.pressed and event.button_index == BUTTON_LEFT:
			emit_signal("clicked", hov_ind)

var _has_mouse = false
func _process(_delta):
	if _has_mouse:
		var pos = get_viewport().get_mouse_position() + Util.MOUSE_OFFSET - rect_global_position
		var found = false
		for q in range(_hitboxes.size()):
			if _hitboxes[q].has_point(pos):
				if hov_ind != q:
					hov_ind = q
					update()
				found = true
				break
		if not found:
			hov_ind = -1

func _notification(what):
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_has_mouse = true
		NOTIFICATION_MOUSE_EXIT:
			_has_mouse = false
			hov_ind = -1

func get_bg_color():
	return get_color("bg_color")
func get_sel_color():
	return get_color("sel_color")
func get_font_color():
	return get_color("font_color")
func get_cur_font():
	return get_font("font")
func get_font_size():
	return get("font_size/font_size")
