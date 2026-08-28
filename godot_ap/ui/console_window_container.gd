tool class_name ConsoleWindowContainer extends PanelContainer

onready var tabs = $Tabs
onready var console_tab = $Tabs/Console
onready var hints_tab = $Tabs/Hints
onready var console_container = $Tabs/Console/Console
onready var console_margin = console_container.margin
onready var console = console_container.console
onready var typing_bar = console_container.typing_bar

export var hide_console_tab = false setget set_hide_console_tab
func set_hide_console_tab(val):
	hide_console_tab = val
	refresh_hidden()
export var hide_hints_tab = false setget set_hide_hints_tab
func set_hide_hints_tab(val):
	hide_hints_tab = val
	refresh_hidden()

func recount(): ## Returns the number of visible tabs, and sets the tabbar's visibility.
	var count = 0
	for q in range(tabs.get_tab_count()):
		if not tabs.get_tab_hidden(q):
			count += 1
	tabs.tabs_visible = count > 1
	return count

func refresh_hidden():
	if Engine.is_editor_hint(): return
	if not is_node_ready(): return
	var prev = tabs.get_current_tab()
	tabs.set_tab_hidden(_get_tab_idx(tabs, console_tab), hide_console_tab)
	tabs.set_tab_hidden(_get_tab_idx(tabs, hints_tab), hide_hints_tab)
	# 3.6's set_tab_hidden always advances to the next available tab, even when
	# unhiding one, so restore the previous selection when it stays visible.
	if tabs.get_tab_hidden(prev):
		_select_next_available(prev)
	else:
		tabs.set_current_tab(prev)
	recount()

func _select_next_available(from):
	var count = tabs.get_tab_count()
	for i in range(count):
		var idx = (from + i) % count
		if not tabs.get_tab_hidden(idx) and not tabs.get_tab_disabled(idx):
			tabs.set_current_tab(idx)
			return

func _ready():
	refresh_hidden()
	var tb = console_container.get_node(typing_bar) if typing_bar is NodePath else typing_bar
	if tb:
		tb.grab_focus()
	# gui_embed_subwindows not in 3.6

	if Engine.is_editor_hint(): return

	var right_bar_ws = []
	for node in console_tab.get_children():
		var cm = console_container.get_node(console_margin) if console_margin is NodePath else console_margin
		if node == cm: continue
		_compute_bar_width(node, right_bar_ws)
		Util.for_all_nodes(node, self, "_compute_bar_width", [right_bar_ws])
	var right_bar_w = 0.0
	for w in right_bar_ws:
		if w > right_bar_w:
			right_bar_w = w
	var cm = console_container.get_node(console_margin) if console_margin is NodePath else console_margin
	cm.add_constant_override("margin_right", 8+ceil(right_bar_w / 2))

func _compute_bar_width(n, right_bar_ws):
	if n is SliderBox:
		right_bar_ws.push_back(n.get_closed_width())

static func _get_tab_idx(my_tabs, control):
	for i in range(my_tabs.get_tab_count()):
		if my_tabs.get_tab_control(i) == control:
			return i
	return -1

func close():
	queue_free()
