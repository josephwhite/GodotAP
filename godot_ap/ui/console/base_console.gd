class_name BaseConsole extends Control

export(NodePath) var scroll_cont
export(NodePath) var parts_cont
export var spacing = 0 setget set_spacing, get_spacing
func set_spacing(val):
	spacing = val
	if not is_inside_tree():
		return
	var pc = parts_cont
	if pc is NodePath:
		pc = get_node(pc)
	if pc:
		pc.add_constant_override("separation", spacing)
func get_spacing():
	var pc = parts_cont
	if pc is NodePath:
		pc = get_node(pc)
	if not pc:
		return spacing
	return pc.get_constant("separation")
export var scroll_to_bottom_on_new_message = false

func pop_dropdown(target):
	var popup = PopupPanel.new()
	popup.rect_min_size = Vector2.ZERO
	popup.exclusive = true
	popup.visible = false
	popup.connect("focus_exited", popup, "queue_free")
	popup.connect("popup_hide", popup, "queue_free")
	var vbox = VBoxContainer.new()
	var _pd_target = target
	var _pd_popup = popup
	var _pd_vbox = vbox
	_pd_target.resized.connect(self, "_resize_popup", [_pd_target, _pd_popup, _pd_vbox])
	popup.add_child(vbox)
	popup.connect("ready", self, "_resize_popup", [_pd_target, _pd_popup, _pd_vbox])
	popup.connect("tree_exiting", self, "_on_popup_tree_exiting", [_pd_target, _pd_popup, _pd_vbox])
	call_deferred("add_child", popup)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	return vbox

func add(part):
	if not part: return
	part.connect("tree_entered", self, "_on_new_message", [part])
	var pc = parts_cont
	if pc is NodePath:
		pc = get_node(pc)
	if pc:
		pc.add_child(part)
	update()
	return part

static func _get_ap():
	return Util._get_ap()

static func make_text(text, ttip = "", col = null):
	if col == null: col = APColors.ComplexColor.NIL
	return ConsoleLabel.make_col(text, col, ttip)

static func make_c_text(text, ttip = "", col = null):
	var part = make_text(text, ttip, col)
	part.align = HALIGN_CENTER
	return part

static func make_spacing(space):
	var part = Control.new()
	part.rect_min_size = space
	return part

func get_line_height():
	var fonts = []
	var clf = ConsoleLabel.get_console_label_fonts()
	if clf:
		fonts.append(clf.base_font)
		fonts.append(clf.bold_font)
		fonts.append(clf.italic_font)
		fonts.append(clf.bold_italic_font)
	var h = 0.0
	for f in fonts:
		h = max(h,f.get_height())
	return h
func make_header_spacing(vspace = -0.5):
	if vspace < 0:
		vspace = get_line_height() * abs(vspace)
	return make_spacing(Vector2(0,vspace))
func add_header_spacing(vspace = -0.5):
	return add(make_header_spacing(vspace))

static func make_indent(indent):
	var part = MarginContainer.new()
	part.add_constant_override("margin_left", indent)
	part.add_constant_override("margin_right", 0)
	part.add_constant_override("margin_top", 0)
	part.add_constant_override("margin_bottom", 0)
	return part

static func make_indented_block(s, indent):
	var root = VBoxContainer.new()
	root.theme_type_variation = "Console_VBox"
	var container
	var spl = s.split("\n")
	var indent_depth = -1
	for line in spl:
		var sz = line.length()
		line = line.lstrip("\t")
		sz -= line.length()
		if sz != indent_depth:
			container = VBoxContainer.new()
			var margin = MarginContainer.new()
			margin.add_child(container)
			margin.add_constant_override("margin_left", ceil(indent * sz))
			margin.add_constant_override("margin_top", 0)
			margin.add_constant_override("margin_right", 0)
			margin.add_constant_override("margin_bottom", 0)
			indent_depth = sz
			root.add_child(margin)

		container.add_child(make_text(line, ""))
	return root

static func make_location(id, data):
	return make_text(data.get_loc_name(id), "", APColors.ComplexColor.as_special(APColors.SpecialColor.LOCATION))
static func make_item(id, flags, data):
	var ttip = "Type: %s" % _get_ap().get_item_classification(flags)
	var color = APColors.ComplexColor.as_special(_get_ap().get_item_class_color(flags))
	return make_text(data.get_item_name(id), ttip, color)

static func make_player(id):
	var player = _get_ap().conn.get_player(id)
	var ttip = "Game: %s" % _get_ap().conn.get_slot(id).game
	if not player.alias.empty():
		ttip += "\nSlot: %s" % player.name
	var color = (APColors.SpecialColor.OWN_PLAYER if id == _get_ap().conn.player_id else
		APColors.SpecialColor.ANY_PLAYER)
	return make_text(player.name, ttip, APColors.ComplexColor.as_special(color))

