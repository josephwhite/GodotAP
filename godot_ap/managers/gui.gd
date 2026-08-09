class_name GUI

static func make_cbox_row(s, initial_state, target, method, binds = []):
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_CENTER)
	var cbox = CheckBox.new()
	cbox.set_pressed_no_signal(initial_state)
	cbox.connect("toggled", target, method, binds)
	cbox.add_stylebox_override("focus", StyleBoxEmpty.new())
	hbox.add_child(cbox)
	var lbl = Label.new()
	lbl.text = s
	lbl.align = HALIGN_LEFT
	hbox.add_child(lbl)
	return hbox
