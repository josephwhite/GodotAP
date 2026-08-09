class_name DataCache

var item_name_to_id = {}
var location_name_to_id = {}
var checksum = ""

static func from(data):
	var c = Util._ap_load("ap_files/datacache.gd").new()
	c.item_name_to_id = data.get("item_name_to_id", c.item_name_to_id)
	for k in c.item_name_to_id.keys():
		c.item_name_to_id[k] = c.item_name_to_id[k] as int
	c.location_name_to_id = data.get("location_name_to_id", c.location_name_to_id)
	for k in c.location_name_to_id.keys():
		c.location_name_to_id[k] = c.location_name_to_id[k] as int
	c.checksum = data.get("checksum", c.checksum)
	return c
static func from_file(file):
	if not file: return null
	var dict = parse_json(file.get_as_text())
	if dict is Dictionary:
		return from(dict)
	return null
func get_item_id(name):
	var id = item_name_to_id.get(name, -1)
	return id
func get_loc_id(name):
	var id = location_name_to_id.get(name, -1)
	return id
static func _dict_find_key(dict, val):
	for k in dict:
		if dict[k] == val:
			return k
	return null

func get_item_name(id):
	var v =_dict_find_key(item_name_to_id, id)
	return str(v) if v else str(id)
func get_loc_name(id):
	if id < 0:
		if id == -1:
			return "Server"
		if id == -2:
			return "Starting Inventory"
		return "??? #%d" % id
	var v = _dict_find_key(location_name_to_id, id)
	return str(v) if v else str(id)

func is_valid():
	return not checksum.empty()
