extends "res://addons/gut/test.gd"
## Tests for functionality impacted by casus toggles.

const UTIL = preload("res://godot_ap/util/util.gd")

var _ap


func before_each():
	_ap = Engine.get_main_loop().get_root().get_node("Archipelago")


func after_each():
	# Restore so the engine's default behavior for any stale reads.
	if _ap:
		_ap.casus["DISABLE_BITWISE_OPERATIONS"] = false


## Enables all casus toggles
func _casus_on():
	_ap.casus["DISABLE_BITWISE_OPERATIONS"] = true


## Disables all casus toggles
func _casus_off():
	_ap.casus["DISABLE_BITWISE_OPERATIONS"] = false


func test_casus_defaults():
	# after_each restored the default
	assert_false(UTIL._casus("DISABLE_BITWISE_OPERATIONS"))
	# include keys that don't exist
	assert_false(UTIL._casus("NONEXISTENT_KEY"))


func test_has_flag_known_bits():
	_casus_off()
	assert_eq(UTIL.has_flag(5, 0), true)
	assert_eq(UTIL.has_flag(5, 1), false)
	assert_eq(UTIL.has_flag(5, 2), true)
	_casus_on()
	assert_eq(UTIL.has_flag(5, 0), true)
	assert_eq(UTIL.has_flag(5, 1), false)
	assert_eq(UTIL.has_flag(5, 2), true)


func test_has_flag_parity():
	var flags = [0, 1, 127, 255, 256]
	var bits = range(9)
	_casus_off()
	var native = _collect_has_flag(flags, bits)
	_casus_on()
	var gated = _collect_has_flag(flags, bits)
	assert_eq_deep(native, gated)


func _collect_has_flag(flags, bits):
	var out = []
	for f in flags:
		for b in bits:
			out.append(UTIL.has_flag(f, b))
	return out


func test_unsigned_to_signed_known():
	var vals = [0, 127, 128, 255, 256, 511]
	var expected = [0, 127, -128, -1, 0, -1]
	_casus_off()
	for i in range(vals.size()):
		assert_eq(UTIL.unsigned_to_signed_8(vals[i]), expected[i])
	_casus_on()
	for i in range(vals.size()):
		assert_eq(UTIL.unsigned_to_signed_8(vals[i]), expected[i])
	assert_eq(UTIL.unsigned_to_signed_16(65535), -1)
	assert_eq(UTIL.unsigned_to_signed_32(2147483648), -2147483648)


func test_unsigned_to_signed_8_parity():
	_casus_off()
	var native = []
	for u in range(256):
		native.append(UTIL.unsigned_to_signed_8(u))
	_casus_on()
	var gated = []
	for u in range(256):
		gated.append(UTIL.unsigned_to_signed_8(u))
	assert_eq_deep(native, gated)


func test_unsigned_to_signed_16_parity():
	var vals = [0, 1, 32767, 32768, 32769, 65534, 65535]
	_casus_off()
	var native = []
	for u in vals:
		native.append(UTIL.unsigned_to_signed_16(u))
	_casus_on()
	var gated = []
	for u in vals:
		gated.append(UTIL.unsigned_to_signed_16(u))
	assert_eq_deep(native, gated)


func test_unsigned_to_signed_32_parity():
	var vals = [0, 1, 2147483647, 2147483648, 3221225472, 4294967295]
	_casus_off()
	var native = []
	for u in vals:
		native.append(UTIL.unsigned_to_signed_32(u))
	_casus_on()
	var gated = []
	for u in vals:
		gated.append(UTIL.unsigned_to_signed_32(u))
	assert_eq_deep(native, gated)


func test_bit_count_known():
	var vals = [0, 1, 3, 255, 256]
	var expected = [0, 1, 2, 8, 1]
	_casus_off()
	for i in range(vals.size()):
		assert_eq(UTIL.bit_count(vals[i]), expected[i])
	_casus_on()
	for i in range(vals.size()):
		assert_eq(UTIL.bit_count(vals[i]), expected[i])


func test_bit_count_parity():
	var vals = [0, 1, 3, 255, 256, 65535, 4294967295]
	_casus_off()
	var native = []
	for v in vals:
		native.append(UTIL.bit_count(v))
	_casus_on()
	var gated = []
	for v in vals:
		gated.append(UTIL.bit_count(v))
	assert_eq_deep(native, gated)

#endregion