static func make_foldable(text, ttip = "", color = null):
	if color == null: color = APColors.ComplexColor.NIL
	return ConsoleFoldableContainer.make(text, ttip, color)

var is_max_scroll = false

func _ready():
	set_spacing(spacing)
	if Engine.is_editor_hint():
		add(make_text("Test Font\n"))
		add(make_text("Bold Font\n")).bold = true
		add(make_text("Italic Font\n")).italic = true
		var v = add(make_text("BoldItalic Font\n"))
		v.bold = true
		v.italic = true
		return

func _on_new_message(_node):
	if scroll_to_bottom_on_new_message:
		scroll_bottom()

func _notification(what):
	match what:
		NOTIFICATION_THEME_CHANGED:
			update()
			var clf = ConsoleLabel.get_console_label_fonts()
			if not clf:
				ConsoleLabel.set_console_label_fonts(FontStorage.new(get_font("font", "ConsoleLabel")))
			else:
				clf.populate(get_font("font", "ConsoleLabel"))
func _get_mouse_pos():
	return get_viewport().get_mouse_position() - rect_global_position + Util.MOUSE_OFFSET

func scroll_bottom():
	var sc = scroll_cont
	if sc is NodePath:
		sc = get_node(sc)
	if not sc: return
	var bar = sc.get_v_scrollbar()
	bar.value = bar.max_value
func scroll_top():
	var sc = scroll_cont
	if sc is NodePath:
		sc = get_node(sc)
	if sc:
		sc.scroll_vertical = 0
func scroll_by_abs(amnt):
	var sc = scroll_cont
	if sc is NodePath:
		sc = get_node(sc)
	if sc:
		sc.scroll_vertical += round(amnt)
func _gui_input(event):
	if Engine.is_editor_hint(): return
	if event is InputEventKey:
		if event.pressed:
			match event.scancode:
				KEY_HOME:
					scroll_top()
				KEY_END:
					scroll_bottom()
				KEY_UP:
					scroll_by_abs(-get_line_height())
				KEY_DOWN:
					scroll_by_abs(get_line_height())
				KEY_PAGEUP:
					scroll_by_abs(-rect_size.y)
				KEY_PAGEDOWN:
					scroll_by_abs(rect_size.y)
				_:
					return
			accept_event()

func queue_locked_redraw():
	is_max_scroll = false
	update()

func _resize_popup(target, popup, vbox):
	var hb = target.get_rect()
	popup.rect_size.x = round(hb.size.x)
	popup.rect_size.y = ceil(vbox.rect_size.y)
	var vbwid = ceil(vbox.rect_size.x)
	var diff = 0
	if popup.rect_size.x < vbwid:
		diff = vbwid - popup.rect_size.x
		popup.rect_size.x = vbwid
	popup.rect_position.x = round(rect_global_position.x + hb.position.x)
	popup.rect_position.y = round(rect_global_position.y + hb.position.y + hb.size.y)
	if diff:
		if popup.rect_position.x > get_tree().get_root().size.x / 2.0:
			popup.rect_position.x = max(0, popup.rect_position.x - diff)
		if popup.rect_position.x + popup.rect_size.x > get_tree().get_root().size.x:
			var diff2 = (popup.rect_position.x + popup.rect_size.x) - get_tree().get_root().size.x
			popup.rect_position.x = max(0, popup.rect_position.x - diff2)
	if not popup.visible: popup.visible = true
func _on_popup_tree_exiting(target, _popup, _vbox):
	if target.resized.is_connected(self, "_resize_popup"):
		target.resized.disconnect(self, "_resize_popup")
func close():
	if Engine.is_editor_hint(): return
	var p = self
	while p and not p is ConsoleWindowContainer:
		p = p.get_parent()
	if p:
		p.close()

func clear():
	var pc = parts_cont
	if pc is NodePath:
		pc = get_node(pc)
	if pc:
		for part in pc.get_children():
			part.queue_free()
	update()

