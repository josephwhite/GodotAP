extends "res://addons/gut/test.gd"

const FAKE = preload("res://tests/fixtures/fake_socket.gd")

var _ap
## Logged messages
var _logged = []
## Fired count of `on_tag_change` signal
var _tag_changes = []
## Fired count of the unconditional `ConnectionInfo.bounce` signal
var _bounced = 0


func _setup_conn():
	var conn = ConnectionInfo.new()
	conn.slot_locations = {}
	conn.connect("bounce", self, "_on_bounce")
	_ap.conn = conn


## Connection with a resolvable player, for the send_* bounce paths.
func _setup_conn_with_player():
	_setup_conn()
	var plyr = NetworkPlayer.new()
	plyr.name = "Alice"
	_ap.conn.players = [plyr]
	_ap.conn.player_id = 1


func _setup_fake_socket():
	_ap._socket = FAKE.FakeSocket.new()


func _last_sent():
	if _ap._socket.peer.sent.size() == 0:
		return {}
	return parse_json(_ap._socket.peer.sent[_ap._socket.peer.sent.size() - 1])[0]


func _receive_from_server(s):
	_ap._socket.peer.incoming.append(s)
	_ap._on_ws_data()


func _on_logged(msg):
	_logged.append(msg)


func _on_tag_changed():
	_tag_changes += 1


func _on_deathlink(source, cause, _json):
	_logged.append("deathlink:%s:%s" % [source, cause])


func _on_traplink(source, trap_name, _json):
	_logged.append("traplink:%s:%s" % [source, trap_name])


func _on_bounce(_json):
	_bounced += 1


func before_each():
	_ap = Engine.get_main_loop().get_root().get_node("Archipelago")
	_logged = []
	_tag_changes = 0
	_bounced = 0
	# Hooks for testing
	_ap.connect("_logged_message", self, "_on_logged")
	_ap.connect("on_tag_change", self, "_on_tag_changed")
	_setup_fake_socket()


func after_each():
	# Disconnect test hooks
	if _ap.is_connected("_logged_message", self, "_on_logged"):
		_ap.disconnect("_logged_message", self, "_on_logged")
	if _ap.is_connected("on_tag_change", self, "_on_tag_changed"):
		_ap.disconnect("on_tag_change", self, "_on_tag_changed")
	_ap._queue_reconnect = false
	_ap._set_status(0)  # APStatus.DISCONNECTED
	if _ap._tags_update_pending:
		_ap._flush_tags_update()
	_ap.AP_GAME_TAGS.clear()
	_ap._is_nongame_client = false
	_ap.deathlink_group = ""
	_ap.traplink_group = ""
	_ap.last_sent_deathlink_time = 0.0
	_ap.last_sent_traplink_time = 0.0
	_ap.TRAP_LINK_ALIASES = {}
	_ap.conn = null
	_ap._socket = null


#region Default tags


func test_default_tags():
	assert_eq_deep(_ap.AP_GAME_TAGS, [])


func test_deathlink_default_not_enabled():
	assert_false(_ap.is_deathlink())


func test_traplink_default_not_enabled():
	assert_false(_ap.is_traplink())


func test_deathlink_default_tag():
	assert_eq(_ap.get_deathlink_tag(), "DeathLink")


func test_deathlink_default_group_is_empty():
	assert_eq(_ap.deathlink_group, "")


func test_traplink_default_tag():
	assert_eq(_ap.get_traplink_tag(), "TrapLink")


func test_traplink_default_group_is_empty():
	assert_eq(_ap.traplink_group, "")


func test_nongame_false_by_default():
	assert_false(_ap._check_nongame_client())


#endregion

#region Tag change


func test_deathlink_group_change():
	assert_eq(_ap.get_deathlink_tag(), "DeathLink")
	_ap.set_deathlink_group("g2")
	assert_eq(_ap.get_deathlink_tag(), "DeathLinkg2")
	# Setting DeathLink Group does not imply DeathLink is active
	assert_false(_ap.is_deathlink())


