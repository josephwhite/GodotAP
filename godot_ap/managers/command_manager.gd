class_name CommandManager extends Node

signal debug_toggled(disabled)

var _commands = []
var _commands_by_name = {}
var debug_hidden = true setget set_debug_hidden

func set_debug_hidden(val):
	if not OS.is_debug_build(): return
	if debug_hidden == val: return
	debug_hidden = val
	emit_signal("debug_toggled")

var default_targets = []
var default_methods = []

var console = null

func reset():
	_commands.clear()
	_commands_by_name.clear()
	debug_hidden = true
	default_targets.clear()
	default_methods.clear()

func debug_disabled():
	return debug_hidden

func autofill(msg, capacity = 5):
	if msg.empty(): return []
	var split_msg = msg.split(" ",true,1)
	var cmd = _commands_by_name.get(split_msg[0])
	var ret = []
	if cmd and not cmd.is_disabled() and cmd.autofill_proc:
		ret = cmd.autofill_proc.call_func(msg)
	elif split_msg.size() < 2:
		for iter_cmd in _commands:
			if iter_cmd.is_disabled(): continue
			if debug_hidden and iter_cmd.is_debug(): continue
			if iter_cmd.text.begins_with(msg.to_lower()):
				ret.append(iter_cmd.text+" ")
	if capacity > 0 and ret.size() > capacity:
		ret.resize(capacity)
	return ret

func register_command(cmd):
	cmd.text = cmd.text.to_lower() # Enforce all-lower for insensitive comparisons
	_commands.append(cmd)
	_commands_by_name[cmd.text] = cmd
	if cmd.is_debug() and debug_hidden and not cmd.text == "/debug":
		cmd.add_disable(self, "debug_disabled")
func register_default(target, method):
	default_targets.append(target)
	default_methods.append(method)

func call_cmd(msg):
	if msg.empty(): return
	var cmd = get_command(msg.split(" ", true, 1)[0])
	if cmd and cmd.call_target:
		if cmd.is_disabled():
			console.add(BaseConsole.make_text("Command '%s' is disabled!" % cmd.text, "", APColors.ComplexColor.as_special(APColors.SpecialColor.UI_MESSAGE)))
		else:
			cmd.call_target.call(cmd.call_method, self, cmd, msg)
	else:
		for i in default_targets.size():
			default_targets[i].call(default_methods[i], self, msg)


func get_commands(): # don't mutate the return
	return _commands
func get_command(cmdname):
	return _commands_by_name.get(cmdname.to_lower())

static func _cmd_is_enabled(cmd):
	return not cmd.is_disabled()
static func _cmd_is_debug(cmd):
	return cmd.is_debug()
static func _is_help_visible(cmd):
	return not (cmd.is_disabled() or cmd.is_debug())
static func _is_db_help_visible(cmd):
	return not cmd.is_disabled() and cmd.is_debug()

func _cmd_help(mgr, _cmd, _msg):
	mgr.console.add_header_spacing()
	var folder = BaseConsole.make_foldable("[ COMMAND HELP ]",
		"Commands shown may vary based on various conditions, such as if you are" +
		" connected to an Archipelago server or not.", APColors.ComplexColor.as_special(APColors.SpecialColor.UI_MESSAGE))
	mgr.console.add(folder)
	folder.add(mgr.console.make_header_spacing())
	for cmd in mgr.get_commands().filter(self, "_is_help_visible"):
		cmd.output_helptext(mgr.console, folder)
	mgr.console.add_header_spacing()
	folder.fold(false)
func _cmd_cls(mgr, _cmd, _msg):
	mgr.console.clear()
func _cmd_clr_hist(mgr, _cmd, _msg):
	mgr.console.window.typing_bar.history_clear()
func _cmd_db_help(mgr, _cmd, _msg):
	mgr.console.add_header_spacing()
	mgr.console.add(BaseConsole.make_text("Debug Help:", "", APColors.ComplexColor.as_special(APColors.SpecialColor.UI_MESSAGE)))
	for cmd in mgr.get_commands().filter(self, "_is_db_help_visible"):
		cmd.output_helptext(mgr.console)
	mgr.console.add_header_spacing()
func _cmd_debug(mgr, _cmd, _msg):
	debug_hidden = not debug_hidden
	mgr.console.add_header_spacing()
	if debug_hidden:
		mgr.console.add(BaseConsole.make_text("Debug mode disabled","",APColors.ComplexColor.as_special(APColors.SpecialColor.UI_MESSAGE)))
	else:
		mgr.console.add(BaseConsole.make_text("Debug mode enabled. Use '/db_help' for debug commands.","",APColors.ComplexColor.as_special(APColors.SpecialColor.UI_MESSAGE)))
	mgr.console.add_header_spacing()

func get_enabled_commands():
	return _commands.filter(self, "_cmd_is_enabled")

func get_debug_commands():
	return _commands.filter(self, "_cmd_is_debug")

func setup_basic_commands():
	var cmd_help = ConsoleCommand.new("/help")
	cmd_help.add_help("", "Displays all currently available commands")
	cmd_help.set_call(self, "_cmd_help")
	register_command(cmd_help)

	var cmd_cls = ConsoleCommand.new("/cls")
	cmd_cls.add_help("", "Clears the console")
	cmd_cls.set_call(self, "_cmd_cls")
	register_command(cmd_cls)

	var cmd_clr_hist = ConsoleCommand.new("/clr_hist")
	cmd_clr_hist.add_help("", "Clears the command history")
	cmd_clr_hist.set_call(self, "_cmd_clr_hist")
	register_command(cmd_clr_hist)

func setup_debug_commands():
	if not OS.is_debug_build(): return
	var cmd_db_help = ConsoleCommand.new("/db_help").debug()
	cmd_db_help.add_help("", "Displays this message")
	cmd_db_help.set_call(self, "_cmd_db_help")
	register_command(cmd_db_help)

	var cmd_debug = ConsoleCommand.new("/debug").debug()
	cmd_debug.set_call(self, "_cmd_debug")
	register_command(cmd_debug)
