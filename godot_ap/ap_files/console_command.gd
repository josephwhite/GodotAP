class_name ConsoleCommand
## Information about a console command.

## How deep the indentation is for help text display on the console.
const HELPTEXT_INDENT = 20


## Contains the help text for the usage of a command.
class CmdHelpText:
	## The arguments the command takes, to be displayed to the user.
	var args: String = ""
	## A description of the command and the uses of the variables.
	var text: String = ""
	var cond_target
	var cond_method


var text: String = ""
var help_text = []
var call_target = null
var call_method = ""
var autofill_proc = null
var disabled_targets = []
var disabled_methods = []
var _debug: bool = false


#region Constructor and builder-pattern funcs
func _init(txt):
	text = txt


func set_call(target, method):
	call_target = target
	call_method = method
	return self


func set_autofill(caller):
	autofill_proc = caller
	return self


func add_help(args, helptxt):
	var ht = CmdHelpText.new()
	ht.args = args
	ht.text = helptxt
	help_text.append(ht)
	return self


func add_help_cond(args, helptxt, cond_target, cond_method):
	add_help(args, helptxt)
	help_text.back().cond_target = cond_target
	help_text.back().cond_method = cond_method
	return self


func add_disable(target, method):
	disabled_targets.append(target)
	disabled_methods.append(method)
	return self


## Enable or disable debug-only status for this command.
func debug(state = true):
	_debug = state
	return self


#endregion


## Returns [code]true[/code] if the command is debug-only.
func is_debug():
	return _debug


func _is_cond_enabled(ht):
	if ht.cond_target == null:
		return true
	return not ht.cond_target.call(ht.cond_method)


## Get all the help text for this command.
func get_helptext():
	var s = ""
	for ht in help_text:
		if _is_cond_enabled(ht):
			s += "%s %s\n    %s\n" % [text, ht.args, ht.text.replace("\n", "\n    ")]
	return s


func output_helptext(console, target = null):
	var texts = []
	for ht in help_text:
		if _is_cond_enabled(ht):
			texts.append(ht)
	if not target:
		for ht in texts:
			console.add(
				BaseConsole.make_text(
					"%s %s" % [text, ht.args],
					"",
					APColors.ComplexColor.as_special(APColors.SpecialColor.UI_MESSAGE)
				)
			)
			var indent = BaseConsole.make_indent(HELPTEXT_INDENT)
			console.add(indent)
			indent.add_child(
				BaseConsole.make_text(
					ht.text, "", APColors.ComplexColor.as_special(APColors.SpecialColor.UI_MESSAGE)
				)
			)
	elif target is ConsoleFoldableContainer:
		for ht in texts:
			target.add(
				BaseConsole.make_text(
					"%s %s" % [text, ht.args],
					"",
					APColors.ComplexColor.as_special(APColors.SpecialColor.UI_MESSAGE)
				)
			)
			target.add(console.make_header_spacing(0))
			var indent = BaseConsole.make_indent(HELPTEXT_INDENT)
			target.add(indent)
			var vbox = VBoxContainer.new()
			indent.add_child(vbox)
			vbox.add_child(
				BaseConsole.make_text(
					ht.text, "", APColors.ComplexColor.as_special(APColors.SpecialColor.UI_MESSAGE)
				)
			)
			vbox.add_child(console.make_header_spacing(0))

	elif target is Container:
		for ht in texts:
			target.add_child(
				BaseConsole.make_text(
					"%s %s" % [text, ht.args],
					"",
					APColors.ComplexColor.as_special(APColors.SpecialColor.UI_MESSAGE)
				)
			)
			target.add_child(console.make_header_spacing(0))
			target.add_child(BaseConsole.make_indent(HELPTEXT_INDENT))
			target.add_child(
				BaseConsole.make_text(
					ht.text, "", APColors.ComplexColor.as_special(APColors.SpecialColor.UI_MESSAGE)
				)
			)
			target.add_child(console.make_header_spacing(0))
			target.add_child(BaseConsole.make_indent(-HELPTEXT_INDENT))


func output_usage(console):
	console.add(
		BaseConsole.make_text(
			"Usage:\n%s" % get_helptext(),
			"",
			APColors.ComplexColor.as_special(APColors.SpecialColor.UI_MESSAGE)
		)
	)


func is_disabled():
	for i in range(disabled_targets.size()):
		if disabled_targets[i].call(disabled_methods[i]):
			return true
	return false


func _to_string():
	var s = "COMMAND(" + text
	if is_disabled():
		s += ",dis"
	if is_debug():
		s += ",db"
	return s + ")"
