## The main Archipelago interface class.
##
## Access non-static members via the `Archipelago` autoload,
## which should be loaded as `godot_ap/autoloads/archipelago.tscn`.
class_name AP extends Node

## The game name to connect to. Empty string for `TextOnly` / `Tracker`/ `HintGame` clients.
export var AP_GAME_NAME = ""
## The tags for your game.
export var AP_GAME_TAGS = []
## The version of your client. Arbitrary number for you to manage.
var AP_CLIENT_VERSION
## The target AP version. Not arbitrary - used in `Connect` packet.
var AP_VERSION
## The ItemHandling to use when connecting.
export var AP_ITEM_HANDLING = 0
## Aliases for Traps in TrapLink. When the key is received, the value will be used instead.
export var TRAP_LINK_ALIASES = {}
## Prints what items have been previously collected when reconnecting to a slot.
export var AP_PRINT_ITEMS_ON_CONNECT = false
## Hide item send messages that don't involve the client.
export var AP_HIDE_NONLOCAL_ITEMSENDS = true
## Automatically opens a default AP text console.
export var AP_AUTO_OPEN_CONSOLE = false
## Show items that are both progression and useful with their own color
export var AP_ENABLE_PROGUSEFUL = false

## Automatically open the Connection box when the console opens
export var AP_CONSOLE_CONNECTION_OPEN = false
## Automatically open/close the Connection box based on connected status
export var AP_CONSOLE_CONNECTION_AUTO = true

## Enables additional logging.
export var AP_LOG_COMMUNICATION = false
## Enables additional logging.
export var AP_LOG_RECIEVED = false
## If true, datapackage local files will be stringified in a readable mode.
export var READABLE_DATAPACK_FILES = true
## Which fields should be saved from received DataPacks.
export var datapack_cached_fields = ["item_name_to_id","location_name_to_id","checksum"]
## Size, in MB, of the websocket inbound buffer. Raising may help if large datapackages are causing disconnections.
export(int, 5, 500, 1) var websocket_inbuffer_mb = 50

onready var hang_clock = $HangTimer

## The base directory of this GodotAP install. Computed at runtime from this
## script's location, so the module can be loaded from anywhere (e.g. inside a
## mod's unpacked folder).
var _ap_base_dir = "res://godot_ap"
func get_ap_base_dir():
	return _ap_base_dir

#region Connection packets
# See `ConnectionInfo` (Archipelago.conn) for more signals
## Emitted before connection is attempted
signal preconnect
## Emitted when `RoomInfo` is received
signal roominfo(conn, json)
## Emitted when `ConnectionRefused` is received
signal connectionrefused(conn, json)
## Emitted when `Connected` is received
signal connected(conn, json)
## Emitted when `PrintJSON` is received
signal printjson(json, plaintext)
## Emitted when the connection is lost
signal disconnected
#endregion
#region Other signals
## Signals when 'status' changes
signal status_updated
## Signals when all required datapacks have finished loading
signal all_datapacks_loaded
## Emitted when a location should be cleared/deleted from the world, as it has been "already collected"
signal remove_location(loc_id)
## Emitted when the connection tags are updated
signal on_tag_change
## Emitted when an output console is attached
signal on_attach_console

# Debug purposes
signal _logged_message(msg)
#endregion


## The Archipelago item handling values.
enum ItemHandling {
	NONE = 0, ## Don't receive any items from the server.
	OTHER = 1, ## Receive your items in other worlds from the server.
	OWN_AND_OTHER = 3, ## Receive your items from your world and other worlds from the server.
	STARTING_AND_OTHER = 5, ## Receive your items from your starting inventory and other worlds from the server.
	ALL = 7, ## Receive your items from your starting inventory, your world, and other worlds from the server.
}

## Timestamp of the last sent DeathLink packet. Automatically updated by 'ConnectionInfo.send_deathlink'.
var last_sent_deathlink_time
## Timestamp of the last sent TrapLink packet. Automatically updated by 'ConnectionInfo.send_traplink'.
var last_sent_traplink_time

## The group that is used for DeathLink for this connection
var deathlink_group setget set_deathlink_group, get_deathlink_group

## The current connection credentials to be used
var creds = null
## The current APLock object. A default lock object is `unlocked`.
## If an `unlocked` object is set here, it will be `locked` when you connect to a slot.
## If a `locked` object is set here, it will disallow you from connecting to any slot different from the one it locked to.
## Saving an APLock object in a save file allows you to lock it to a particular room.
## `save_manager` can handle the lock for you, along with handling local save files.
var aplock = null

var _socket

## A config manager, designed to handle configs not tied to a specific save file.
## Will always exist, as GodotAP's own configs are managed by this.
## Can be customized by adding a node inheriting from 'APConfigManager' to 'godot_ap/autoloads/archipelago.tscn'
var config

## A save manager, designed to handle local save files tied to a specific room/slot.
## Null unless a node inheriting from 'APSaveManager' is added to to 'godot_ap/autoloads/archipelago.tscn'
var save_manager ## Can be 'null' if not provided in 'godot_ap/autoloads/archipelago.tscn'

#region CONNECTION
var conn ## The active Archipelago connection

## Emits strings representing stages of the connection process. Useful for displaying connection progress to users.
signal connect_step(message)
## The possible connection status states.
enum APStatus {
	DISCONNECTED, ## Not connected to any Archipelago server
	SOCKET_CONNECTING, ## Socket attempting to connect
	CONNECTING, ## Socket connected, trying to connect with server
	CONNECTED, ## Connected with server, authenticating for selected slot
	PLAYING, ## Authenticated and acively playing
	DISCONNECTING, ## Attempting to disconnect from the server
}
var _queue_reconnect = false
## The current connection status.
var status = APStatus.DISCONNECTED setget _set_status
func _set_status(val):
	if status != val:
		status = val
		emit_signal("status_updated")
	if status == APStatus.DISCONNECTED:
		conn = null
		if _queue_reconnect:
			_queue_reconnect = false
			ap_reconnect()

## Returns true if there is an active Archipelago connection
func is_ap_connected():
	return status == APStatus.PLAYING
## Returns true if there is no active Archipelago connection
func is_not_connected():
	return status != APStatus.PLAYING

var _pending_connect_args = null # Temp storage for 'Connect' command args during RoomInfo handshake
var _connecting_part # Label in the 'output_console' displaying the messages from 'connect_step'

var _connect_attempts = 1 # Connection attempt counter
var _wss = true # If current connection attempt is using secure sockets. Alternates each attempt.

## Returns the URL currently being targetted for connection
func get_url():
	return "%s://%s:%s" % ["wss" if _wss else "ws",creds.ip,creds.port]

