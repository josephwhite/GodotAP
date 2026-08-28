class_name HintsTab extends MarginContainer

static func _get_ap():
	return Util._get_ap()

export(int, 0, 20, 1) var hint_vertical_separation = 15
onready var hint_console = $Console.console

var hint_container
var headings = []

var sort_ascending = [true,true,true,true,false]
var sort_cols = [4,0,2,1,3]

const FORCE_ALL = "[Force All]"
const LOCAL_ITEMS = "[Local Items]"
const ITEMS_PROG = "[Progression]"
const ITEMS_USEFUL = "[Useful]"
const ITEMS_TRAP = "[Trap]"
const ITEMS_FILLER = "[Filler]"
var status_filters = {
	FORCE_ALL: true,
	NetworkHint.Status.FOUND: true,
}
var recv_filters = {}
var finding_filters = {}
var item_filters = {}
var loc_filters = {}

var old_status_system = false

var _sort_index_data = {}
func sort_by_dest(a, b):
	return (_get_ap().conn.get_player_name(a.item.dest_player_id).nocasecmp_to(
		_get_ap().conn.get_player_name(b.item.dest_player_id)))
func sort_by_item(a, b):
	var a_data = _get_ap().conn.get_gamedata_for_player(a.item.dest_player_id)
	var b_data = _get_ap().conn.get_gamedata_for_player(b.item.dest_player_id)
	return (a_data.get_item_name(a.item.id).nocasecmp_to(
		b_data.get_item_name(b.item.id)))
func sort_by_src(a, b):
	return (_get_ap().conn.get_player_name(a.item.src_player_id).nocasecmp_to(
		_get_ap().conn.get_player_name(b.item.src_player_id)))
func sort_by_loc(a, b):
	var a_data = _get_ap().conn.get_gamedata_for_player(a.item.src_player_id)
	var b_data = _get_ap().conn.get_gamedata_for_player(b.item.src_player_id)
	return (a_data.get_loc_name(a.item.loc_id).nocasecmp_to(
		b_data.get_loc_name(b.item.loc_id)))
func sort_by_status(a, b):
	return (a.status - b.status)
func sort_by_prev_index(a, b):
	return _sort_index_data.get(b, 99999) - _sort_index_data.get(a, 99999)

func do_sort(a, b):
	var sorters = [
		funcref(self, "sort_by_dest"),
		funcref(self, "sort_by_item"),
		funcref(self, "sort_by_src"),
		funcref(self, "sort_by_loc"),
		funcref(self, "sort_by_status")
	]
	for q in range(sort_cols.size()):
		var c = sorters[sort_cols[q]].call_func(a,b)
		if c < 0: return sort_ascending[sort_cols[q]]
		elif c > 0: return not sort_ascending[sort_cols[q]]
	return sort_by_prev_index(a,b) >= 0

func _status_filter(s):
	match s:
		NetworkHint.Status.FOUND: return true
		NetworkHint.Status.NOT_FOUND: return old_status_system
		_: return not old_status_system

