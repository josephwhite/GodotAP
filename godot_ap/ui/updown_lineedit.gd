extends LineEdit

func _gui_input(event):
	if event is InputEventKey:
		var n
		match event.scancode:
			KEY_UP:
				n = get_node_or_null(focus_neighbour_top) as Control
			KEY_DOWN:
				n = get_node_or_null(focus_neighbour_bottom) as Control
		if n:
			accept_event()
			if event.pressed and not event.is_echo():
				release_focus()
				n.grab_focus()
				if n is LineEdit:
					n.caret_column = len(n.text)
			return
	return