## Reconnect to Archipelago with the same information as before
func ap_reconnect():
	if status != APStatus.DISCONNECTED:
		ap_disconnect()
		_queue_reconnect = true
		return
	emit_signal("connect_step", "Connecting...")
	status = APStatus.SOCKET_CONNECTING
	_connect_attempts = 1
	_wss = true
	emit_signal("preconnect")
	var err = _socket.connect_to_url(get_url())
	if err:
		_log("Connection to '%s' failed! Retrying (%d)" % [get_url(), _connect_attempts])
		_wss = not _wss
		if _wss: _connect_attempts += 1

## Connect to Archipelago with the specified connection information
func ap_connect(room_ip, room_port, slot_name, room_pwd = ""):
	if status != APStatus.DISCONNECTED:
		ap_disconnect() # Do it here so the ip/port/slot are correct in the disconnect message
	open_logger()
	creds.update(room_ip, room_port, slot_name, room_pwd)
	ap_reconnect()

## Disconnect from Archipelago
func ap_disconnect():
	if _connecting_part:
		_connecting_part = null
	if status == APStatus.DISCONNECTED or status == APStatus.DISCONNECTING:
		return
	status = APStatus.DISCONNECTING
	emit_signal("connect_step", "Disconnecting...")
	_socket.disconnect_from_host()
	if hang_clock and hang_clock.is_inside_tree():
		hang_clock.start(hang_clock.wait_time)
	close_logger()
	if output_console:
		var part = BaseConsole.make_text("Disconnecting...","%s:%s %s" % [creds.ip,creds.port,creds.slot], APColors.ComplexColor.as_special(APColors.SpecialColor.UI_MESSAGE))
		output_console.add(part)
		while status != APStatus.DISCONNECTED:
			yield(self, "status_updated")
		part.text = "Disconnected from AP."

## Forcibly disconnect. Use 'ap_disconnect()' to disconnect normally if possible.
func force_disconnect():
	if status == APStatus.DISCONNECTED: return
	_socket.disconnect_from_host()
	_create_socket()
	status = APStatus.DISCONNECTED
	emit_signal("disconnected")

func _create_socket():
	_socket = WebSocketClient.new()
	_socket.connect("connection_established", self, "_on_ws_connected")
	_socket.connect("connection_closed", self, "_on_ws_closed")
	_socket.connect("connection_error", self, "_on_ws_error")
	_socket.connect("data_received", self, "_on_ws_data")
#endregion CONNECTION

#region MOD-LOADING SUPPORT
## Returns the Archipelago autoload node, or null if not present.
static func _get_ap():
	return Engine.get_main_loop().get_root().get_node("Archipelago")
#endregion

#region LOGGING TO FILE
## The current file being logged to.
const _ap_logging_state = {"file": null}
## Opens the GodotAP logging file, if it isn't already open
static func open_logger():
	if not _ap_logging_state.file:
		_ap_logging_state.file = Util._file_open("user://ap/ap_log.log",File.WRITE)
## Closes the GodotAP logging file, if its open
static func close_logger():
	if _ap_logging_state.file:
		_ap_logging_state.file.close()
		_ap_logging_state.file = null
# Logs a message to the GodotAP log
static func _log(s):
	if _ap_logging_state.file:
		_ap_logging_state.file.store_line(s)
		if OS.is_debug_build(): _ap_logging_state.file.flush() # Ensure logs are immediately flushed in case of crash
	var msg = "[AP] %s" % s
	print(msg)
	var _ap_signal = _get_ap()
	if _ap_signal:
		_ap_signal.emit_signal("_logged_message", msg)
## Logs a message to the GodotAP log
static func log(s):
	_log(str(s))
## Logs a warning to the GodotAP log and Godot warning console
static func warn(s):
	_log("[WARN] %s" % str(s))
	push_warning(s)
## Logs an error to the GodotAP log and Godot error console
static func error(s):
	_log("[ERROR] %s" % str(s))
	push_error(s)

## Logs a message to the GodotAP log, but only if AP_LOG_COMMUNICATION is true
func comm_log(pref, s):
	if not AP_LOG_COMMUNICATION: return
	_log("[%s] %s" % [pref,str(s)])
## Logs a message to the GodotAP log, but only in a Debug build
static func dblog(s):
	if not OS.is_debug_build(): return
	_log(s)
## Logs a warning to the GodotAP log and Godot warning console, but only in a Debug build
static func dbwarn(s):
	if not OS.is_debug_build(): return
	warn(s)
## Logs an error to the GodotAP log and Godot error console, but only in a Debug build
static func dberror(s):
	if not OS.is_debug_build(): return
	error(s)
#endregion

enum WebSocketState { STATE_CLOSED, STATE_CONNECTING, STATE_OPEN, STATE_CLOSING }

var _socket_state = WebSocketState.STATE_CLOSED

func _process(_delta):
	if _socket:
		_socket.poll()

func _on_ws_connected(_protocol=""):
	_socket_state = WebSocketState.STATE_OPEN
	var _peer = _socket.get_peer(1)
	if _peer and _peer.has_method("set_write_mode"):
		_peer.set_write_mode(0)
	if status == APStatus.SOCKET_CONNECTING:
		_log("Connected to '%s'!" % get_url())
		status = APStatus.CONNECTING

func _on_ws_closed():
	_socket_state = WebSocketState.STATE_CLOSED
	if hang_clock:
		hang_clock.stop()
	if status == APStatus.DISCONNECTING:
		status = APStatus.DISCONNECTED
		emit_signal("disconnected")
	else:
		_log("Accidental disconnection; reconnecting!")
		ap_reconnect()

func _on_ws_error():
	_socket_state = WebSocketState.STATE_CLOSED
	if status == APStatus.SOCKET_CONNECTING:
		if _connect_attempts >= 50:
			_socket.disconnect_from_host()
			status = APStatus.DISCONNECTING
			_log("Connection to '%s' failed too much! Giving up!" % get_url())
			if output_console and _connecting_part:
				_connecting_part.text = "Connection Failed!"
				_connecting_part.hint_tooltip += "\nFailed connecting too many times. Check your connection details, or '/reconnect' to try again."
				_connecting_part = null
		else:
			_log("Connection to '%s' failed! Retrying (%d)" % [get_url(), _connect_attempts])
			_wss = not _wss
			if _wss: _connect_attempts += 1
			var err = _socket.connect_to_url(get_url())
			if err:
				_log("Connection to '%s' failed immediately! Retrying (%d)" % [get_url(), _connect_attempts])
				_wss = not _wss
				if _wss: _connect_attempts += 1

func _on_ws_data():
	var packet = _socket.get_peer(1).get_packet()
	var json = parse_json(packet.get_string_from_utf8())
	if not json is Array:
		json = [json]
	for dict in json:
		_handle_command(dict)

var _printout_recieved_items = false # Used by AP_PRINT_ITEMS_ON_CONNECT
## Sends a command of the specified name, with the given dictionary as the command arguments, to the Archipelago server
func send_command(cmdname, args):
	args["cmd"] = cmdname
	send_packet([args])
