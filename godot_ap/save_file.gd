class_name SaveFile
## GodotAP connection & session save file.

## A room lock, preventing the save from connecting to the wrong room once locked.
var aplock = null
## Room connection information.
var creds = null


func _init():
	aplock = APLock.new()
	creds = APCredentials.new()


## Read save from file on disk.
func read(file):
	if not aplock.read(file):
		return false
	if not creds.read(file):
		return false
	if file.get_error():
		return false
	return true


## Write save to file on disk.
func write(file):
	if not aplock.write(file):
		return false
	if not creds.write(file):
		return false
	return true


## Clear currently loaded save information.
func clear():
	aplock = APLock.new()
	creds = APCredentials.new()