func test_traplink_group_change():
	assert_eq(_ap.get_traplink_tag(), "TrapLink")
	_ap.set_traplink_group("g2")
	assert_eq(_ap.get_traplink_tag(), "TrapLinkg2")
	# Setting TrapLink Group does not imply TrapLink is active
	assert_false(_ap.is_traplink())


## Changing the group while TrapLink is live re-tags the link.
func test_traplink_group_change_while_enabled():
	_ap.set_traplink(true)
	assert_true(_ap.has_tag("TrapLink"))
	_ap.set_traplink_group("g2")
	assert_false(_ap.has_tag("TrapLink"))
	assert_true(_ap.has_tag("TrapLinkg2"))
	assert_true(_ap.is_traplink())


## Re-setting the same group is a no-op and leaves the link alone.
func test_traplink_group_change_same_value_noop():
	_ap.set_traplink_group("g2")
	_ap.set_traplink(true)
	var changes = _tag_changes
	_ap.set_traplink_group("g2")
	assert_eq(_ap.get_traplink_group(), "g2")
	assert_true(_ap.is_traplink())
	assert_eq(_tag_changes, changes)


## Based on bug where calling set_tags twice sequentially crashes the game
func test_deathlink_and_traplink_same_frame():
	assert_false(_ap.is_deathlink())
	assert_false(_ap.is_traplink())
	_ap.set_deathlink(true)
	_ap.set_traplink(true)
	assert_true(_ap.is_deathlink())
	assert_true(_ap.is_traplink())
	# Ensure tags were applied to AP_GAME_TAGS
	var death_count = 0
	var trap_count = 0
	for tag in _ap.AP_GAME_TAGS:
		if tag == _ap.get_deathlink_tag():
			death_count += 1
		elif tag == _ap.get_traplink_tag():
			trap_count += 1
	assert_eq(death_count, 1)
	assert_eq(trap_count, 1)


#endregion

#region Nongame client


## Use Network Protocol reference as confirmed nongame tags
func test_nongame_status_by_confirmed_tags():
	# Nongame
	for tag in ["TextOnly", "Tracker", "HintGame"]:
		_ap.set_tag(tag)
		assert_true(_ap._check_nongame_client(), "tag %s marks nongame" % tag)
		_ap.set_tag(tag, false)
	# Is (or can be) a game
	for tag in [_ap.get_deathlink_tag(), _ap.get_traplink_tag(), "NoText"]:
		_ap.set_tag(tag)
		assert_false(_ap._check_nongame_client(), "tag %s keeps nongame false" % tag)
		_ap.set_tag(tag, false)


## A grouped link tag is still not a nongame marker.
func test_nongame_false_for_grouped_link_tags():
	for tag in ["DeathLinkd1", "TrapLinkt1"]:
		_ap.set_tag(tag)
		assert_false(_ap._check_nongame_client(), "tag %s keeps nongame false" % tag)
		_ap.set_tag(tag, false)


## Nongame status reliant on specific tag prescence
func test_nongame_false_after_tag_removal():
	_ap.set_tag("HintGame")
	_ap.set_tag("HintGame", false)
	assert_false(_ap._check_nongame_client())


func test_collect_blocked_when_hintgame():
	_setup_conn()
	_ap.set_tag("HintGame")
	assert_false(_ap.collect_location(1))
	assert_eq(_ap.collect_locations([1]), 0)
	assert_eq(_ap._socket.peer.sent.size(), 0)
	assert_eq(_logged, [])


func test_collect_works_after_removing_hintgame():
	_setup_conn()
	_ap.conn.slot_locations[1] = false
	_ap.set_tag("HintGame")
	_ap.set_tag("HintGame", false)
	assert_true(_ap.collect_location(1))
	var frame = _last_sent()
	assert_eq(frame["cmd"], "LocationChecks")
	assert_eq(frame["locations"], [1.0])


#endregion