## Sends an array of dictionaries as a packet of commands to the server
func send_packet(obj):
	var s = to_json(obj)
	comm_log("SEND", s)
	_socket.get_peer(1).put_packet(s.to_utf8())
func _handle_command(json): # Handle an incoming packet from the server
	var command = json["cmd"]
	comm_log("RECV", str(json))
	match command:
		"RoomInfo":
			status = APStatus.CONNECTED
			emit_signal("connect_step", "Parsing RoomInfo...")
			if output_console and _connecting_part:
				_connecting_part.text = "Authenticating..."
			conn = ConnectionInfo.new()
			conn.serv_version = Version.from(json["version"])
			conn.gen_version = Version.from(json["generator_version"])
			conn.seed_name = json["seed_name"]
			handle_datapackage_checksums(json["datapackage_checksums"])
			var args = {"name":creds.slot,"password":creds.pwd,"uuid":config.uuid,
				"version":AP_VERSION._as_ap_dict(),"slot_data":true}
			args["game"] = AP_GAME_NAME
			args["tags"] = AP_GAME_TAGS
			args["items_handling"] = AP_ITEM_HANDLING
			emit_signal("roominfo", conn, json)
			_pending_connect_args = args
			connect("all_datapacks_loaded", self, "_send_connect_cmd", [], CONNECT_ONESHOT)
			connect("disconnected", self, "_noop", [], CONNECT_ONESHOT)
			_send_datapack_request()
		"ConnectionRefused":
			var err_str = str(json["errors"])
			if output_console and _connecting_part:
				_connecting_part.text = "Connection Refused!"
				_connecting_part.hint_tooltip += "\nERROR(S): "+err_str
				_connecting_part = null
			_log("Connection errors: %s" % err_str)
			emit_signal("connect_step", "ERR: %s" % err_str)
			emit_signal("connectionrefused", conn, json)
			ap_disconnect()
		"Connected":
			conn.player_id = json["slot"]
			conn.team_id = json["team"]
			conn.slot_data = json["slot_data"]
			for plyr in json["players"]:
				conn.players.append(NetworkPlayer.from(plyr))
			var slot_info = json["slot_info"]
			for key in slot_info:
				conn.slots.append(NetworkSlot.from(slot_info[key]))

			if aplock:
				var lock_err = aplock.lock(conn)
				if lock_err:
					_connecting_part.text = "Connection Mismatch! Wrong slot for this save!"
					for s in lock_err:
						_connecting_part.hint_tooltip += "\n%s" % s
					_connecting_part = null
					ap_disconnect()
					return

			for loc in json["missing_locations"]:
				if not location_exists(loc):
					conn.slot_locations[loc as int] = false
					#Force this locations to be accessible?

			var server_checked = {}
			for loc in json["checked_locations"]:
				_remove_loc(loc)
				server_checked[loc] = true

			var to_collect = []
			for loc in conn.slot_locations.keys():
				if conn.slot_locations[loc] and not loc in server_checked:
					to_collect.append(loc)
			collect_locations(to_collect)

			# Deathlink stuff?
			# If deathlink stuff, possibly ConnectUpdate to add DeathLink tag?

			status = APStatus.PLAYING
			if output_console and _connecting_part:
				_connecting_part.text = "Connected Successfully!"
				_connecting_part = null

			emit_signal("connect_step", "Connected!")
			if AP_PRINT_ITEMS_ON_CONNECT:
				_printout_recieved_items = true
				get_tree().create_timer(3).connect("timeout", self, "_reset_printout_flag")

			conn._load_locations()
			emit_signal("connected", conn, json)
		"PrintJSON":
			_preparse_json(json)
			var s = (output_console.printjson_command(json) if output_console
				else BaseConsole.printjson_out_str(json["data"]))
			_log("[PRINT] %s" % s)
			emit_signal("printjson", json, s)
		"DataPackage":
			var packs = json["data"]["games"]
			for game in packs.keys():
				_handle_datapack(game, packs[game])
			_send_datapack_request()
		"ReceivedItems":
			while status != APStatus.PLAYING:
				if status == APStatus.CONNECTED:
					yield(self, "status_updated")
				else: return
			var idx = json["index"]
			var items = []
			for obj in json["items"]:
				items.append(NetworkItem.from(obj, true))
			var refr_items = []
			if idx == 0:
				refr_items = items.duplicate()
			if items:
				var q = 0
				while q < items.size():
					if _receive_item(idx, items[q]):
						q += 1
					else:
						items.remove(q)
					idx += 1
				conn.emit_signal("obtained_items", items)

			if json["index"] == 0:
				conn.received_items = refr_items.duplicate()
				conn.emit_signal("refresh_items", refr_items)
		"RoomUpdate":
			for loc in json.get("checked_locations", []):
				_remove_loc(loc)
			if json.has("players"):
				conn.players.clear()
				for plyr in json["players"]:
					conn.players.append(NetworkPlayer.from(plyr))
			conn.emit_signal("roomupdate", json)
		"Bounced":
			conn.emit_signal("bounce", json)
			var tags = json.get("tags", [])
			if tags.has(get_deathlink_tag()):
				var tstamp = json["data"].get("time", 0.0)
				if abs(tstamp - last_sent_deathlink_time) < 0.5:
					return # Skip deaths from self
				var source = json["data"].get("source", "")
				var cause = json["data"].get("cause", "")
				conn.emit_signal("deathlink", source, cause, json)
			if tags.has("TrapLink"):
				var tstamp = json["data"].get("time", 0.0)
				if abs(tstamp - last_sent_traplink_time) < 0.5:
					return # Skip traps from self
				var source = json["data"].get("source", "")
				var trap_name = json["data"].get("trap_name", "")
				trap_name = TRAP_LINK_ALIASES.get(trap_name, trap_name)
				conn.emit_signal("traplink", source, trap_name, json)
		"LocationInfo":
			conn._on_locinfo(json)
		"Retrieved":
			conn._on_retrieve(json)
		"SetReply":
			conn.emit_signal("setreply", json)
		"InvalidPacket":
			_log("[INVALID PACKET] Error with %s of command '%s' (%s)" % [json["type"], json.get("original_cmd", "?"), json["text"]])
		_:
			_log("[UNHANDLED PACKET TYPE] %s" % str(json))

#region DATAPACKS
var _datapack_cache = {} # Local cache of DataPackages used when connecting
var _datapack_pending = [] # List of DataPackages that are still being waited for

## For each game (key) in the checksums dictionary, requests an update for its datapackage
## if the locally stored checksum does not match the given value
func handle_datapackage_checksums(checksums):
	Util._make_dir_recursive("user://ap/datapacks/") # Ensure the directory exists, for later
	var cachefile = Util._file_open("user://ap/datapacks/cache.dat", File.READ)
	if cachefile:
		var loaded = cachefile.get_var()
		if loaded is Dictionary:
			_datapack_cache = loaded
		cachefile.close()
	_datapack_pending = []
	for game in checksums.keys():
		if _datapack_cache.has(game):
			var _f = File.new()
			if _f.file_exists("user://ap/datapacks/%s.json" % game):
				# cache file is valid
				var cached = _datapack_cache[game]
				if cached["checksum"] == checksums[game] and cached["fields"] == datapack_cached_fields:
					continue # already up-to-date, matching checksum

		_datapack_pending.append(game)

