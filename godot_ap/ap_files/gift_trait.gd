class_name GiftTrait

var gift_trait: String
var quality: float = 1.0
var duration: float = 1.0

func to_json() -> Dictionary:
	# TODO: Suport Data Version 1-2 (PascalCase)
	var json: Dictionary = {
		"trait": gift_trait,
		"quality": quality,
		"duration": duration
	}
	return json
