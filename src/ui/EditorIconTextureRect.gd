tool
class_name EditorIconTextureRect
extends TextureRect

# Streamlined TextureRect for using editor icons in plugin UI

var editor = EditorScript.new().get_editor_interface()
var editor_theme = editor.get_base_control().theme

var _EditorIcons: Array = [ ]

func _build_editor_icon_list() -> Array:
	return Array(editor_theme.get_icon_list('EditorIcons'))

func _get_EditorIcons() -> Array:
	if _EditorIcons.size() < 1:
		_EditorIcons = _build_editor_icon_list()
	return _EditorIcons

var EditorIcons setget , _get_EditorIcons

var _icon_name: String = "NavigationMeshInstance" # For now

func _get_icon() -> String:
	return _icon_name

func _set_icon(icon_name) -> void:
	if not editor.get_base_control().theme.has_icon(icon_name, "EditorIcons"):
		return
		push_warning('Unknown icon: %s' % [ icon_name ])
	_icon_name = icon_name
	_update_texture()

export (String) var icon setget _set_icon, _get_icon

# Assumes icon name has been validated
func _update_texture():
	texture = editor.get_base_control().theme.get_icon(_icon_name, "EditorIcons")
	#texture.flags = 0
	texture.property_list_changed_notify()

func _enter_tree() -> void:
	_update_texture()
