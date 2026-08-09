class_name CustomLabel extends Panel

export var text = "" setget set_text
func set_text(val):
	if val != text:
		text = val
		update()
export(Resource) var font
export var font_size = 16
export var pos = Vector2(0.0, 0.0)

func _draw():
	draw_string(font, pos, text, get_color("font_color", "Label"))