# Caches and stores to disk `data` as the DataCache file for `game`
func _handle_datapack(game, data):
	var data_file = Util._file_open("user://ap/datapacks/%s.json" % game, File.WRITE)
	_datapack_cache[game] = {"checksum":data["checksum"],"fields":datapack_cached_fields.duplicate()}
	for key in data.keys():
		if not key in datapack_cached_fields:
			data.erase(key)
	if READABLE_DATAPACK_FILES:
		data_file.store_string(JSON.print(data, "\t"))
	else:
		data_file.store_string(to_json(data))
	_data_caches[game] = DataCache.from(data)
	data_file.close()
func _noop():
	pass
func _send_connect_cmd():
	send_command("Connect", _pending_connect_args)
	_pending_connect_args = null
func _send_datapack_request():
	if _datapack_pending:
		var game = _datapack_pending.pop_front()
		emit_signal("connect_step", "Fetching DataPackage for '%s'..." % game)
		var req = [{"cmd":"GetDataPackage","games":[game]}]
		send_packet(req)
		_cache_datapacks()
	else:
		emit_signal("connect_step", "All DataPackages fetched!")
		_cache_datapacks()
		emit_signal("all_datapacks_loaded")
func _cache_datapacks():
	var cachefile = Util._file_open("user://ap/datapacks/cache.dat", File.WRITE)
	cachefile.store_var(_datapack_cache)
	cachefile.close()

const _data_caches = {} # DataPackage objects for each game
## Returns a DataCache for the specified game. If it cannot be found, returns an empty (invalid) DataCache, which can still be used, albeit it will not have the desired data within.
static func get_datacache(game):
	var ret = _data_caches.get(game)
	if ret: return ret
	var data_file = Util._file_open("user://ap/datapacks/%s.json" % game, File.READ)
	if not data_file:
		return DataCache.new()
	ret = DataCache.from_file(data_file)
	data_file.close()
	_data_caches[game] = ret
	return ret
#endregion DATAPACKS

#region ITEMS
func _receive_item(index, item):
	assert(item.dest_player_id == conn.player_id)
	if conn._received_index(index):
		return false # Already recieved, skip
	var data = conn.get_gamedata_for_player(conn.player_id)
	var msg = ""
	if item.loc_id < 0:
		if output_console and _printout_recieved_items:
			var flowbox = ConsoleHFlow.new()
			flowbox.add_text_split(conn.get_player().output())
			flowbox.add_text_split(BaseConsole.make_text(" got "))
			flowbox.add_text_split(item.output())
			flowbox.add_text_split(BaseConsole.make_text(" ("))
			flowbox.add_text_split(BaseConsole.make_location(item.loc_id, data))
			flowbox.add_text_split(BaseConsole.make_text(")"))
			output_console.add(flowbox)
		msg = "You found your %s at %s!" % [data.get_item_name(item.id),data.get_loc_name(item.loc_id)]
		_remove_loc(item.loc_id)
	elif item.dest_player_id == item.src_player_id:
		if output_console and _printout_recieved_items:
			var flowbox = ConsoleHFlow.new()
			flowbox.add_text_split(conn.get_player().output())
			flowbox.add_text_split(BaseConsole.make_text(" found their "))
			flowbox.add_text_split(item.output())
			flowbox.add_text_split(BaseConsole.make_text(" ("))
			flowbox.add_text_split(BaseConsole.make_location(item.loc_id, data))
			flowbox.add_text_split(BaseConsole.make_text(")"))
			output_console.add(flowbox)
		msg = "You found your %s at %s!" % [data.get_item_name(item.id),data.get_loc_name(item.loc_id)]
		_remove_loc(item.loc_id)
	else:
		var src_data = conn.get_gamedata_for_player(item.src_player_id)
		if output_console and _printout_recieved_items:
			var flowbox = ConsoleHFlow.new()
			flowbox.add_text_split(conn.get_player(item.src_player_id).output())
			flowbox.add_text_split(BaseConsole.make_text(" sent "))
			flowbox.add_text_split(item.output())
			flowbox.add_text_split(BaseConsole.make_text(" to "))
			flowbox.add_text_split(conn.get_player().output())
			flowbox.add_text_split(BaseConsole.make_text(" ("))
			flowbox.add_text_split(BaseConsole.make_location(item.loc_id, src_data))
			flowbox.add_text_split(BaseConsole.make_text(")"))
			output_console.add(flowbox)

		msg = "%s found your %s at their %s!" % [conn.get_player_name(item.src_player_id), data.get_item_name(item.id), src_data.get_loc_name(item.loc_id)]

	conn.emit_signal("obtained_item", item)

	if AP_LOG_RECIEVED:
		_log(msg)

	if conn.received_items.size() == index:
		conn.received_items.append(item)
	else:
		if conn.received_items.size() < index+1:
			conn.received_items.resize(index+1)
		conn.received_items[index] = item
	return true
#endregion ITEMS

#region LOCATIONS
func _remove_loc(loc_id):
	if conn and not conn.slot_locations.get(loc_id, false):
		conn.slot_locations[loc_id] = true
		emit_signal("remove_location", loc_id)
## Will call `proc` when the specified location id is "removed" (i.e. collected, either by the player or the server)
## If the location is already removed when you call this, `proc` will be called immediately.
func on_removed_id(loc_id, proc):
	if conn.slot_locations.get(loc_id, false):
		proc.call_func()
	else:
		connect("remove_location", self, "_on_location_removed", [loc_id, proc])
## Will call `proc` when the specified location name is "removed" (i.e. collected, either by the player or the server)
## If the location is already removed when you call this, `proc` will be called immediately.
func on_removed(loc_name, proc):
	on_removed_id(conn.get_gamedata_for_player(conn.player_id).get_loc_id(loc_name), proc)

## Call when a single location is collected and needs to be sent to the server.
func collect_location(loc_id):
	if _is_nongame_client: return
	_printout_recieved_items = false
	send_command("LocationChecks", {"locations":[loc_id]})
	_remove_loc(loc_id)
## Call when multiple locations are collected and need to be sent to the server at once.
func collect_locations(locs):
	if _is_nongame_client: return
	if locs.size() == 0: return
	_printout_recieved_items = false
	send_command("LocationChecks", {"locations":locs})
	for loc_id in locs:
		_remove_loc(loc_id)

## Returns if the location exists in the slot or not.
func location_exists(loc_id):
	return conn.slot_locations.has(loc_id)
