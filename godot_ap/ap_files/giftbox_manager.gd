class_name GiftBoxManager

## Format key for GiftBoxes in DataStorage. Needs player's slot and team number.
const GIFTBOX_KEY_FORMAT := "GiftBox;%d;%d"

## Format key for Motherboxes in DataStorage. Needs team number.
const MOTHERBOX_KEY_FORMAT := "GiftBoxes;%d"

var _is_open := false
var _auto_reject := false
## The metadata for this giftbox (null if not open)
var metadata: GiftBoxMetadata = null
## Gifts received, by gift ID
var incoming_gifts: Dictionary[String, Gift] = {}
## Gifts sent by us, by gift ID
var outgoing_gifts: Dictionary[String, Gift] = {}

func _get_giftbox_key(team: int = -1, slot: int = -1) -> String:
	if team < 0: team = conn.team_id
	if slot < 0: slot = conn.player_id
	return GIFTBOX_KEY_FORMAT % [team, slot]

func _get_motherbox_key(team: int = -1) -> String:
	if team < 0: team = conn.team_id
	return MOTHERBOX_KEY_FORMAT % [team]

## Returns true if the giftbox is currently open.
func is_open() -> bool:
	return _is_open

func set_auto_reject(enabled: bool) -> void:
	_auto_reject = enabled
	
## Returns true if the gift should be auto-rejected based on current settings.
func _should_auto_reject(gift: Gift) -> bool:
	if not _is_open:
		return true
	if not metadata.accepts_any_gift and not _gift_matches_desired(gift):
		return true
	return false
	
## Returns true if any of the gift's traits appear in the desired traits list.
func _gift_matches_desired(gift: Gift) -> bool:
	var desired: Array[String] = metadata.desired_traits
	if desired.is_empty():
		return false
	for t in gift.traits:
		if t.gift_trait in desired:
			return true
	return false
