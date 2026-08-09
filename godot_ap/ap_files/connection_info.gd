## Data representing a connection to the Archipelago server.
##
## Each new connection will be sent via the 'Archipelago.connected' signal.
## As each connection is a new object, any connections to signals of this class will automatically be cleaned up upon disconnecting.
class_name ConnectionInfo

const _AP_state = {"ref": null}
const _NH_state = {"ref": null}
const _NI_state = {"ref": null}

static func _get_ap():
	if _AP_state.ref == null:
		_AP_state.ref = Util._get_ap()
	return _AP_state.ref
static func _get_nh():
	if _NH_state.ref == null:
		_NH_state.ref = Util._ap_load("ap_files/network_hint.gd")
	return _NH_state.ref
static func _get_ni():
	if _NI_state.ref == null:
		_NI_state.ref = Util._ap_load("ap_files/network_item.gd")
	return _NI_state.ref

# Variables / data

var serv_version ## The server's Archipelago version
var gen_version ## The generator's Archipelago version
var seed_name ## The seed_name received from the server

var player_id ## The ID of your player
var team_id ## The ID of your team (unimplemented)
var slot_data ## The slot_data from the server

var players = [] ## The players in this Multiworld
var slots = [] ## The slots in this Multiworld

## The checked status of the locations for this slot, by location ID.
var slot_locations = {}

## The NetworkItems received from the server, in index order.
var received_items = []

## The hints for this slot.
var hints = [] setget , get_hints
func get_hints():
	if not _hint_listening:
		var ap = _get_ap()
		if ap:
			ap.warn("Tried to access hint information, but the client isn't listening for hints from the server!\n\t\t\tCall 'set_hint_notify()' or 'install_hint_listenter()' first!")
	return hints

## All locations, by ID
var locations = {}
## All locations, by name
var locs_by_name = {}

# Init / Getters

func _received_index(index):
	return received_items.size() > index and received_items[index] != null

func _to_string():
	return "AP_CONN(SERV_%s, GEN_%s, SEED:%s, PLYR %d, TEAM %d, SLOT_DATA %s)" % [serv_version,gen_version,seed_name,player_id,team_id,slot_data]

## Returns a NetworkPlayer for the given ID (or the current slot)
## TODO: Handle teams
func get_player(id_ = -1):
	if id_ < 0: return players[player_id-1]
	return players[id_-1]
## Returns a NetworkSlot for the given ID (or the current slot)
## TODO: Handle teams
func get_slot(id_ = -1):
	if id_ < 0: return slots[player_id-1]
	return slots[id_-1]
## Returns a player's name for the given ID (or the current slot)
## If `alias` is false, will return the slot name regardless of alias
func get_player_name(plyr_id_ = -1, alias = true):
	var plyr_id = plyr_id_
	var name = get_player(plyr_id).get_name(alias)
	if not name: name = "Player %d" % plyr_id
	return name
## Returns the game name for the given player ID (or the current slot)
func get_game_for_player(plyr_id = -1):
	return get_slot(plyr_id).game
## Returns the DataCache for the given player ID (or the current slot)
func get_gamedata_for_player(plyr_id = -1):
	var ap = _get_ap()
	if ap:
		return ap.get_datacache(get_game_for_player(plyr_id))
	return DataCache.new()

## Returns the APLocation (name + id + current hint status) for the given location ID
func get_location(locid):
	return locations.get(locid, APLocation.nil())
## Returns the APLocation (name + id + current hint status) for the given location name
func get_loc_by_name(loc_name):
	return locs_by_name.get(loc_name, APLocation.nil())

# Loads (or reloads) all locations from the datapackage.
func _load_locations():
	locations.clear()
	locs_by_name.clear()
	assert(not _get_ap()._datapack_pending) # should never be called before datapacks are loaded...
	for locid in _get_ap().location_list():
		var loc = APLocation.make(locid)
		locations[locid] = loc
		locs_by_name[loc.name] = loc

# Incoming server packets
## Emitted when a `Bounce` packet is received.
signal bounce(json)
## Emitted when a `Bounce` packet of type `DeathLink` is received, after the `bounce` signal.
signal deathlink(source, cause, json)
## Emitted when a `Bounce` packet of type `TrapLink` is received, after the `bounce` signal.
## 'trap_name' will be the trap name AFTER resolving the received name through `TRAP_LINK_ALIASES`.
signal traplink(source, trap_name, json)

## Emitted when a `SetReply` packet is received
signal setreply(json)
## Emitted when a `RoomUpdate` packet is received
signal roomupdate(json)
## Emitted for each item received
signal obtained_item(item)
## Emitted for each item *packet* received
signal obtained_items
## Emitted when the server re-sends ALL obtained items
signal refresh_items
## Used as part of the `set_hint_notify()` / `install_hint_listener()` functions.
## Use `set_hint_notify()` instead of connecting to this signal directly.
signal _on_hint_update

## Emitted when a scout packet containing ALL locations is received (see `force_scout_all`)
signal all_scout_cached
# Outgoing server packets
var _notified_keys = {}
var _setreply_callbacks = {}
var _hint_listening = false
## Tell the server to send us information about the hints for this slot.
func install_hint_listener():
	if _hint_listening: return
	_hint_listening = true
	var hint_str = "_read_hints_%d_%d" % [team_id, player_id]
	set_notify(hint_str, funcref(self, "_load_hints_from_json"))
	retrieve(hint_str, funcref(self, "_load_hints_from_json"))