## Returns if the location was checked or not. `def` is returned if the location does not exist in the slot.
func location_checked(loc_id, def = false):
	return conn.slot_locations.get(loc_id, def)
## Returns a list of all location ids
func location_list():
	var arr = []
	arr = conn.slot_locations.keys()
	return arr
#endregion LOCATIONS

## Try to reconnect to the current connection details, BUT if it detects errors in the details,
## it will instead prompt the user to enter the details in the output console (if one is open).
func ap_reconnect_to_save():
	if creds.slot.empty() or creds.port.length() != 5:
		if output_console:
			var s = "Connection details required! "
			if aplock and aplock.valid:
				s += "Please reconnect to the room previously used by this save file!"
			else:
				s += "Connect to a room when ready."
			output_console.add(BaseConsole.make_text(s, "", APColors.ComplexColor.as_special(APColors.SpecialColor.UI_MESSAGE)))
	else:
		ap_reconnect()

func _exit_tree():
	if status != APStatus.DISCONNECTED:
		ap_disconnect()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		close_logger()

#region CONSOLE

var output_console_container = null ## Container for the current output console
## The currently attached GodotAP console, if one exists.
var output_console setget set_output_console, get_output_console
func get_output_console():
	return cmd_manager.console if cmd_manager else null
func set_output_console(val):
	if cmd_manager:
		cmd_manager.console = val
	output_console = val

## Loads a PackedScene as the active console. This becomes the active scene in the passed SceneTree.
func load_packed_console_as_scene(tree, console):
	if output_console: return false
	if not Util.for_all_nodes(console.instance(), self, "_is_console_container"):
		return false
	yield(tree, "idle_frame")
	tree.change_scene_to(console)
	yield(tree, "node_added")
	assert(tree.current_scene)
	load_console(tree.current_scene, false)
	return true
## Loads a Node as the active console. The window this node is in will be considered the console window.
func load_console(console_scene, as_child = true):
	if output_console: return false
	if console_scene is ConsoleContainer:
		output_console_container = console_scene
	elif console_scene is Node:
		output_console_container = Util.for_all_nodes(console_scene, self, "_is_console_container")
		if not output_console_container:
			return false
	if as_child: call_deferred("add_child", console_scene)
	if console_scene.is_inside_tree():
		_init_console()
	else:
		console_scene.connect("ready", self, "_init_console")
	return true
## Opens a default Archipelago text console popup
func open_console():
	if output_console: return
	load_console(Util._ap_load("ui/ap_console_window.tscn").instance())
## Closes the currently attached console
func close_console():
	if output_console:
		output_console.close()
		set_output_console(null)

func _is_console_container(node):
	return node is ConsoleContainer
func _init_console():
	var tb = output_console_container.get_node(output_console_container.typing_bar)
	set_output_console(output_console_container.get_node(output_console_container.console) if output_console_container.console is NodePath else output_console_container.console)
	tb.connect("send_text", self, "_on_send_text")
	output_console.connect("tree_exiting", self, "close_console")
	tb.cmd_manager = cmd_manager
	emit_signal("on_attach_console")
func _on_send_text(s):
	cmd_manager.call_cmd(s)
	output_console.call_deferred("scroll_bottom")
func _reset_printout_flag():
	_printout_recieved_items = false
func _on_location_removed(signal_id, check_id, proc):
	if signal_id == check_id:
		proc.call_func()
#endregion CONSOLE

## The CommandManager for console commands. New commands can be registered as you like.
var cmd_manager = null
## Resets the CommandManager used by the archipelago console
func init_command_manager(can_connect, server_autofills = true):
	cmd_manager.reset()
	cmd_manager.register_default(self, "_default_cmd")
	if can_connect:
		var cmd_connect = ConsoleCommand.new("/connect")
		cmd_connect.add_help("port", "Connects to a new port, with the same ip/slot/password.")
		cmd_connect.add_help("ip[:port]", "Connects to a new ip+[optional] port, with the same slot/password. (if port omitted, uses 38281)")
		cmd_connect.add_help("ip[:port] slot [pwd]", "Connects to a new ip+port, with a new slot and [optional] password. (if port omitted, uses 38281)")
		cmd_connect.set_call(self, "_cmd_connect")
		cmd_manager.register_command(cmd_connect)

		var cmd_reconnect = ConsoleCommand.new("/reconnect")
		cmd_reconnect.add_help("", "Refreshes the connection to the Archipelago server")
		cmd_reconnect.set_call(self, "_cmd_reconnect")
		cmd_manager.register_command(cmd_reconnect)

		var cmd_disconnect = ConsoleCommand.new("/disconnect")
		cmd_disconnect.add_help_cond("", "Kills the connection to the Archipelago server", self, "is_ap_connected")
		cmd_disconnect.set_call(self, "_cmd_disconnect")
		cmd_manager.register_command(cmd_disconnect)
	var cmd_locations = ConsoleCommand.new("/locations")
	cmd_locations.add_help_cond("[filter]", "Lists all locations (optionally matching a filter) for the current slot's game.", self, "is_ap_connected")
	cmd_locations.set_call(self, "_cmd_locations")
	cmd_manager.register_command(cmd_locations)

	var cmd_items = ConsoleCommand.new("/items")
	cmd_items.add_help_cond("[filter]", "Lists all items (optionally matching a filter) for the current slot's game.", self, "is_ap_connected")
	cmd_items.set_call(self, "_cmd_items")
	cmd_manager.register_command(cmd_items)
	if server_autofills: # Autofill for some AP commands
		var cmd_hint_location = ConsoleCommand.new("!hint_location")
		cmd_hint_location.set_autofill(funcref(self, "_autofill_locs"))
		cmd_hint_location.add_disable(self, "is_not_connected")
		cmd_manager.register_command(cmd_hint_location)

		var cmd_hint = ConsoleCommand.new("!hint")
		cmd_hint.set_autofill(funcref(self, "_autofill_items"))
		cmd_hint.add_disable(self, "is_not_connected")
		cmd_manager.register_command(cmd_hint)

		var cmd_server_help = ConsoleCommand.new("!help")
		cmd_server_help.add_help("", "Displays server-based command help")
		cmd_server_help.add_disable(self, "is_not_connected")
		cmd_manager.register_command(cmd_server_help)

		var cmd_remaining = ConsoleCommand.new("!remaining")
		cmd_remaining.add_disable(self, "is_not_connected")
		cmd_manager.register_command(cmd_remaining)

		var cmd_missing = ConsoleCommand.new("!missing")
		cmd_missing.add_disable(self, "is_not_connected")
		cmd_manager.register_command(cmd_missing)

		var cmd_checked = ConsoleCommand.new("!checked")
		cmd_checked.add_disable(self, "is_not_connected")
		cmd_manager.register_command(cmd_checked)

		var cmd_collect = ConsoleCommand.new("!collect")
		cmd_collect.add_disable(self, "is_not_connected")
		cmd_manager.register_command(cmd_collect)

		var cmd_release = ConsoleCommand.new("!release")
		cmd_release.add_disable(self, "is_not_connected")
		cmd_manager.register_command(cmd_release)

		var cmd_players = ConsoleCommand.new("!players")
		cmd_players.add_disable(self, "is_not_connected")
		cmd_manager.register_command(cmd_players)
	cmd_manager.setup_basic_commands()
	if OS.is_debug_build():
		var cmd_send = ConsoleCommand.new("/send").debug()
		cmd_send.add_help("", "Cheat-Collects the given location")
		cmd_send.add_disable(self, "_check_nongame_client")
		cmd_send.set_autofill(funcref(self, "_autofill_locs"))
		cmd_send.set_call(self, "_cmd_send")
		cmd_manager.register_command(cmd_send)

		var cmd_lock_info = ConsoleCommand.new("/lock_info").debug()
		cmd_lock_info.add_help("", "Prints the connection lock info")
		cmd_lock_info.set_call(self, "_cmd_lock_info")
		cmd_manager.register_command(cmd_lock_info)

		var cmd_unlock_connection = ConsoleCommand.new("/unlock_connection").debug()
		cmd_unlock_connection.add_help("", "Unlocks the connection lock, so that any valid slot can be connected to (instead of only the slot previously connected to)")
		cmd_unlock_connection.set_call(self, "_cmd_unlock_connection")
		cmd_manager.register_command(cmd_unlock_connection)

		var cmd_set_tag = ConsoleCommand.new("/set_tag").debug()
		cmd_set_tag.add_help("tag [bool]", "Sets a tag for the current connection")
		cmd_set_tag.set_autofill(funcref(self, "_autofill_set_tag"))
		cmd_set_tag.set_call(self, "_cmd_set_tag")
		cmd_manager.register_command(cmd_set_tag)

		var cmd_tags = ConsoleCommand.new("/tags").debug()
		cmd_tags.add_help("", "Prints out your connection tags")
		cmd_tags.set_call(self, "_cmd_tags")
		cmd_manager.register_command(cmd_tags)

		var cmd_slot_data = ConsoleCommand.new("/slot_data").debug()
		cmd_slot_data.add_help("", "Prints slot_data")
		cmd_slot_data.add_disable(self, "is_not_connected")
		cmd_slot_data.set_call(self, "_cmd_slot_data")
		cmd_manager.register_command(cmd_slot_data)

		cmd_manager.setup_debug_commands()

