class_name Gift

var id: String
var item_name: String
var amount: int = 1
var item_value: int = 0
var gift_traits: Array[GiftTrait] = []
var sender_slot: int = 0
var receiver_slot: int = 0
var sender_team: int = 0
var receiver_team: int = 0
var is_refund: bool = false

static func from(json: Dictionary) -> Gift:
	# TODO: Suport Data Version 1-2
	var v := Gift.new()
	var id: Variant = json.get("id")
	v.id = id if (id is String) else ""
	var n: Variant = json.get("item_name")
	v.item_name = n if (n is String) else ""
	var a: Variant = json.get("amount")
	v.amount = a if (a is int) else 1
	var iv: Variant = json.get("item_value")
	v.item_value = iv if (iv is int) else 0
	var isr: Variant = json.get("is_refund")
	v.is_refund = isr if (isr is bool) else false
	# sender/receiver
	v.sender_slot = json.get("sender_slot", 0)
	v.receiver_slot = json.get("receiver_slot", 0)
	v.sender_team = json.get("sender_team", 0)
	v.receiver_team = json.get("receiver_team", 0)
	# traits
	var gt_raw: Variant = json.get("traits")
	if gt_raw is Array:
		for t in gt_raw:
			if t is Dictionary:
				var gt := GiftTrait.from(t)
				if not gt.gift_trait.is_empty():
					v.traits.append(gt)
	return v

func to_json() -> Dictionary:
	# TODO: Suport Data Version 1-2
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
