class_name Gift

var id: String
var item_name: String
var amount: int = 1
var item_value: int = -1
var gift_traits: Array[GiftTrait] = []
var sender_slot: int
var receiver_slot: int
var sender_team: int
var receiver_team: int
var is_refund: bool = false

func to_json() -> Dictionary:
	# TODO: Suport Data Version 1-2 (PascalCase)
	var json: Dictionary = {
		"id": id,
		"item_name": item_name,
		"amount": amount,
		"traits": [],
		"sender_slot": sender_slot,
		"receiver_slot": receiver_slot,
		"sender_team": sender_team,
		"receiver_team": receiver_team,
		"is_refund": is_refund
	}
	for t in gift_traits:
		json["traits"].append(t.to_json())
	if item_value >= 0:
		json["item_value"] = item_value
	return json
	
func _to_string() -> String:
	return "GIFT(%s, %s x%d, %d->%d, team %d->%d)" % [id, item_name, amount, sender_slot, receiver_slot, sender_team, receiver_team]