func _init():
	var _script = get_script()
	if _script and _script.resource_path:
		var base = _script.resource_path.get_base_dir().get_base_dir()
		if base.begins_with("res://"):
			_ap_base_dir = base
	creds = APCredentials.new()
	cmd_manager = CommandManager.new()
	init_command_manager(true)
func _ready():
	_update_tags()
	if AP_AUTO_OPEN_CONSOLE:
		# Delayed to prevent some warnings
		yield(get_tree().create_timer(2.0), "timeout")
		open_console()
	_create_socket()
	for node in get_children():
		if node is APConfigManager:
			config = node
		elif node is APSaveManager:
			save_manager = node
	if not config:
		config = APConfigManager.new()
		add_child(config)
	# 'save_manager' can be null
## Item Classification bits
enum ItemClassification {
	FILLER = 0b000,
	PROG = 0b001,
	USEFUL = 0b010,
	TRAP = 0b100
}

## Converts a set of ItemClassification flags to a 'SpecialColor'
static func get_item_class_color(flags):
	if flags & ItemClassification.PROG:
		var _ap = _get_ap()
		if _ap and _ap.AP_ENABLE_PROGUSEFUL and (flags & ItemClassification.USEFUL):
			return APColors.SpecialColor.ITEM_PROGUSEFUL
		else:
			return APColors.SpecialColor.ITEM_PROG
	elif flags & ItemClassification.TRAP:
		return APColors.SpecialColor.ITEM_TRAP
	elif flags & ItemClassification.USEFUL:
		return APColors.SpecialColor.ITEM_USEFUL
	return APColors.SpecialColor.ITEM
## Returns the string name representing the combined item classifications flags
static func get_item_classification(flags):
	match flags:
		ItemClassification.PROG:
			return "Progression"
		ItemClassification.USEFUL:
			return "Useful"
		ItemClassification.TRAP:
			return "Trap"
		ItemClassification.FILLER:
			return "Filler"
		_: # If multiple bits are combined, make a comma-delimited list.
			var s = ""
			for q in 3:
				if flags & (1<<q):
					if s:
						s += ","
					s += get_item_classification(1<<q)
			return s

func _default_cmd(mgr, msg):
	if msg[0] == "/":
		mgr.console.add(BaseConsole.make_text("Unknown command '%s' - use '/help' to see commands" % msg.split(" ", true, 1)[0], "", APColors.ComplexColor.as_special(APColors.SpecialColor.UI_MESSAGE)))
	else:
		if _ensure_connected(mgr.console):
			send_command("Say", {"text":msg})
func _cmd_connect(mgr, cmd, msg):
	var command_args = msg.split(" ", true, 3)
	if command_args.size() == 2:
		command_args.append(creds.slot)
		command_args.append(creds.pwd)
	elif command_args.size() == 3:
		command_args.append("")
	if command_args.size() != 4:
		cmd.output_usage(mgr.console)
	else:
		var ipport = command_args[1].split(":",1)
		if ipport.empty():
			cmd.output_usage(mgr.console)
		if ipport.size() == 1 and ipport[0].length() == 5:
			ipport = [creds.ip,ipport[0]]
		elif ipport.size() == 1:
			ipport.append("38281")
		ap_connect(ipport[0],ipport[1],command_args[2],command_args[3])
func _cmd_reconnect(_mgr, _cmd, _msg):
	ap_reconnect()
func _cmd_disconnect(_mgr, _cmd, _msg):
	ap_disconnect()
func _cmd_locations(mgr, _cmd, msg):
	if not _ensure_connected(mgr.console): return
	var filt = msg.substr(11)
	var data = conn.get_gamedata_for_player()
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_constant_override("h_separation", 80)
	var title = "LOCATIONS"
	if filt: title += " (%s)" % filt
	var folder = BaseConsole.make_foldable("[ %s ]" % title, msg, APColors.ComplexColor.as_special(APColors.SpecialColor.UI_MESSAGE))
	mgr.console.add(folder)
	folder.add(grid)
	folder.fold(false)
	var h1 = BaseConsole.make_text("Location Name:")
	grid.add_child(h1)
	if filt:
		h1.hint_tooltip = "Filter: " + filt
	grid.add_child(BaseConsole.make_text("Status:"))
	var ids = data.location_name_to_id.values()
	_sort_temp_index_dict.clear()
	for q in ids.size():
		_sort_temp_index_dict[ids[q]] = q
	ids.sort_custom(self, "_sort_by_index")
	for lid in ids:
		var loc_name = data.get_loc_name(lid)
		if not filt or (filt.to_lower() in loc_name.to_lower()):
			var loc_status = find_hint_status(lid, NetworkHint.Status.NOT_FOUND)
			var color = APColors.ComplexColor.as_rich(NetworkHint._get_status_colors().get(loc_status, APColors.RichColor.RED))
			var stat_name = NetworkHint.status_names.get(loc_status, "Not Found")
			grid.add_child(BaseConsole.make_text(loc_name, "Location %d" % lid, color))
			grid.add_child(BaseConsole.make_text(stat_name, "", color))
	mgr.console.add_header_spacing()
