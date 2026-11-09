extends "res://addons/gut/test.gd"
## Tests for BaseConsole PrintJSON rendering and console label color handling.

var _ap


func before_each():
	_ap = Engine.get_main_loop().get_root().get_node("Archipelago")


func after_each():
	_ap.conn = null


## Connection with one resolvable player named Alice.
func _setup_conn():
	var conn = ConnectionInfo.new()
	conn.player_id = 1
	var slot = NetworkSlot.new()
	slot.name = "Alice"
	slot.game = "Test"
	conn.slots = [slot]
	var plyr = NetworkPlayer.new()
	plyr.name = "Alice"
	plyr.slot = 1
	conn.players = [plyr]
	_ap.conn = conn
	return conn


## Unknown PrintJSON element types should render as plain text.
func test_printjson_out_unknown_type_falls_back_to_text():
	_setup_conn()
	var console = autofree(BaseConsole.new())
	var box = ConsoleHFlow.new()
	var s = console.printjson_out([{"type": "future_type", "text": "hello"}], box)
	assert_eq(s, "hello")
	assert_eq(box.get_child_count(), 1)
	box.free()


## Join/Part rewriting must not mutate the packet seen by `printjson` subscribers.
func test_printjson_command_does_not_mutate_join_packet():
	_setup_conn()
	var console = autofree(BaseConsole.new())
	console.parts_cont = NodePath(".")
	var data = [{"type": "text", "text": "Alice joined"}]
	var packet = {"type": "Join", "slot": 1, "data": data}
	console.printjson_command(packet)
	assert_eq(data.size(), 1)
	if data.size() > 0:
		assert_eq(data[0]["text"], "Alice joined")
	assert_eq(packet["data"].size(), 1)


## The 3.6 port maps `APColors.ComplexColor.NIL` to null; `set_color(null)` must reset.
func test_console_label_set_color_null_resets():
	var lbl = autofree(ConsoleLabel.make("hi"))
	lbl.rich_color = APColors.RichColor.RED
	lbl.set_color(null)
	assert_eq(lbl.color_override, "")
	assert_eq(lbl.rich_color, APColors.RichColor.NIL)


## Foldable containers default their color to `ComplexColor.NIL`.
func test_foldable_container_make_default_color():
	var folder = autofree(ConsoleFoldableContainer.make("Title"))
	assert_eq(folder.label.text, "Title")


## `max_parts` queues the oldest parts once the limit is exceeded.
func test_max_parts_queues_oldest():
	var console = autofree(BaseConsole.new())
	console.parts_cont = NodePath(".")
	console.max_parts = 2
	console.add(ConsoleLabel.make("one"))
	console.add(ConsoleLabel.make("two"))
	console.add(ConsoleLabel.make("three"))
	assert_eq(console.get_child_count(), 3)
	assert_true(console.get_child(0).is_queued_for_deletion())
	assert_false(console.get_child(1).is_queued_for_deletion())
	assert_false(console.get_child(2).is_queued_for_deletion())


## `max_parts = 0` disables the limit.
func test_max_parts_zero_disables_limit():
	var console = autofree(BaseConsole.new())
	console.parts_cont = NodePath(".")
	console.max_parts = 0
	console.add(ConsoleLabel.make("one"))
	console.add(ConsoleLabel.make("two"))
	console.add(ConsoleLabel.make("three"))
	assert_eq(console.get_child_count(), 3)
	assert_false(console.get_child(0).is_queued_for_deletion())
