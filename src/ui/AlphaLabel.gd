class_name AlphaLabel
extends Label
tool

#
# Extended form of Label that updates the font color with transparent variation
#

var opacity: float = 0.5

var editor = EditorScript.new().get_editor_interface()
var editor_theme = editor.get_base_control().theme

var godot_theme: Theme
var base_font_color: Color



func _get_font_color() -> Color:
	return base_font_color * Color(1, 1, 1, opacity)

var font_color: Color setget, _get_font_color

func _enter_tree() -> void:
	godot_theme =  EditorScript.new().get_editor_interface().get_base_control().theme
	base_font_color = godot_theme.get_color('font_color', 'Label')
	add_color_override('font_color', _get_font_color())