#region Tag mutation APIs


func test_notext_roundtrip():
	_ap.set_tag("NoText")
	assert_true(_ap.has_tag("NoText"))
	assert_false(_ap._check_nongame_client())
	_ap.set_tag("NoText", false)
	assert_false(_ap.has_tag("NoText"))


func test_set_tags_overwrites():
	_ap.set_tags(["NoText", "HintGame"])
	assert_eq_deep(_ap.AP_GAME_TAGS, ["NoText", "HintGame"])
	assert_true(_ap._check_nongame_client())


func test_set_misc_tags_preserves_active_links():
	_ap.set_deathlink(true)
	_ap.set_traplink(true)
	_ap.set_misc_tags(["TextOnly"])
	assert_true(_ap.has_tag("TextOnly"))
	assert_true(_ap.has_tag(_ap.get_deathlink_tag()))
	assert_true(_ap.has_tag(_ap.get_traplink_tag()))
	assert_true(_ap._check_nongame_client())


func test_set_misc_tags_preserves_group_variant():
	_ap.set_deathlink_group("g2")
	_ap.set_deathlink(true)
	_ap.set_misc_tags(["TextOnly"])
	assert_true(_ap.has_tag("DeathLinkg2"))
	assert_false(_ap.has_tag("DeathLink"))
	assert_true(_ap.has_tag("TextOnly"))


## Grouped DeathLink and TrapLink are both preserved by a misc-tag overwrite.
func test_set_misc_tags_preserves_both_group_variants():
	_ap.set_deathlink_group("d1")
	_ap.set_traplink_group("t1")
	_ap.set_deathlink(true)
	_ap.set_traplink(true)
	_ap.set_misc_tags(["TextOnly"])
	assert_true(_ap.has_tag("DeathLinkd1"))
	assert_true(_ap.has_tag("TrapLinkt1"))
	assert_false(_ap.has_tag("DeathLink"))
	assert_false(_ap.has_tag("TrapLink"))
	assert_true(_ap.has_tag("TextOnly"))


func test_set_misc_tags_erases_inactive_links():
	_ap.set_misc_tags(["TextOnly"])
	assert_false(_ap.has_tag(_ap.get_deathlink_tag()))
	assert_false(_ap.has_tag(_ap.get_traplink_tag()))
	assert_eq_deep(_ap.AP_GAME_TAGS, ["TextOnly"])
	_ap.set_misc_tags([])
	assert_eq(_ap.AP_GAME_TAGS.size(), 0)


## Clearing the group while the link is live re-tags it to the bare variant,
## so set_misc_tags then preserves that bare tag rather than dropping it.
func test_group_cleared_while_enabled_falls_back_to_bare_tag():
	_ap.set_deathlink_group("d1")
	_ap.set_traplink_group("t1")
	_ap.set_deathlink(true)
	_ap.set_traplink(true)
	_ap.set_deathlink_group("")
	_ap.set_traplink_group("")
	assert_false(_ap.has_tag("DeathLinkd1"))
	assert_false(_ap.has_tag("TrapLinkt1"))
	assert_true(_ap.is_deathlink())
	assert_true(_ap.is_traplink())
	_ap.set_misc_tags(["TextOnly"])
	assert_true(_ap.has_tag("DeathLink"))
	assert_true(_ap.has_tag("TrapLink"))
	assert_true(_ap.has_tag("TextOnly"))


## Disabling the links first means clearing the group leaves nothing to preserve.
func test_set_misc_tags_erases_grouped_variants_when_links_off():
	_ap.set_deathlink_group("d1")
	_ap.set_traplink_group("t1")
	_ap.set_deathlink(true)
	_ap.set_traplink(true)
	_ap.set_deathlink(false)
	_ap.set_traplink(false)
	_ap.set_deathlink_group("")
	_ap.set_traplink_group("")
	_ap.set_misc_tags(["TextOnly"])
	assert_eq_deep(_ap.AP_GAME_TAGS, ["TextOnly"])


