class_name NetworkHint

enum Status {
	UNSPECIFIED = 0,
	NON_PRIORITY = 10,
	AVOID = 20,
	PRIORITY = 30,

	FOUND = -2, # Special case, not actually a status value but used for the same GUI column
	NOT_FOUND = -1, # Compat, can probaly remove soon
}

const status_names = {
	Status.FOUND: "Found",
	Status.UNSPECIFIED: "Unspecified",
	Status.NON_PRIORITY: "No Priority",
	Status.AVOID: "Avoid",
	Status.PRIORITY: "Priority",
	Status.NOT_FOUND: "Not Found",
}
const _status_colors_state = {"dict": null}
static func _get_status_colors():
	var d = _status_colors_state.dict
	if not d:
		d = {
			Status.FOUND: APColors.RichColor.GREEN,
			Status.UNSPECIFIED: APColors.RichColor.NIL,
			Status.NON_PRIORITY: APColors.RichColor.SLATEBLUE,
			Status.AVOID: APColors.RichColor.SALMON,
			Status.PRIORITY: APColors.RichColor.PLUM,
			Status.NOT_FOUND: APColors.RichColor.RED,
		}
		_status_colors_state.dict = d
	return d

var item
var entrance
var status = Status.NOT_FOUND

static func from(json):
	if json["class"] != "Hint":
		return null
	var hint = Util._ap_load("ap_files/network_hint.gd").new()
	hint.item = NetworkItem.from_hint(json)
	if json.get("found", false):
		hint.status = Status.FOUND
	else:
		hint.status = int(json.get("status", Status.NOT_FOUND))
	hint.entrance = json.get("entrance", "")
	return hint

func is_local():
	return item.is_local()

func make_status():
	return make_hint_status(status)

const _BC_state = {"ref": null}
static func _get_bc():
	if _BC_state.ref == null:
		_BC_state.ref = Util._ap_load("ui/console/base_console.gd")
	return _BC_state.ref

static func make_hint_status(targ_status):
	var txt = status_names.get(targ_status, "Unknown")
	var color = _get_status_colors().get(targ_status, APColors.RichColor.RED)
	return _get_bc().make_text(txt, "", APColors.ComplexColor.as_rich(color))

static func update_hint_status(targ_status, part):
	part.text = status_names.get(targ_status, "Unknown")
	part.rich_color = _get_status_colors().get(targ_status, APColors.RichColor.RED)

func as_plain_string():
	return "%s %s '%s' (%s) for %s at '%s'" % [
		Util._get_ap().conn.get_player_name(item.src_player_id),
		"found" if status == Status.FOUND else "will find",
		item.get_name(), item.get_classification(),
		Util._get_ap().conn.get_player_name(item.dest_player_id),
		Util._get_ap().conn.get_gamedata_for_player(item.src_player_id).get_loc_name(item.loc_id)
	]

func _to_string():
	return "HINT(%d %d %d %d %d)" % [item.src_player_id,item.id,item.dest_player_id,item.loc_id,status]
