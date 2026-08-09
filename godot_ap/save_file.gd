class_name SaveFile

var aplock = null
var creds = null

func _init():
	aplock = APLock.new()
	creds = APCredentials.new()

func read(file):
	if not aplock.read(file):
		return false
	if not creds.read(file):
		return false
	if file.get_error():
		return false
	return true

func write(file):
	if not aplock.write(file):
		return false
	if not creds.write(file):
		return false
	return true

func clear():
	aplock = APLock.new()
	creds = APCredentials.new()