func _load_hints_from_json(new_hints):
	hints = []
	for json in new_hints:
		hints.append(_get_nh().from(json))
	emit_signal("_on_hint_update", hints)


## Connects the specified `Callable(Array)->void` to be called every time
## hints are updated for this client. Will call immediately, if hints are already loaded;
## else will immediately call for hints to be loaded, which will trigger an update.
func set_hint_notify(target, method):
	connect("_on_hint_update", target, method)
	if _hint_listening: target.call(method, hints)
	else: install_hint_listener()
## Sends a `SetNotify` packet, and connects the specified `Callable(Variant)->void`
## to be called every time the specified `key` is updated on the server.
func set_notify(key, proc):
	if not _notified_keys.has(key):
		_get_ap().send_command("SetNotify", {"keys": [key]})
		_notified_keys[key] = true
	if not _setreply_callbacks.has(key):
		_setreply_callbacks[key] = []
	_setreply_callbacks[key].append(proc)
	if not is_connected("setreply", self, "_on_setreply"):
		connect("setreply", self, "_on_setreply")

var _retrieve_queue = {}
## Sends a `Get` packet, and connects the specified `Callable(Variant)->void`
## to be called once when the result is retrieved
func retrieve(key, proc):
	_get_ap().send_command("Get", {"keys": [key]})
	if not _retrieve_queue.has(key):
		_retrieve_queue[key] = [proc]
	else: _retrieve_queue[key].append(proc)
func _on_setreply(json):
	var key = json.get("key")
	if _setreply_callbacks.has(key):
		for proc in _setreply_callbacks[key]:
			proc.call_func(json.get("value"))
func _on_retrieve(json):
	var vals = json.get("keys", {})
	for key in vals.keys():
		for proc in _retrieve_queue.get(key, []):
			proc.call_func(vals[key])
		_retrieve_queue[key] = []

## Sends an `UpdateHint` packet, updating the status of an existing hint
## The hint is identified by `loc, plyr`, the location it is for and the player who is to find it
func update_hint(loc, plyr, status):
	_get_ap().send_command("UpdateHint", {"location": loc, "player": plyr, "status": status})

var _scout_cache = {}
var _scout_queue = {}
## Sends a `LocationScouts` packet, and connects the specified `Callable(NetworkItem)->void`
## to be called with the returned information.
## If the location has already been scouted this session, returns the cached info.
func scout(location, create_as_hint, proc):
	var item = _scout_cache.get(location)
	if create_as_hint or not item: # Always send if `create_as_hint`!
		_get_ap().send_command("LocationScouts", {"locations": [location], "create_as_hint": create_as_hint})
	if not proc: return
	if item:
		proc.call_func(item)
	else:
		if not _scout_queue.has(location):
			_scout_queue[location] = [proc]
		else: _scout_queue[location].append(proc)
func _on_locinfo(json):
	var locs = json.get("locations", [])
	for loc in locs:
		var locid = loc["location"] as int
		_scout_cache[locid] = _get_ni().from(loc, false)
		for proc in _scout_queue.get(locid, []):
			proc.call_func(_scout_cache[locid])
		_scout_queue.erase(locid)
	if locs.size() == slot_locations.size():
		emit_signal("all_scout_cached")
func force_scout_all(): ## Scouts every location into the local cache
	_get_ap().send_command("LocationScouts", {"locations": slot_locations.keys(), "create_as_hint": 0})

## Sends a `Bounce` packet with whatever information you like
func send_bounce(data, target_games, target_slots, target_tags):
	var cmd = {}
	if target_games:
		cmd["games"] = target_games
	if target_slots:
		cmd["slots"] = target_slots
	if target_tags:
		cmd["tags"] = target_tags
	if not cmd: return
	cmd.merge(data)
	_get_ap().send_command("Bounce", cmd)

## Sends a `Bounce` packet designed for the `DeathLink` feature
## Requires `DeathLink` being enabled (see 'Archipelago.set_deathlink()')
## Only players in the same DeathLink group will be killed.
func send_deathlink(cause = ""):
	if not _get_ap().is_deathlink():
		_get_ap().log("Tried to send DeathLink while DeathLink is not enabled!")
		return
	var cmd = {"data": {}}
	if not cause.empty():
		cmd["data"]["cause"] = cause
	cmd["data"]["source"] = get_player_name(-1, false)
	_get_ap().last_sent_deathlink_time = OS.get_unix_time()
	cmd["data"]["time"] = _get_ap().last_sent_deathlink_time
	send_bounce(cmd, [], [], [_get_ap().get_deathlink_tag()])

## Sends a `Bounce` packet designed for the `TrapLink` feature
## Requires the client be connected with the `TrapLink` tag
func send_traplink(trap_name):
	if not _get_ap().is_traplink():
		_get_ap().log("Tried to send TrapLink while TrapLink is not enabled!")
		return
	if trap_name.empty():
		_get_ap().log("Tried to send TrapLink without a trap name!")
		return
	var cmd = {"data": {}}
	cmd["data"]["trap_name"] = trap_name
	cmd["data"]["source"] = get_player_name(-1, false)
	_get_ap().last_sent_traplink_time = OS.get_unix_time()
	cmd["data"]["time"] = _get_ap().last_sent_traplink_time
	send_bounce(cmd, [], [], ["TrapLink"])