func sort_click(mouse_button, index):
	if mouse_button == BUTTON_LEFT:
		if sort_cols[0] == index:
			sort_ascending[index] = not sort_ascending[index]
			headings[index].text = headings[index].text.rstrip("↓↑") + ("↑" if sort_ascending[index] else "↓")
		else:
			headings[sort_cols[0]].text = headings[sort_cols[0]].text.rstrip(" ↓↑")
			sort_cols.erase(index)
			sort_cols.push_front(index)
			sort_ascending[index] = index != 4
			headings[index].text += (" ↑" if sort_ascending[index] else " ↓")
		queue_refresh()
		return true
	elif mouse_button == BUTTON_RIGHT:
		var hc = get_node(hint_console) if hint_console is NodePath else hint_console
		var vbox = hc.pop_dropdown(headings[index]) if hc else null
		# Create action buttons
		var btnrow = HBoxContainer.new()
		var btn_checkall = Button.new()
		btn_checkall.text = "Check All"
		btn_checkall.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_checkall.connect("pressed", self, "_on_check_all_pressed", [vbox])
		var btn_uncheckall = Button.new()
		btn_uncheckall.text = "Uncheck All"
		btn_uncheckall.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_uncheckall.connect("pressed", self, "_on_uncheck_all_pressed", [vbox])
		btnrow.add_child(btn_checkall)
		btnrow.add_child(btn_uncheckall)
		vbox.add_child(btnrow)
		# Add filter options
		match index:
			0: # Receiving Player
				var arr = [LOCAL_ITEMS]
				for s in recv_filters.keys():
					if not s in arr:
						arr.append(s)
				for s in arr:
					var mname
					if s == LOCAL_ITEMS:
						mname = "_on_recv_finding_filter_changed"
					else:
						mname = "_on_recv_filter_changed"
					var hbox = GUI.make_cbox_row(s, recv_filters.get(s, true), self, mname, [s])
					vbox.add_child(hbox)
			1: # Item
				var arr = [ITEMS_FILLER,ITEMS_TRAP,ITEMS_USEFUL,ITEMS_PROG]
				for s in item_filters.keys():
					if not s in arr:
						arr.append(s)
				for s in arr:
					var hbox = GUI.make_cbox_row(s, item_filters.get(s, true), self, "_on_item_filter_changed", [s])
					vbox.add_child(hbox)
			2: # Finding Player
				var arr = [LOCAL_ITEMS]
				for s in finding_filters.keys():
					if not s in arr:
						arr.append(s)
				for s in arr:
					var mname
					if s == LOCAL_ITEMS:
						mname = "_on_finding_recv_filter_changed"
					else:
						mname = "_on_finding_filter_changed"
					var hbox = GUI.make_cbox_row(s, finding_filters.get(s, true), self, mname, [s])
					vbox.add_child(hbox)
			3: # Location
				var arr = loc_filters.keys()
				for s in arr:
					var hbox = GUI.make_cbox_row(s, loc_filters.get(s, true), self, "_on_loc_filter_changed", [s])
					vbox.add_child(hbox)
			4: # Status
				var arr = [FORCE_ALL]
				for s in Util.reversed(NetworkHint.status_names.keys()):
					if _status_filter(s):
						arr.append(s)
				for s in arr:
					var hbox = GUI.make_cbox_row(s if s is String else NetworkHint.status_names[s],
						status_filters.get(s, true),
						self, "_on_status_filter_changed", [s])
					vbox.add_child(hbox)
		return true
	return false

func reset_hints_to_empty():
	recv_filters = {
		LOCAL_ITEMS: recv_filters.get(LOCAL_ITEMS, true),
	}
	finding_filters = {
		LOCAL_ITEMS: finding_filters.get(LOCAL_ITEMS, true),
	}
	item_filters = {
		ITEMS_PROG: item_filters.get(ITEMS_PROG, true),
		ITEMS_USEFUL: item_filters.get(ITEMS_USEFUL, true),
		ITEMS_TRAP: item_filters.get(ITEMS_TRAP, true),
		ITEMS_FILLER: item_filters.get(ITEMS_FILLER, true),
	}
	loc_filters = {}
	load_hints([])
func _ready():
	if hint_console is NodePath:
		hint_console = $Console.get_node(hint_console)
	_get_ap().connect("connected", self, "_on_connected")
	_get_ap().connect("disconnected", self, "reset_hints_to_empty")
	headings.append(BaseConsole.make_c_text("Receiving Player"))
	headings.append(BaseConsole.make_c_text("Item"))
	headings.append(BaseConsole.make_c_text("Finding Player"))
	headings.append(BaseConsole.make_c_text("Location"))
	headings.append(BaseConsole.make_c_text("Status ↓"))
	for q in range(headings.size()):
		headings[q].connect("clicked", self, "sort_click", [q])
	hint_container = GridContainer.new()
	hint_container.columns = 5
	for heading in headings:
		hint_container.add_child(heading)
	var hc = get_node(hint_console) if hint_console is NodePath else hint_console
	if hc:
		hc.add(hint_container)

var _queued_refresh_hints = false
func _process(_delta):
	if _queued_refresh_hints:
		_queued_refresh_hints = false
		refresh_hints()

func queue_refresh():
	_queued_refresh_hints = true

var _stored_hints = []
func load_hints(hints):
	_stored_hints = hints.duplicate()
	refresh_hints()
