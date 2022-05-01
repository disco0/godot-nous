tool
class_name TrenchBroomGameFolder


const MODELS_LEAF     := 'models'
const MODELS_TEX_LEAF := MODELS_LEAF + '/textures'

var models_dir:     String setget, get_models_dir
var models_tex_dir: String setget, get_models_tex_dir
var textures_dir:   String setget, get_textures_dir
var path:           String setget _set_path


func _init(game_folder_path: String):
	if not OS.has_feature("editor"): return
	var dir := Directory.new()
	if game_folder_path == null or game_folder_path == "" or (Engine.editor_hint and not dir.dir_exists(game_folder_path + "/")):
		push_error('Invalid trenchbroom game base directory <%s>' % [ game_folder_path ])
		return

	path = ProjectSettings.globalize_path(game_folder_path.simplify_path())
	if not dir.dir_exists(path):
		print('Creating output directory: <%s>' % [ path ])
		var mkdir_err := dir.make_dir_recursive(path)
		if mkdir_err != OK:
			print('  -> Failed with error: %s' % [ mkdir_err ])
			push_error('Error initializing game folder: %s <%s>' % [ mkdir_err, path ])


func usemtl_path(tex_leaf: String) -> String:
	return MODELS_TEX_LEAF.plus_file(tex_leaf).trim_suffix('.png')


func global_to_usemtl(path) -> String:
	return path_to(path)


func usemtl_to_global(usemtl_path: String) -> String:
	return self.models_tex_dir.plus_file(usemtl_path)


# Intended for usemtl
func path_to(child_path: String) -> String:
	child_path = ProjectSettings.globalize_path(child_path.simplify_path())
	if child_path.begins_with(path):
		return child_path.trim_prefix(path + '/')
	else:
		push_error('child_path <%s> is not rooted in defined path.' % [ child_path ])
		return ''


func _to_string() -> String:
	if typeof(path) != TYPE_STRING or path.empty():
		push_error('TrenchBroomGameFolder._to_string >> path not defined, or empty string')

	return path


func get_textures_dir() -> String:
	return path.plus_file('textures')


func get_models_tex_dir() -> String:
	return path.plus_file(MODELS_TEX_LEAF)


func get_models_dir() -> String:
	return path.plus_file('models')


func _set_path(value: String) -> void:
	path = ProjectSettings.globalize_path(value.simplify_path())
