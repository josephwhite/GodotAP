class_name GiftTrait

var gift_trait: String
var quality: float = 1.0
var duration: float = 1.0

static func from(json: Dictionary) -> GiftTrait:
	# TODO: Suport Data Version 1-2
	var v := GiftTrait.new()
	var t: Variant = json.get("trait")
	v.gift_trait = t if (t is String) else ""
	var q: Variant = json.get("quality")
	v.quality = q if (q is float or q is int) else 1.0
	var d: Variant = json.get("duration")
	v.duration = d if (d is float or d is int) else 1.0
	return v

func to_json() -> Dictionary:
	# TODO: Suport Data Version 1-2
	var json: Dictionary = {
		"trait": gift_trait,
		"quality": quality,
		"duration": duration
	}
	return json