func refresh_hints():
	_sort_index_data.clear()
	for q in range(_stored_hints.size()):
		_sort_index_data[_stored_hints[q]] = q
	_stored_hints.sort_custom(self, "do_sort")

	for child in hint_container.get_children():
		if not (child in headings):
			child.queue_free()
	old_status_system = true
	hint_container.add_constant_override("v_separation", hint_vertical_separation)

	for hint in _stored_hints:
		if hint.status != NetworkHint.Status.NOT_FOUND and hint.status != NetworkHint.Status.FOUND:
			old_status_system = false
		if filter_allow(hint):
			var data = _get_ap().conn.get_gamedata_for_player(hint.item.src_player_id)

			var dest = BaseConsole.make_player(hint.item.dest_player_id).centered()
			var itm = hint.item.output().centered()
			var src = BaseConsole.make_player(hint.item.src_player_id).centered()
			var loc = BaseConsole.make_location(hint.item.loc_id, data).centered()
			var status = hint.make_status().centered()
			if hint.item.dest_player_id == _get_ap().conn.player_id:
				if not (hint.status in [NetworkHint.Status.FOUND,NetworkHint.Status.NOT_FOUND]):
					status.connect("clicked", self, "_on_hint_status_clicked", [hint, status])
			hint_container.add_child(dest)
			hint_container.add_child(itm)
			hint_container.add_child(src)
			hint_container.add_child(loc)
			hint_container.add_child(status)
	var hc = get_node(hint_console) if hint_console is NodePath else hint_console
	if hc:
		hc.is_max_scroll = false
		hc.update()

func filter_allow(hint):
	var recv_name = _get_ap().conn.get_player_name(hint.item.dest_player_id, false)
	var item_name = hint.item.get_name()
	var find_name = _get_ap().conn.get_player_name(hint.item.src_player_id, false)
	var loc_name = _get_ap().conn.get_gamedata_for_player(hint.item.src_player_id).get_loc_name(hint.item.loc_id)
	#region Add filters if missing
	if not recv_filters.has(recv_name):
		recv_filters[recv_name] = true
	if not item_filters.has(item_name):
		item_filters[item_name] = true
	if not finding_filters.has(find_name):
		finding_filters[find_name] = true
	if not loc_filters.has(loc_name):
		loc_filters[loc_name] = true
	#endregion
	if not recv_filters.get(recv_name, true):
		return false
	if not item_filters.get(item_name, true):
		return false
	if not finding_filters.get(find_name, true):
		return false
	if not loc_filters.get(loc_name, true):
		return false
	if hint.is_local() and not recv_filters.get(LOCAL_ITEMS, true):
		return false
	var flags = hint.item.flags
	if Util.has_flag(flags, 0) and not item_filters.get(ITEMS_PROG, true):
		return false
	if Util.has_flag(flags, 1) and not item_filters.get(ITEMS_USEFUL, true):
		return false
	if Util.has_flag(flags, 2) and not item_filters.get(ITEMS_TRAP, true):
		return false
	if (not flags) and not item_filters.get(ITEMS_FILLER, true):
		return false
	if not status_filters.get(hint.status, true):
		if not status_filters.get(FORCE_ALL, false):
			return false
	return true

func _on_check_all_pressed(vbox):
	Util.for_all_nodes(vbox, self, "_set_checkbox_true")

func _on_uncheck_all_pressed(vbox):
	Util.for_all_nodes(vbox, self, "_set_checkbox_false")

func _set_checkbox_true(node):
	if node is CheckBox:
		node.button_pressed = true

func _set_checkbox_false(node):
	if node is CheckBox:
		node.button_pressed = false

func _on_recv_filter_changed(state, key):
	recv_filters[key] = state
	queue_refresh()

func _on_recv_finding_filter_changed(state, key):
	recv_filters[key] = state
	finding_filters[key] = state
	queue_refresh()

func _on_item_filter_changed(state, key):
	item_filters[key] = state
	queue_refresh()

func _on_finding_filter_changed(state, key):
	finding_filters[key] = state
	queue_refresh()

func _on_finding_recv_filter_changed(state, key):
	finding_filters[key] = state
	recv_filters[key] = state
	queue_refresh()

func _on_loc_filter_changed(state, key):
	loc_filters[key] = state
	queue_refresh()

func _on_status_filter_changed(state, key):
	status_filters[key] = state
	queue_refresh()

func _on_connected(conn, _j):
	conn.set_hint_notify(self, "load_hints")

func _on_hint_status_clicked(_btn, hint, status_label):
	var hc = get_node(hint_console) if hint_console is NodePath else hint_console
	var vbox = hc.pop_dropdown(status_label) if hc else null
	vbox.add_constant_override("separation", 0)
	for s in [NetworkHint.Status.AVOID, NetworkHint.Status.NON_PRIORITY, NetworkHint.Status.PRIORITY]:
		var btn = Button.new()
		btn.text = NetworkHint.status_names[s]
		btn.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
		btn.connect("pressed", self, "_on_hint_action_pressed", [hint, s, vbox])
		vbox.add_child(btn)

func _on_hint_action_pressed(hint, action_status, _vbox):
	_get_ap().conn.update_hint(hint.item.loc_id, hint.item.src_player_id, action_status)