func _sort_by_index(a, b):
	return _sort_temp_index_dict[b] > _sort_temp_index_dict[a]
func _cmd_items(mgr, _cmd, msg):
	if not _ensure_connected(mgr.console): return
	var filt = msg.substr(7)
	var data = conn.get_gamedata_for_player()
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_constant_override("h_separation", 80)
	var title = "ITEMS"
	if filt: title += " (%s)" % filt
	var folder = BaseConsole.make_foldable("[ %s ]" % title, msg, APColors.ComplexColor.as_special(APColors.SpecialColor.UI_MESSAGE))
	mgr.console.add(folder)
	folder.add(grid)
	folder.fold(false)
	var item_dict = {}
	for item in conn.received_items:
		var dict = item_dict.get(item.id)
		if dict:
			dict[item.flags] = dict.get(item.flags, 0) + 1
		else:
			item_dict[item.id] = {item.flags: 1}
	var ids = data.item_name_to_id.values()
	_sort_temp_index_dict.clear()
	_sort_temp_item_dict = item_dict.duplicate()
	for q in ids.size(): _sort_temp_index_dict[ids[q]] = q
	ids.sort_custom(self, "_sort_items_by_flag")
	var found_second_column = false
	var found_any = false
	for iid in ids:
		var itm_name = data.get_item_name(iid)
		if not filt or (filt.to_lower() in itm_name.to_lower()):
			found_any = true
			var flag_options = item_dict.get(iid)
			if flag_options:
				found_second_column = true
				break
	var filt_ttip = "Filter: " + filt
	if found_any:
		grid.columns = 2 if found_second_column else 1
		var h1 = BaseConsole.make_text("Item Name:")
		grid.add_child(h1)
		if filt:
			h1.hint_tooltip = filt_ttip
		if found_second_column:
			grid.add_child(BaseConsole.make_text("Num Collected:"))
		for iid in ids:
			var itm_name = data.get_item_name(iid)
			if not filt or (filt.to_lower() in itm_name.to_lower()):
				var flag_options = item_dict.get(iid)
				if flag_options:
					for flags in flag_options.keys():
						var c1 = BaseConsole.make_item(iid, flags, data)
						grid.add_child(c1)
						grid.add_child(BaseConsole.make_text("x%d" % flag_options[flags], "", APColors.ComplexColor.as_rich(c1.rich_color)))
				else:
					grid.add_child(BaseConsole.make_text(itm_name, "Item %d" % iid))
					if found_second_column:
						grid.add_child(Control.new())
	elif filt:
		grid.add_child(BaseConsole.make_text(
			"No%s items found!" % (" matching" if filt else ""),
			filt_ttip, APColors.ComplexColor.as_rich(APColors.RichColor.SALMON)))
	mgr.console.add_header_spacing()
func _sort_items_by_flag(a, b):
	var has_a = _sort_temp_item_dict.has(a)
	var has_b = _sort_temp_item_dict.has(b)
	if has_a and not has_b:
		return true
	if has_a == has_b:
		return _sort_temp_index_dict[b] > _sort_temp_index_dict[a]
	return false
func _cmd_send(mgr, cmd, msg):
	if not _ensure_connected(mgr.console): return
	var command_args = msg.split(" ", true, 1)
	if command_args.size() > 1 and command_args[1]:
		var data = conn.get_gamedata_for_player(conn.player_id)
		for loc in conn.slot_locations.keys():
			var loc_name = data.get_loc_name(loc)
			if loc_name.strip_edges().to_lower() == command_args[1].strip_edges().to_lower():
				if conn.slot_locations[loc]:
					mgr.console.add(BaseConsole.make_text("Location already sent!", "", APColors.ComplexColor.as_special(APColors.SpecialColor.UI_MESSAGE)))
				else:
					mgr.console.add(BaseConsole.make_text("Sending location '%s'!" % loc_name, "", APColors.ComplexColor.as_special(APColors.SpecialColor.UI_MESSAGE)))
					collect_location(loc)
				return
		mgr.console.add(BaseConsole.make_text("Location '%s' not found! Check spelling?" % command_args[1].strip_edges(), "", APColors.ComplexColor.as_special(APColors.SpecialColor.UI_MESSAGE)))
	else: cmd.output_usage(mgr.console)
func _cmd_lock_info(mgr, _cmd, _msg):
	mgr.console.add(BaseConsole.make_text("%s" % (str(aplock) if aplock else "No Lock Active"), "", APColors.ComplexColor.as_special(APColors.SpecialColor.UI_MESSAGE)))
func _cmd_unlock_connection(_mgr, _cmd, _msg):
	if aplock:
		aplock.unlock()
func _cmd_set_tag(mgr, cmd, msg):
	var args = msg.split(" ", true, 2)
	var state = true
	var tag = args[1].strip_edges() if args.size() > 1 else ""
	if tag.empty():
		cmd.output_usage(mgr.console)
		return
	if args.size() > 2:
		var s = args[2].to_lower()
		if s == "false": state = false
		elif s != "true":
			cmd.output_usage(mgr.console)
			return
	set_tag(tag, state)
	mgr.console.add(BaseConsole.make_text("Set tag '%s' to %s" % [args[1],state], "", APColors.ComplexColor.as_special(APColors.SpecialColor.UI_MESSAGE)))
func _autofill_set_tag(msg):
	var args = msg.split(" ", 2)
	var arg_count = args.size()
	while args.size() < 3: args.append("")
	var ret = []
	var opts = []
	if arg_count < 3:
		opts = ["TextOnly","HintGame","Tracker",get_deathlink_tag()]
		var matched = false
		for opt in opts:
			if args[1] == opt:
				matched = true
				break
			if opt.to_lower().begins_with(args[1].to_lower()):
				ret.append("%s %s" % [args[0],opt])
		if not matched:
			return ret
		ret.clear()
	opts = ["true","false"]
	for opt in opts:
		if arg_count < 3 or opt.to_lower().begins_with(args[2].to_lower()):
			ret.append("%s %s %s" % [args[0],args[1],opt])
	return ret
func _cmd_tags(mgr, _cmd, _msg):
	mgr.console.add(BaseConsole.make_text(str(AP_GAME_TAGS), "", APColors.ComplexColor.as_special(APColors.SpecialColor.UI_MESSAGE)))
