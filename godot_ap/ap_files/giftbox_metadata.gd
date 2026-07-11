class_name GiftBoxMetadata

var is_open: bool = true
var accepts_any_gift: bool = true
var desired_traits: Array[String] = []
var minimum_gift_data_version: int = 1
var maximum_gift_data_version: int = 3

static func from(json: Dictionary) -> GiftBoxMetadata:
	# TODO: Suport Data Version 1-2
	var v := GiftBoxMetadata.new()
	var io: Variant = json.get("is_open")
	v.is_open = io if (io is bool) else true
	var aag: Variant = json.get("accepts_any_gift")
	v.accepts_any_gift = aag if (aag is bool) else true
	var dt: Variant = json.get("desired_traits")
	v.desired_traits = dt if (dt is Array) else []
	# TODO: Add validation so min version can't be less than 1?
	var min_v: Variant = json.get("minimum_gift_data_version")
	v.minimum_gift_data_version = min_v if (min_v is int) else 1
	var max_v: Variant = json.get("maximum_gift_data_version")
	v.maximum_gift_data_version = max_v if (max_v is int) else 3
	return v

func to_json() -> Dictionary:
	# TODO: Suport Data Version 1-2
	var json: Dictionary = {
		"is_open": is_open,
		"accepts_any_gift": accepts_any_gift,
		"desired_traits": desired_traits,
		"minimum_gift_data_version": minimum_gift_data_version,
		"maximum_gift_data_version": maximum_gift_data_version,
	}
	return json