#endregion

#region Signal changes


func test_on_tag_change_emitted_per_mutation():
	assert_eq(_tag_changes, 0)
	_ap.set_tag("NoText")
	assert_eq(_tag_changes, 1)
	_ap.set_tag("NoText", false)
	assert_eq(_tag_changes, 2)


func test_set_tag_unchanged_no_signal():
	_ap.set_tag("NoText")
	var changes = _tag_changes
	_ap.set_tag("NoText")
	_ap.set_tags(["NoText"])
	assert_eq(_tag_changes, changes)


#endregion

#region Coalesced ConnectUpdate wire send


## Setting two links without crashing
func test_tags_coalesce_into_one_pending_flush():
	_ap._tags_update_pending = false
	_ap.set_deathlink(true)
	_ap.set_traplink(true)
	assert_true(_ap._tags_update_pending)
	yield(get_tree(), "idle_frame")
	assert_false(_ap._tags_update_pending)
	assert_true(_ap.is_deathlink())
	assert_true(_ap.is_traplink())


func test_connectupdate_sent_once_when_playing():
	# Drain any stale deferred tag flush from prior tests while still DISCONNECTED.
	yield(get_tree(), "idle_frame")
	_ap._set_status(4)  # APStatus.PLAYING
	_ap.set_tag("NoText")
	_ap.set_tag("HintGame")
	assert_true(_ap._tags_update_pending)
	yield(get_tree(), "idle_frame")
	assert_eq(_ap._socket.peer.sent.size(), 1)
	assert_false(_ap._tags_update_pending)
	var frame = _last_sent()
	assert_eq(frame["cmd"], "ConnectUpdate")
	assert_eq_deep(frame["tags"], ["NoText", "HintGame"])


func test_connectupdate_not_sent_when_not_playing():
	_ap.set_tag("NoText")
	assert_true(_ap._tags_update_pending)
	yield(get_tree(), "idle_frame")
	assert_eq(_ap._socket.peer.sent.size(), 0)


func test_transient_removal_flushes_final_tags():
	# Drain any stale deferred tag flush from prior tests while still DISCONNECTED.
	yield(get_tree(), "idle_frame")
	_ap._set_status(4)  # APStatus.PLAYING
	_ap.set_deathlink(true)
	_ap.set_traplink(true)
	_ap.set_deathlink(false)
	yield(get_tree(), "idle_frame")
	assert_eq(_ap._socket.peer.sent.size(), 1)
	var frame = _last_sent()
	assert_eq(frame["cmd"], "ConnectUpdate")
	assert_eq_deep(frame["tags"], [_ap.get_traplink_tag()])


#endregion

#region Bounce - Untagged


## Even if no tags are present, we still fire a signal.
func test_bounced_signal_fires_for_untagged_packet():
	_setup_conn()
	_receive_from_server(
		'{"cmd":"Bounced","tags":[],"data":{"time":10.0,"source":"Eve","cause":"nope"}}'
	)
	assert_eq(_bounced, 1)


func test_bounce_untagged_fires_bounce_but_no_derived():
	_setup_conn()
	_ap.conn.connect("deathlink", self, "_on_deathlink")
	_ap.conn.connect("traplink", self, "_on_traplink")
	_ap.set_deathlink(true)
	_ap.set_traplink(true)
	_receive_from_server(
		'{"cmd":"Bounced","tags":[],"data":{"time":10.0,"source":"Eve","cause":"nope"}}'
	)
	assert_eq(_logged, [])
	assert_eq(_bounced, 1)


#endregion

#region Bounce - DeathLink/TrapLink Recieves


func test_bounce_deathlink_signal():
	_setup_conn()
	_ap.conn.connect("deathlink", self, "_on_deathlink")
	_ap.set_deathlink(true)
	_receive_from_server(
		'{"cmd":"Bounced","tags":["DeathLink"],"data":{"time":10.0,"source":"Alice","cause":"boom"}}'
	)
	assert_eq(_logged, ["deathlink:Alice:boom"])
	assert_eq(_bounced, 1)


