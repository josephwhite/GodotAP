class_name GiftBoxMetadata

var is_open: bool = true
var accepts_any_gift: bool = true
var desired_traits: Array[String] = []
var minimum_gift_data_version: int = 1
var maximum_gift_data_version: int = 3

func to_json() -> Dictionary:
	# TODO: Suport Data Version 1-2 (PascalCase)
	var json: Dictionary = {
		"is_open": is_open,
		"accepts_any_gift": accepts_any_gift,
		"desired_traits": desired_traits,
		"minimum_gift_data_version": minimum_gift_data_version,
		"maximum_gift_data_version": maximum_gift_data_version,
	}
	return json
