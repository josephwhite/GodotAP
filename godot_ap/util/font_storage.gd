class_name FontStorage

func _init(_base_font):
	populate(_base_font)

func populate(_base_font):
	base_font = _base_font
	bold_font = Util.font_mod(_get_font_for_mod(), true, false)
	italic_font = Util.font_mod(_get_font_for_mod(), false, true)
	bold_italic_font = Util.font_mod(_get_font_for_mod(), true, true)

func get_font(bold, italic):
	if not italic:
		if not bold:
			return base_font
		else:
			return bold_font
	else:
		if not bold:
			return italic_font
		else:
			return bold_italic_font

func _get_font_for_mod():
	return base_font.duplicate() if base_font else null

var base_font
var bold_font
var italic_font
var bold_italic_font