func test_bounce_traplink_signal_with_alias():
	_setup_conn()
	_ap.conn.connect("traplink", self, "_on_traplink")
	_ap.set_traplink(true)
	_ap.TRAP_LINK_ALIASES = {"foo": "Illusory Wall"}
	_receive_from_server(
		'{"cmd":"Bounced","tags":["TrapLink"],"data":{"time":10.0,"source":"Bob","trap_name":"foo"}}'
	)
	assert_eq(_logged, ["traplink:Bob:Illusory Wall"])
	assert_eq(_bounced, 1)


## Timestamp check
func test_bounce_self_deathlink_skipped():
	_setup_conn()
	_ap.conn.connect("deathlink", self, "_on_deathlink")
	_ap.set_deathlink(true)
	_ap.last_sent_deathlink_time = 10.0
	_receive_from_server(
		'{"cmd":"Bounced","tags":["DeathLink"],"data":{"time":10.0,"source":"Alice","cause":"boom"}}'
	)
	assert_eq(_logged, [])
	assert_eq(_bounced, 1)


## Timestamp check
func test_bounce_self_traplink_skipped():
	_setup_conn()
	_ap.conn.connect("traplink", self, "_on_traplink")
	_ap.set_traplink(true)
	_ap.last_sent_traplink_time = 10.0
	_receive_from_server(
		'{"cmd":"Bounced","tags":["TrapLink"],"data":{"time":10.0,"source":"Bob","trap_name":"trap"}}'
	)
	assert_eq(_logged, [])
	assert_eq(_bounced, 1)


## What an unfortunate thing to happen.
func test_bounce_deathlink_fires_with_link_off():
	_setup_conn()
	_ap.conn.connect("deathlink", self, "_on_deathlink")
	_receive_from_server(
		'{"cmd":"Bounced","tags":["DeathLink"],"data":{"time":10.0,"source":"Alice","cause":"boom"}}'
	)
	assert_eq(_logged, ["deathlink:Alice:boom"])
	assert_eq(_bounced, 1)


func test_bounce_deathlink_group_variant():
	_setup_conn()
	_ap.conn.connect("deathlink", self, "_on_deathlink")
	_ap.set_deathlink_group("g2")
	_ap.set_deathlink(true)
	_receive_from_server(
		'{"cmd":"Bounced","tags":["DeathLinkg2"],"data":{"time":10.0,"source":"Alice","cause":"boom"}}'
	)
	assert_eq(_logged, ["deathlink:Alice:boom"])
	assert_eq(_bounced, 1)


func test_bounce_wrong_group_variant_ignored():
	_setup_conn()
	_ap.conn.connect("deathlink", self, "_on_deathlink")
	_ap.set_deathlink_group("g2")
	_receive_from_server(
		'{"cmd":"Bounced","tags":["DeathLink"],"data":{"time":10.0,"source":"Alice","cause":"boom"}}'
	)
	assert_eq(_logged, [])
	assert_eq(_bounced, 1)


func test_bounce_traplink_group_variant():
	_setup_conn()
	_ap.conn.connect("traplink", self, "_on_traplink")
	_ap.set_traplink_group("g2")
	_ap.set_traplink(true)
	_receive_from_server(
		'{"cmd":"Bounced","tags":["TrapLinkg2"],"data":{"time":10.0,"source":"Bob","trap_name":"trap"}}'
	)
	assert_eq(_logged, ["traplink:Bob:trap"])
	assert_eq(_bounced, 1)


## A grouped TrapLink tag does not match an ungrouped bounce.
func test_bounce_traplink_wrong_group_variant_ignored():
	_setup_conn()
	_ap.conn.connect("traplink", self, "_on_traplink")
	_ap.set_traplink_group("g2")
	_receive_from_server(
		'{"cmd":"Bounced","tags":["TrapLink"],"data":{"time":10.0,"source":"Bob","trap_name":"trap"}}'
	)
	assert_eq(_logged, [])
	assert_eq(_bounced, 1)


