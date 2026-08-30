extends GridContainer

static func _get_ap():
	return Util._get_ap()

onready var ipbox = $IP_Box
onready var portbox = $Port_Box
onready var slotbox = $Slot_Box
onready var pwdbox = $Pwd_Box
onready var showpwd = $HBox/ShowPwd
onready var errlbl = $ErrorLabel

func _ready():
	pwdbox.secret = true
	showpwd.connect("toggled", self, "_on_showpwd_toggled")
	_get_ap().creds.connect("updated", self, "refresh_creds")
	refresh_creds(_get_ap().creds)
	_get_ap().connect("connected", self, "_on_ap_connected")
	_get_ap().connect("disconnected", self, "_on_ap_disconnected")
	_get_ap().connect("connect_failed", self, "_on_connect_failed")

func _on_showpwd_toggled(button_pressed):
	pwdbox.secret = not button_pressed
func refresh_creds(creds):
	ipbox.text = creds.ip
	portbox.text = creds.port
	slotbox.text = creds.slot
	pwdbox.text = creds.pwd

func update_connection(status):
	ipbox.editable = not status
	portbox.editable = not status
	slotbox.editable = not status
	pwdbox.editable = not status
func try_connection():
	if _get_ap().is_not_connected():
		errlbl.text = ""
		_get_ap().ap_connect(ipbox.text, portbox.text, slotbox.text, pwdbox.text)
		_connect_signals()

func kill_connection():
	_get_ap().ap_disconnect()

func _connect_signals():
	if not _get_ap().is_connected("connected", self, "_on_connect_success"):
		_get_ap().connect("connected", self, "_on_connect_success")
	if not _get_ap().is_connected("connectionrefused", self, "_on_connect_refused"):
		_get_ap().connect("connectionrefused", self, "_on_connect_refused")
func _disconnect_signals():
	_get_ap().disconnect("connected", self, "_on_connect_success")
	_get_ap().disconnect("connectionrefused", self, "_on_connect_refused")
func _on_connect_success(_conn, _json):
	_disconnect_signals()
	errlbl.text = ""
func _on_connect_refused(_conn, json):
	_disconnect_signals()
	errlbl.text = "ERROR: " + (", ".join(json.get("errors", ["Unknown"])))
func _on_connect_failed(msg):
	errlbl.text = "ERROR: " + msg
func _on_ap_connected(_conn, _json):
	update_connection(true)
func _on_ap_disconnected():
	update_connection(false)