func printjson_command(json):
	var s = ""
	var output_data = false
	var pre_space = false
	var post_space = false
	var flowbox = ConsoleHFlow.new()
	match json.get("type"):
		"Chat":
			var msg = json.get("message","")
			var name_part = _get_ap().conn.get_player(json["slot"]).output()
			name_part.text += ": "
			var name_str = name_part.text
			flowbox.add_text_split(name_part)
			if not msg.empty():
				var lbl = make_text(msg)
				flowbox.add_text_split(lbl)
				s += name_str + msg
		"CommandResult", "AdminCommandResult", "Goal", "Release", "Collect", "Tutorial":
			pre_space = true
			post_space = true
			output_data = true
		"Countdown":
			if int(json["countdown"]) == 0:
				post_space = true
			output_data = true
		"ItemSend", "ItemCheat":
			if not _get_ap().AP_HIDE_NONLOCAL_ITEMSENDS:
				output_data = true
			elif int(json["receiving"]) == _get_ap().conn.player_id:
				output_data = true
			else:
				var ni = NetworkItem.from(json["item"], true)
				if ni.src_player_id == _get_ap().conn.player_id:
					output_data = true
		"Hint":
			if int(json["receiving"]) == _get_ap().conn.player_id:
				output_data = true
			else:
				var ni = NetworkItem.from(json["item"], true)
				if ni.src_player_id == _get_ap().conn.player_id:
					output_data = true
		"Join", "Part":
			var data = json["data"]
			var elem = data.pop_front()
			var plyr = _get_ap().conn.get_player(json["slot"])
			var spl = (elem["text"] as String).split(plyr.get_name(), true, 1)
			if spl.size() == 2:
				elem["text"] = spl[0]
				s += printjson_out([elem], flowbox)
				var plyr_lbl = plyr.output()
				flowbox.add_text_split(plyr_lbl)
				s += plyr_lbl.text
				elem["text"] = spl[1]
				s += printjson_out([elem], flowbox)
				s += printjson_out(data, flowbox)
			else: output_data = true
		_:
			output_data = true
	if flowbox.get_child_count() > 0:
		add(flowbox)
		flowbox = null
	if pre_space and output_data:
		add_header_spacing()
	if output_data:
		if not flowbox: flowbox = ConsoleHFlow.new()
		s += printjson_out(json["data"], flowbox)
		add(flowbox)
	if post_space and output_data:
		add_header_spacing()
	return s


func printjson_out(elems, flowbox):
	var s = ""
	for elem in elems:
		var txt = elem["text"]
		if txt.empty():
			continue
		var part
		match elem.get("type", "text"):
			"hint_status":
				var stat = int(elem["hint_status"])
				var stat_name = NetworkHint.status_names.get(stat, "(unknown)")
				var color = NetworkHint._get_status_colors().get(stat, APColors.RichColor.RED)

				part = make_text(txt, stat_name, APColors.ComplexColor.as_rich(color))
			"player_name":
				part = make_text(txt, "Arbitrary Player Name", APColors.ComplexColor.as_special(APColors.SpecialColor.ANY_PLAYER))
			"item_name":
				part = make_text(txt, "Arbitrary Item Name", APColors.ComplexColor.as_special(APColors.SpecialColor.ITEM))
			"location_name":
				part = make_text(txt, "Arbitrary Location Name", APColors.ComplexColor.as_special(APColors.SpecialColor.LOCATION))
			"entrance_name":
				part = make_text(txt, "Arbitrary Entrance Name", APColors.ComplexColor.as_special(APColors.SpecialColor.LOCATION))
			"player_id":
				var plyr_id = int(txt)
				part = _get_ap().conn.get_player(plyr_id).output()
			"item_id":
				var item_id = int(txt)
				var plyr_id = int(elem["player"])
				var data = _get_ap().conn.get_gamedata_for_player(plyr_id)
				var flags = int(elem["flags"])
				part = make_item(item_id, flags, data)
			"location_id":
				var loc_id = int(txt)
				var plyr_id = int(elem["player"])
				var data = _get_ap().conn.get_gamedata_for_player(plyr_id)
				part = make_location(loc_id, data)
			"text":
				part = make_text(txt)
			"color":
				part = make_text(txt)
				var col_str = elem["color"]
				if col_str.ends_with("_bg"): # no handling for bg colors, just convert to fg
					col_str = col_str.substr(0,col_str.length()-3)
				match col_str:
					"bold":
						part.bold = true
					"underline":
						pass #part.underline = true
					_:
						part.color = APColors.color_from_name(part, col_str, part.color)
		s += part.text
		flowbox.add_text_split(part)
	return s

static func printjson_out_str(elems):
	var s = ""
	for elem in elems:
		var txt = elem["text"]
		if txt.empty():
			continue
		match elem.get("type", "text"):
			"player_id":
				var plyr_id = int(txt)
				txt = _get_ap().conn.get_player(plyr_id).output().text
			"item_id":
				var item_id = int(txt)
				var plyr_id = int(elem["player"])
				var data = _get_ap().conn.get_gamedata_for_player(plyr_id)
				var flags = int(elem["flags"])
				txt = make_item(item_id, flags, data).text
			"location_id":
				var loc_id = int(txt)
				var plyr_id = int(elem["player"])
				var data = _get_ap().conn.get_gamedata_for_player(plyr_id)
				txt = make_location(loc_id, data).text
		s += txt
	return s

static func printjson_str(elems):
	var s = ""
	for elem in elems:
		var txt = elem["text"]
		s += txt
	return s