## Grouped TrapLink bounces still resolve aliases.
func test_bounce_traplink_group_variant_with_alias():
	_setup_conn()
	_ap.conn.connect("traplink", self, "_on_traplink")
	_ap.set_traplink_group("g2")
	_ap.set_traplink(true)
	_ap.TRAP_LINK_ALIASES = {"foo": "Illusory Wall"}
	_receive_from_server(
		'{"cmd":"Bounced","tags":["TrapLinkg2"],"data":{"time":10.0,"source":"Bob","trap_name":"foo"}}'
	)
	assert_eq(_logged, ["traplink:Bob:Illusory Wall"])
	assert_eq(_bounced, 1)


## Groups are independent: a grouped TrapLink still ignores grouped DeathLink.
func test_bounce_traplink_group_ignores_grouped_deathlink():
	_setup_conn()
	_ap.conn.connect("deathlink", self, "_on_deathlink")
	_ap.conn.connect("traplink", self, "_on_traplink")
	_ap.set_traplink_group("g2")
	_receive_from_server(
		'{"cmd":"Bounced","tags":["DeathLinkg2"],"data":{"time":10.0,"source":"Alice","cause":"boom"}}'
	)
	assert_eq(_logged, [])
	assert_eq(_bounced, 1)


#endregion

#region Bounce - DeathLink/TrapLink Sends


func test_send_traplink_tags_bounce_with_current_tag():
	_setup_conn_with_player()
	_ap.set_traplink(true)
	_ap.conn.send_traplink("trap")
	var frame = _last_sent()
	assert_eq(frame["cmd"], "Bounce")
	assert_eq_deep(frame["tags"], ["TrapLink"])
	assert_eq(frame["data"]["trap_name"], "trap")
	assert_eq(frame["data"]["source"], "Alice")


## The outbound Bounce must carry the grouped tag, not the bare literal.
func test_send_traplink_tags_bounce_with_grouped_tag():
	_setup_conn_with_player()
	_ap.set_traplink_group("g2")
	_ap.set_traplink(true)
	_ap.conn.send_traplink("trap")
	var frame = _last_sent()
	assert_eq(frame["cmd"], "Bounce")
	assert_eq_deep(frame["tags"], ["TrapLinkg2"])


func test_send_deathlink_tags_bounce_with_grouped_tag():
	_setup_conn_with_player()
	_ap.set_deathlink_group("d1")
	_ap.set_deathlink(true)
	_ap.conn.send_deathlink("boom")
	var frame = _last_sent()
	assert_eq(frame["cmd"], "Bounce")
	assert_eq_deep(frame["tags"], ["DeathLinkd1"])


## Sending without the link enabled must not put anything on the wire.
func test_send_traplink_blocked_when_grouped_link_off():
	_setup_conn_with_player()
	_ap.set_traplink_group("g2")
	_ap.conn.send_traplink("trap")
	assert_eq(_ap._socket.peer.sent.size(), 0)

#endregion

#region Bounce - Custom Links/Tags

func test_knockbacklink_send():
	_setup_conn_with_player()
	_ap.set_tag("KnockbackLink")
	var knockback = Vector3(10, 5, 1)
	var cmd = {"data": {}}
	cmd["data"]["source"] = _ap.conn.get_player_name(-1, false)
	cmd["data"]["source"] = ""
	cmd["data"]["time"] = OS.get_unix_time()
	cmd["data"]["value"] = {"x": knockback.x, "y": knockback.y, "z": knockback.z}
	_ap.conn.send_bounce(cmd, [], [], ["KnockbackLink"])
	# Did we send?
	var frame = _last_sent()
	assert_eq(frame["cmd"], "Bounce")
	assert_eq_deep(frame["tags"], ["KnockbackLink"])


#endregion