func _cmd_slot_data(mgr, _cmd, _msg):
	var folder = BaseConsole.make_foldable("[ SLOT_DATA ]", "/slot_data", APColors.ComplexColor.as_special(APColors.SpecialColor.UI_MESSAGE))
	mgr.console.add(folder)
	folder.add(BaseConsole.make_indented_block(JSON.print(conn.slot_data, "\t"), 25))
	folder.fold(false)
func _check_nongame_client():
	return _is_nongame_client
func _cmd_nil(_msg): pass
func _autofill_locs(msg):
	if not conn: return []
	var args = msg.split(" ", true, 1)
	var data = conn.get_gamedata_for_player(conn.player_id)
	var locs = []
	locs = data.location_name_to_id.keys()
	var ind = 0
	while ind < locs.size():
		var id = data.location_name_to_id[locs[ind]]
		if location_checked(id, true):
			locs.remove(ind)
		else: ind += 1
	if args.size() > 1 and args[1]:
		var arg_str = args[1].strip_edges().to_lower()
		if arg_str.begins_with("\""):
			arg_str = arg_str.substr(1)
		if arg_str.ends_with("\""):
			arg_str = arg_str.substr(0,arg_str.length()-1)
		var q = 0
		while q < locs.size():
			if not locs[q].strip_edges().to_lower().begins_with(arg_str):
				locs.remove(q)
			else:
				q += 1
	for q in locs.size():
		locs[q] = "%s %s" % [args[0],locs[q]]
	return locs
func _autofill_items(msg):
	if not conn: return []
	var args = msg.split(" ", true, 1)
	var data = conn.get_gamedata_for_player(conn.player_id)
	var itms = []
	itms = data.item_name_to_id.keys()
	if args.size() > 1 and args[1]:
		var arg_str = args[1].strip_edges().to_lower()
		if arg_str.begins_with("\""):
			arg_str = arg_str.substr(1)
		if arg_str.ends_with("\""):
			arg_str = arg_str.substr(0,arg_str.length()-1)
		var q = 0
		while q < itms.size():
			if not itms[q].strip_edges().to_lower().begins_with(arg_str):
				itms.remove(q)
			else:
				q += 1
	for q in itms.size():
		itms[q] = "%s %s" % [args[0],itms[q]]
	return itms

# If the current client is `non-game`, i.e. a `TextOnly`, `Tracker`, or `HintGame` tagged client which cannot send locations.
var _is_nongame_client = false
var _sort_temp_index_dict = {}
var _sort_temp_item_dict = {}
func _update_tags():
	if status == APStatus.PLAYING:
		send_command("ConnectUpdate", {"tags":AP_GAME_TAGS})
	_is_nongame_client = false
	for tag in AP_GAME_TAGS:
		if tag == "TextOnly" or tag == "Tracker" or tag == "HintGame":
			_is_nongame_client = true
			break
	emit_signal("on_tag_change")
## Sets a given Archipelago tag (on or off)
func set_tag(tag, state = true):
	if tag.empty(): return
	for q in AP_GAME_TAGS.size():
		var t = AP_GAME_TAGS[q]
		if t == tag:
			if not state:
				AP_GAME_TAGS.remove(q)
				_update_tags()
			return
	if state:
		AP_GAME_TAGS.append(tag)
		_update_tags()
## Checks if a given tag is active
func has_tag(tag):
	return tag in AP_GAME_TAGS
## Sets the Archipelago connection tags (overwriting all existing tags)
func set_tags(tags):
	if AP_GAME_TAGS != tags:
		AP_GAME_TAGS = tags.duplicate()
		_update_tags()
## Sets the Archipelago connection tags (overwrites tags except supported tags 'DeathLink' / 'TrapLink')
func set_misc_tags(tags):
	var supported_tags = [get_deathlink_tag(), "TrapLink"]
	tags = tags.duplicate()
	for tag in supported_tags:
		if tag in AP_GAME_TAGS:
			if not (tag in tags):
				tags.append(tag)
		else: tags.erase(tag)
	set_tags(tags)

func _ensure_connected(console):
	if status == APStatus.PLAYING:
		return true
	console.add(BaseConsole.make_text("Not connected to Archipelago! Please connect first!", "", APColors.ComplexColor.as_special(APColors.SpecialColor.UI_MESSAGE)))
	return false

## Changes this connection's DeathLink group
## Will only send/receive deaths with other clients in the same group
func set_deathlink_group(group):
	if group == deathlink_group: return
	var deathlink = is_deathlink()
	if deathlink:
		set_deathlink(false)
	deathlink_group = group
	if deathlink:
		set_deathlink(true)
## Returns the current DeathLink group name
## Will only send/receive deaths with other clients in the same group
func get_deathlink_group():
	return deathlink_group
## Returns the tag being used for DeathLink (including DeathLink group support)
func get_deathlink_tag():
	return "DeathLink" + deathlink_group
## Turn 'DeathLink' on or off
func set_deathlink(state):
	set_tag(get_deathlink_tag(), state)
## Check if 'DeathLink' is on
func is_deathlink():
	return has_tag(get_deathlink_tag())

## Turn 'TrapLink' on or off
func set_traplink(state):
	set_tag("TrapLink", state)
## Check if 'TrapLink' is on
func is_traplink():
	return has_tag("TrapLink")

## Archipelago client statuses
enum ClientStatus {
	CLIENT_UNKNOWN = 0, ## error value
	CLIENT_CONNECTED = 5, ## at least one client has connected to this slot
	CLIENT_READY = 10, ## this slot has indicated it is 'ready'
	CLIENT_PLAYING = 20, ## this slot has begun playing
	CLIENT_GOAL = 30 ## this slot has won
}
## Set the current Archipelago status.
## Set to 'CLIENT_GOAL' when the player has 'won'.
func set_client_status(stat):
	send_command("StatusUpdate", {"status": stat})

## Gets the status of the specified hint.
func find_hint_status(loc_id, default = null):
	if default == null:
		default = NetworkHint.Status.UNSPECIFIED
	if location_checked(loc_id):
		return NetworkHint.Status.FOUND
	for hint in conn.hints:
		if hint.item.src_player_id == conn.player_id and \
			hint.item.loc_id == loc_id:
			return hint.status
	return default

# Used to override incoming packets from the Archipelago server.
func _preparse_json(json):
	var data = json.get("data")
	if not data: return
	if data.size() != 1: return # Optimize, don't check if we know we don't care

	# Idea: Alter the 'compressed websocket' warning, to remove the part telling players to inform the developer, as it is a known issue.
	#if data[0]["text"] == "Warning: your client does not support compressed websocket connections! It may stop working in the future. If you are a player, please report this to the client\'s developer.":
	#	data[0]["text"] = "Warning: your client does not support compressed websocket connections! The GodotAP dev is already aware of this issue, but there is currently no available way to fix this (as of Godot 4.4), until the Godot engine updates to support compressed websockets."
	return
