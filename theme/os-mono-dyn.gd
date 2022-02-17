class_name OSMonospaceFont
extends DynamicFont
tool

# 
# Dynamically loads current editor font from filesystem.
# 
# HAHA NEVERMIND THIS WONT WORK IN 3.x
# https://github.com/godotengine/godot/issues/27106
#

var interface: EditorInterface = EditorScript.new().get_editor_interface()
var editor_settings := interface.get_editor_settings()

var font_setting_path: String = 'interface/editor/code_font' setget _set_font_setting_path
func _set_font_setting_path(new_path: String) -> void:
	if not editor_settings.has_setting(new_path):
		push_error('Editor setting not found at path: %s' % [ new_path ])
	font_setting_path = new_path
	_update_font_path()
	
func _update_font_path():
	_font_path = editor_settings.get_setting(font_setting_path)

var _font_path: String
func _get_font_path() -> String:
	return _font_path

func _init() -> void:
	_update_font_path()
	
func update() -> void:
	print('Attempting update of font data from configured path: <%s>' % [ _font_path ])
	var file := File.new()
	
	if not (_font_path and file.file_exists(_font_path)):
		push_warning('OSMonospaceFont.update >> Failed to find font at path: <%s>' % [ 
				_font_path if typeof(_font_path) == TYPE_STRING and _font_path.length() > 0 else "NIL"
			])
		
	var data = load(_font_path)
	if is_instance_valid(data):
		font_data = data
		font_data.emit_changed()
		emit_signal("changed")
		
	else:
		push_error('OSMonospaceFont.update >> No valid instance return from loading resource: <%s>')
		
	
