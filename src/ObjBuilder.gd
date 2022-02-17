class_name ObjBuilder
extends Node
tool

var dprint := CSquadUtil.dprint_for(self)


# Path for in-game generation
const OBJ_EXPORT_BASE_DIR: String = 'user://obj-gen'
# Default path for in editor (getter used otherwise)
const GAME_FOLDER_EXPORT_BASE_DIR: String = 'res://Maps/models'


onready var obj_exporter := $ObjExporter
var extractors := EntityMeshExtractors.new()
var scale_factor setget _set_scale_factor, _get_scale_factor
var output_dir setget, _get_output_dir


func _init():
	pass


func _ready() -> void:
	pass


func _exit_tree () -> void:
	obj_exporter = null


func _set_scale_factor(value: float) -> void:
	if is_inside_tree():
		obj_exporter.scale_factor = value
		CSquadUtil.Settings.set_scale_factor(value)


func _get_scale_factor() -> float:
	return CSquadUtil.Settings.scale_factor


var _output_dir: String = GAME_FOLDER_EXPORT_BASE_DIR
func _get_output_dir() -> String:
	return CSquadUtil.Settings.models_dir


# Compute full output path for model,
func get_node_export_path(root_node: Node, out_dir: String = "") -> String:
	assert(root_node.filename != "")

	if out_dir == "":
		out_dir = _get_output_dir()

	if not(typeof(out_dir) == TYPE_STRING and out_dir.length() > 0):
		var dir := Directory.new()
		if Engine.editor_hint and dir.dir_exists(GAME_FOLDER_EXPORT_BASE_DIR):
			print("[ObjBuilder#get_node_export_path] Creating path in models subfolder in TrenchBroom's configured game folder")
			out_dir = GAME_FOLDER_EXPORT_BASE_DIR
		else:
			out_dir  = OBJ_EXPORT_BASE_DIR

	return out_dir.plus_file(root_node.get_tree().edited_scene_root.filename.get_file().get_basename() + '.obj')


enum MESHINFO {
	MESH = 0,
	OVERRIDE,
	OFFSET,
	# Currently unused
	SCALE_FACTOR
}


# Generalized version of initial player test that attempts to match an extractor based on passed
# scene Node's name.
func export_scene_to_obj(scene: Node, out_path = null) -> void:
	if typeof(out_path) != TYPE_STRING or len(out_path) == 0:
		out_path = get_node_export_path(scene)
		dprint.write('out_path not passed or zero length, using computed output path: <%s>' % [ out_path ], 'export_scene_to_obj')

	var extractor = self.extractors.get_extractor_for_node(scene)
	if not is_instance_valid(extractor):
		dprint.write('Failed to resolve extractor for scene node: %s' % [ scene ], 'export_scene_to_obj')
		return

	var mesh_info_array = extractor.resolve_meshes(scene)

	# Scale meshes (moved from ObjExport, still not 100% on where this should be in the process)
	for info in mesh_info_array:
		MeshUtils.process_mesh(info[MESHINFO.MESH], info[MESHINFO.OFFSET], CSquadUtil.Settings.scale_factor)

	obj_exporter.save_meshes_to_obj(mesh_info_array, scene.get_tree().edited_scene_root.filename.get_file().get_basename()) # , out_path)


func run_with_edited_scene(node: Node):
	dprint.write('node = @%s' % [ node ], 'run_with_edited_scene')
	var target_scene = node.get_tree().edited_scene_root
	dprint.write('=> @%s -> @%s' % [ node.name, target_scene.name ], 'run_with_edited_scene')
	export_scene_to_obj(target_scene)
