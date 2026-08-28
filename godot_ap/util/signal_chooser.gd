class_name SignalChooser

const _active_choosers = []
const _handler_state = {
	"handlers": []
}

signal chosen(idx)

var _choice = -1
var choices = []

func _choose(idx):
	assert(idx > -1)
	if _choice > -1: return
	_choice = idx
	choices[idx].call_func()
	emit_signal("chosen", idx)
	_deregister(self)

func _reg_signal(sig, idx):
	var h = _SigHandler.new()
	h.chooser = self
	h.idx = idx
	_handler_state.handlers.append(h)
	sig.connect(h, "_on_signal", [], CONNECT_ONESHOT)

func _reg_call(proc, idx):
	proc.call_func()
	_choose(idx)

func register_signal(sig, on_chosen):
	_register(self)
	choices.append(on_chosen)
	_reg_signal(sig, choices.size()-1)
	return self

func register_call(proc, on_chosen):
	_register(self)
	choices.append(on_chosen)
	_reg_call(proc, choices.size()-1)
	return self

func register_multiple(causes, effects):
	assert(causes.size() == effects.size())
	for q in range(causes.size()):
		register_signal(causes[q], effects[q])
	return self

func finished():
	if _choice < 0:
		yield(self, "chosen")
	return _choice

func is_finished():
	return _choice > -1

static func _register(chooser):
	if not (chooser in _active_choosers):
		_active_choosers.append(chooser)

static func _deregister(chooser):
	if chooser in _active_choosers:
		_active_choosers.erase(chooser)

class _SigHandler extends Reference:
	var chooser
	var idx
	func _on_signal():
		chooser._choose(idx)
