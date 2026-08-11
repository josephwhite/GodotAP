class_name APSaveManager extends Node

static func _get_ap():
	return Util._get_ap()

export var SAVE_HEADER = "GodotAP_Save_File"
var open_save
var open_save_ind = -1

func make_save_file(): ## Override to return a subclass of SaveFile
	return SaveFile.new()

func _init():
	open_save = make_save_file()
	Util._make_dir_recursive("user://saves/")

func _ready():
	if OS.is_debug_build(): # Debug commands for forcibly saving/loading via console
		var cmd_save = ConsoleCommand.new("/save").debug()
		cmd_save.add_help("[num]", "Saves the save file, optionally to a different-numbered slot. num >= 0.")
		cmd_save.set_call(self, "_cmd_save")
		_get_ap().cmd_manager.register_command(cmd_save)

		var cmd_delsave = ConsoleCommand.new("/delsave").debug()
		cmd_delsave.add_help("num", "Deletes the specified save file. num >= 0.")
		cmd_delsave.set_call(self, "_cmd_delsave")
		_get_ap().cmd_manager.register_command(cmd_delsave)

		var cmd_loadsave = ConsoleCommand.new("/loadsave").debug()
		cmd_loadsave.add_help("num", "Loads the specified save file. num >= 0.")
		cmd_loadsave.set_call(self, "_cmd_loadsave")
		_get_ap().cmd_manager.register_command(cmd_loadsave)

func save():
	write_save(open_save_ind)

func read_save(ind):
	if ind < 0: return false
	var file = Util._file_open("user://saves/%d.dat" % ind, File.READ)
	if not file or file.get_pascal_string() != SAVE_HEADER:
		var f2 = Util._file_open("user://saves/%d.dat" % ind, File.WRITE)
		if not f2: return false
		f2.close()
		open_save.clear()
	else:
		if not open_save.read(file):
			open_save.clear()
		file.close()
	open_save_ind = ind
	_get_ap().creds.update(
		open_save.creds.ip, open_save.creds.port,
		open_save.creds.slot, open_save.creds.pwd)
	_get_ap().aplock = open_save.aplock
	return true

func write_save(ind):
	if ind < 0: return false
	var file = Util._file_open("user://saves/%d.dat" % ind, File.WRITE)
	file.store_pascal_string(SAVE_HEADER)
	open_save.write(file)
	file.close()
	return true

func delete_save(ind):
	Directory.new().remove("user://saves/%d.dat" % ind)

func _cmd_save(mgr, cmd, msg):
	var command_args = msg.split(" ", true, 2)
	if command_args.size() == 1:
		save()
	elif command_args.size() != 2 or not command_args[1].is_valid_int() or int(command_args[1]) < 0:
		cmd.output_usage(mgr.console)
	else:
		write_save(int(command_args[1]))
func _cmd_delsave(mgr, cmd, msg):
	var command_args = msg.split(" ", true, 2)
	if command_args.size() != 2 or not command_args[1].is_valid_int() or int(command_args[1]) < 0:
		cmd.output_usage(mgr.console)
	else:
		delete_save(int(command_args[1]))
func _cmd_loadsave(mgr, cmd, msg):
	var command_args = msg.split(" ", true, 2)
	if command_args.size() != 2 or not command_args[1].is_valid_int() or int(command_args[1]) < 0:
		cmd.output_usage(mgr.console)
	else:
		var is_conn = _get_ap().status != 0
		if is_conn:
			_get_ap().ap_disconnect()
			while _get_ap().status != 0:
				yield(_get_ap(), "status_updated")
		read_save(int(command_args[1]))
		if is_conn:
			_get_ap().ap_reconnect_to_save()
