class_name ThemeBox extends CheckBox

signal set_theme(path)
export var target_theme_path = ""

func _ready():
	connect("toggled", self, "_on_toggle")

func _on_toggle(b):
	if b:
		emit_signal("set_theme", target_theme_path)
