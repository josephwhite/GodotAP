class_name ConsoleFoldableContainer extends VBoxContainer

var label
var body
var folded setget fold, is_folded

func is_folded():
	return not body.visible
func fold(val):
	body.visible = not val
	update()
	if label.text.ends_with(" (Show)") or label.text.ends_with(" (Hide)"):
		label.text = label.text.substr(0, label.text.length() - 7)
	label.text += " (Show)" if val else " (Hide)"

func toggle_fold():
	fold(not folded)

func _init():
	add_constant_override("separation", 4)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	label = ConsoleLabel.make("")
	add_child(label)

	body = VBoxContainer.new()
	body.theme_type_variation = "Console_VBox"
	add_child(body)
	folded = true

	label.connect("clicked", self, "toggle_fold")

func add(node):
	body.add_child(node)
	return node

static func make(text, ttip = "", color = null):
	if color == null: color = APColors.ComplexColor.NIL
	var ret = Util._ap_load("ui/console/foldable_container.gd").new()
	ret.label.set_content(text, ttip)
	ret.label.set_color(color)
	return ret
