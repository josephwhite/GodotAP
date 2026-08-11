class_name SliderBox extends MarginContainer

static func _get_ap():
	return Util._get_ap()

export var total_slide_dur = 0.5
onready var row = $Row
onready var handle = $Row/Handle
onready var handle_label = $Row/Handle/Margin/CustomLabel
onready var box = $Row/Box
onready var connect_btn = $Row/Box/Margins/VBox/ButtonRow/ConnectBtn
onready var disconnect_btn = $Row/Box/Margins/VBox/ButtonRow/DisconnectBtn
var is_open = false setget set_is_open
func set_is_open(val):
	if is_open != val:
		is_open = val
		handle_label.text = "▶" if is_open else "◀"
var _slide_tween = null

func _ready():
	handle.connect("gui_input", self, "_button_input")
	row.add_constant_override("separation", 0)
	rect_min_size = Vector2.ZERO
	_get_ap().connect("connected", self, "_on_ap_connected")
	_get_ap().connect("disconnected", self, "_on_ap_disconnected")
	if _get_ap().AP_CONSOLE_CONNECTION_AUTO or _get_ap().AP_CONSOLE_CONNECTION_OPEN:
		set_is_open(true)
	call_deferred("_apply_initial_state")

func _apply_initial_state():
	_recalc_row_size()
	_set_open_x(0 if is_open else ceil(box.rect_size.x))

func _recalc_row_size():
	row.rect_min_size.x = handle.rect_size.x + box.rect_size.x
	row.rect_min_size.y = max(handle.rect_size.y, box.rect_size.y)

func slide_to(open):
	if open == is_open: return
	set_is_open(open)
	_slide()

func _set_open_x(x):
	add_constant_override("margin_left", x)
	add_constant_override("margin_right", -x)
	queue_sort()

func _slide():
	var x = get_constant("margin_left")
	var w = ceil(box.rect_size.x)
	var targ_x = 0 if is_open else w
	var dur = total_slide_dur * abs(x - targ_x) / w
	if _slide_tween:
		_slide_tween.stop_all()
		_slide_tween.queue_free()
	_slide_tween = Tween.new()
	add_child(_slide_tween)
	_slide_tween.interpolate_method(self, "_set_open_x", x, targ_x, dur, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	_slide_tween.start()

func _button_input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and event.is_pressed():
			slide_to(not is_open)

func _on_ap_connected(_conn, _json):
	connect_btn.disabled = true
	disconnect_btn.disabled = false
	if _get_ap().AP_CONSOLE_CONNECTION_AUTO:
		slide_to(false)

func _on_ap_disconnected():
	connect_btn.disabled = false
	disconnect_btn.disabled = true
	if _get_ap().AP_CONSOLE_CONNECTION_AUTO:
		slide_to(true)

func get_closed_width():
	return handle.rect_size.x
