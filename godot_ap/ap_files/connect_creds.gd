class_name APCredentials extends Node

signal updated(creds)

var ip = "archipelago.gg"
var port = "" setget , get_port

func get_port():
	if port.empty():
		return "38281"
	return port
var slot = ""
var pwd = ""

func read(file):
	var new_strs = [file.get_line(),file.get_line(),file.get_line(),file.get_line()]
	if file.get_error():
		return false
	ip = new_strs[0]
	port = new_strs[1]
	slot = new_strs[2]
	pwd = new_strs[3]
	emit_signal("updated", self)
	return true

func write(file):
	file.store_line(ip)
	file.store_line(port)
	file.store_line(slot)
	file.store_line(pwd)
	return true

func update(nip, nport, nslot, npwd = ""):
	ip = nip
	port = nport
	slot = nslot
	pwd = npwd
	emit_signal("updated", self)

func _to_string():
	return "APCREDS(%s:%s,%s,%s)" % [ip,port,slot,pwd]
