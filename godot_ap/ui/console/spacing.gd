class_name Spacing extends Control

var parent
var hspace

func _init(_parent, _hspace):
	parent = _parent
	hspace = _hspace

func _ready():
	get_viewport().connect("size_changed", self, "_on_window_size_changed")
	parent.connect("resized", self, "_on_window_size_changed")

func _on_window_size_changed():
	if rect_position.x == 0.0 or rect_position.x + hspace >= get_parent().rect_size.x:
		rect_min_size.x = 0.0
	else:
		rect_min_size.x = hspace
