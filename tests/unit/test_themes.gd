extends "res://addons/gut/test.gd"
## Tests for the selectable GUI themes.

const THEME_PATHS = [
	"ui/themes/dark_theme.tres",
	"ui/themes/light_theme.tres",
	"ui/themes/aura_theme.tres",
	"ui/themes/win98_theme.tres",
]
const NEW_THEME_PATHS = ["ui/themes/aura_theme.tres", "ui/themes/win98_theme.tres"]

## Styleboxes every new theme must define, so no control silently falls back to
## the project's default dark theme.
const REQUIRED_STYLES = {
	"Button": ["normal", "hover", "pressed", "disabled", "focus"],
	"CheckBox": ["normal", "hover", "pressed", "disabled", "focus"],
	"CheckButton": ["normal", "hover", "pressed", "disabled", "focus"],
	"LineEdit": ["normal", "focus", "read_only"],
	"Panel": ["panel"],
	"PanelContainer": ["panel"],
	"PopupMenu": ["panel", "hover", "separator"],
	"TabContainer":
	[
		"panel",
		"tab_selected",
		"tab_unselected",
		"tab_hovered",
		"tab_disabled",
		"tab_focus",
		"tabbar_background",
	],
	"TooltipPanel": ["panel"],
	"HScrollBar": ["scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"],
	"VScrollBar": ["scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"],
	"Console_BG": ["panel"],
	"Console_Bar": ["normal", "focus"],
	"Console_Bar_Front": ["normal"],
	"Console_Bar_Back": ["normal"],
}

const REQUIRED_COLORS = {
	"Button": ["font_color", "font_disabled_color", "font_hover_color", "font_pressed_color"],
	"Label": ["font_color"],
	"LineEdit": ["font_color", "selection_color", "caret_color"],
	"Console_Label":
	[
		"font_color",
		"rich_black",
		"rich_blue",
		"rich_cyan",
		"rich_gold",
		"rich_green",
		"rich_magenta",
		"rich_orange",
		"rich_plum",
		"rich_red",
		"rich_salmon",
		"rich_slateblue",
		"rich_white",
		"rich_yellow",
	],
	"Console_AutofillBar": ["bg_color", "font_color", "sel_color"],
	"PopupMenu": ["font_color", "font_hover_color"],
	"TabContainer": ["font_selected_color", "font_unselected_color", "font_hovered_color"],
}

const REQUIRED_FONTS = {
	"Button": ["font"],
	"CheckBox": ["font"],
	"Label": ["font"],
	"LineEdit": ["font"],
	"Console_Label": ["font"],
	"TabContainer": ["font"],
}


func _load_theme(path):
	return Util._ap_load(path)


func _instance_settings():
	return load("res://godot_ap/ui/settings_tab.tscn").instance()


func test_all_theme_files_load():
	for path in THEME_PATHS:
		assert_true(_load_theme(path) is Theme, "%s must load as a Theme" % path)


func test_new_themes_define_required_styles():
	for path in NEW_THEME_PATHS:
		var theme = _load_theme(path)
		for theme_type in REQUIRED_STYLES:
			for style_name in REQUIRED_STYLES[theme_type]:
				assert_true(
					theme.has_stylebox(style_name, theme_type),
					"%s missing style %s/styles/%s" % [path, theme_type, style_name]
				)


func test_new_themes_define_required_colors():
	for path in NEW_THEME_PATHS:
		var theme = _load_theme(path)
		for theme_type in REQUIRED_COLORS:
			for color_name in REQUIRED_COLORS[theme_type]:
				assert_true(
					theme.has_color(color_name, theme_type),
					"%s missing color %s/colors/%s" % [path, theme_type, color_name]
				)


func test_new_themes_define_required_fonts():
	for path in NEW_THEME_PATHS:
		var theme = _load_theme(path)
		for theme_type in REQUIRED_FONTS:
			for font_name in REQUIRED_FONTS[theme_type]:
				assert_true(
					theme.has_font(font_name, theme_type),
					"%s missing font %s/fonts/%s" % [path, theme_type, font_name]
				)


func test_settings_theme_paths_resolve():
	var root = _instance_settings()
	var mgr = root.get_node("Margin/Tabs/Theme")
	assert_true(mgr is ThemeManager)
	assert_eq(mgr.themes.size(), 4)
	for themebox_path in mgr.themes:
		var box = mgr.get_node(themebox_path)
		assert_true(box is ThemeBox, "%s must be a ThemeBox" % themebox_path)
		var resolved = Util._ap_base_dir().plus_file(box.target_theme_path)
		assert_true(ResourceLoader.exists(resolved), "%s must exist" % box.target_theme_path)
		assert_true(load(resolved) is Theme, "%s must load as a Theme" % box.target_theme_path)
	root.free()


func test_settings_theme_boxes_share_a_button_group():
	var root = _instance_settings()
	var mgr = root.get_node("Margin/Tabs/Theme")
	var group = null
	for themebox_path in mgr.themes:
		var box = mgr.get_node(themebox_path)
		assert_not_null(box.group, "%s must belong to a ButtonGroup" % themebox_path)
		if group == null:
			group = box.group
		assert_eq(box.group, group, "%s must share the selector group" % themebox_path)
	root.free()


func test_default_theme_is_dark():
	var root = _instance_settings()
	var mgr = root.get_node("Margin/Tabs/Theme")
	var def = mgr.get_node(mgr.default_theme)
	assert_eq(def.name, "DarkTheme")
	assert_eq(def.target_theme_path, "ui/themes/dark_theme.tres")
	root.free()
