extends "res://addons/gut/test.gd"
## Tests for the APLock class.

const LOCK_PATH = "user://ap/_test_ap_lock.dat"


func before_each():
	Util._make_dir_recursive("user://ap/")


## Mock Archipelago connection
func _make_conn(pid, team, slot_name, seed_name):
	var conn = ConnectionInfo.new()
	conn.player_id = pid
	conn.team_id = team
	conn.seed_name = seed_name
	var slots_arr = []
	slots_arr.resize(pid)
	for i in range(slots_arr.size()):
		var slot = NetworkSlot.new()
		slot.name = slot_name
		slot.game = "Test"
		slots_arr[i] = slot
	conn.slots = slots_arr
	return conn


func _make_lock():
	return autofree(APLock.new())


func test_lock_initial_captures():
	var lock = _make_lock()
	var conn = _make_conn(1, 0, "Alice", "seed1")
	assert_eq(lock.lock(conn), [])
	assert_true(lock.valid)
	assert_eq(lock.player_id, 1)
	assert_eq(lock.team_id, 0)
	assert_eq(lock.slot_name, "Alice")
	assert_eq(lock.seed_name, "seed1")


func test_lock_match_repeat_ok():
	var lock = _make_lock()
	var conn = _make_conn(1, 0, "Alice", "seed1")
	lock.lock(conn)
	assert_eq(lock.lock(conn), [])


func test_lock_player_id_mismatch():
	var lock = _make_lock()
	lock.lock(_make_conn(1, 0, "Alice", "seed1"))
	var errs = lock.lock(_make_conn(2, 0, "Alice", "seed1"))
	assert_eq(errs.size(), 1)
	assert_true(errs[0].find("Wrong player_id") >= 0)


func test_lock_team_mismatch():
	var lock = _make_lock()
	lock.lock(_make_conn(1, 0, "Alice", "seed1"))
	var errs = lock.lock(_make_conn(1, 1, "Alice", "seed1"))
	assert_eq(errs.size(), 1)
	assert_true(errs[0].find("Wrong team_id") >= 0)


func test_lock_slot_name_mismatch():
	var lock = _make_lock()
	lock.lock(_make_conn(1, 0, "Alice", "seed1"))
	var errs = lock.lock(_make_conn(1, 0, "Bob", "seed1"))
	assert_eq(errs.size(), 1)
	assert_true(errs[0].find("Wrong slot_name") >= 0)


func test_lock_seed_mismatch():
	var lock = _make_lock()
	lock.lock(_make_conn(1, 0, "Alice", "seed1"))
	var errs = lock.lock(_make_conn(1, 0, "Alice", "seed2"))
	assert_eq(errs.size(), 1)
	assert_true(errs[0].find("Wrong seed_name") >= 0)


func test_multiple_mismatches():
	var lock = _make_lock()
	lock.lock(_make_conn(1, 0, "Alice", "seed1"))
	var errs = lock.lock(_make_conn(2, 1, "Bob", "seed2"))
	assert_eq(errs.size(), 4)


func test_unlock_then_relock():
	var lock = _make_lock()
	lock.lock(_make_conn(1, 0, "Alice", "seed1"))
	lock.unlock()
	assert_false(lock.valid)
	lock.lock(_make_conn(7, 3, "Zoe", "other"))
	assert_true(lock.valid)
	assert_eq(lock.player_id, 7)


func test_write_read_roundtrip():
	var lock = _make_lock()
	assert_eq(lock.lock(_make_conn(1, 0, "Alice", "seed1")), [])
	var f = File.new()
	f.open(LOCK_PATH, File.WRITE)
	lock.write(f)
	f.close()
	var read = _make_lock()
	f = File.new()
	f.open(LOCK_PATH, File.READ)
	assert_true(read.read(f))
	f.close()
	assert_true(read.valid)
	assert_eq(read.player_id, 1)
	assert_eq(read.team_id, 0)
	assert_eq(read.slot_name, "Alice")
	assert_eq(read.seed_name, "seed1")


func test_read_invalid_lock():
	var f = File.new()
	f.open(LOCK_PATH, File.WRITE)
	f.store_8(0)
	f.close()
	var read = _make_lock()
	f = File.new()
	f.open(LOCK_PATH, File.READ)
	assert_true(read.read(f))
	f.close()
	assert_false(read.valid)


func test_to_string():
	assert_eq(_make_lock()._to_string(), "APLOCK()")
	var lock = _make_lock()
	lock.lock(_make_conn(1, 0, "Alice", "seed1"))
	assert_eq(lock._to_string(), "APLOCK(1,0,Alice,seed1)")
