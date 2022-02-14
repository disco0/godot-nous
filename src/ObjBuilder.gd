class_name ObjBuilder
extends Node
tool

const dprint_base_ctx := 'ObjBuilder'
static func dprint(msg: String, ctx: String = "") -> void:
	print('[%s] %s' % [
		'%s%s' % [ dprint_base_ctx, ":" + ctx if len(ctx) > 0 else "" ],
		msg
	])

onready var obj_exporter := $ObjExporter
	
func _init():
	extractors = EntityMeshExtractors.new()
	extractors.register_extractors()

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
var scale_factor setget _set_scale_factor, _get_scale_factor

# Path for in-game generation
const OBJ_EXPORT_BASE_DIR: String = 'user://obj-gen'
# Default path for in editor (getter used otherwise)
const GAME_FOLDER_EXPORT_BASE_DIR: String = 'res://Maps/models'
var _output_dir: String = GAME_FOLDER_EXPORT_BASE_DIR
func _get_output_dir() -> String:
	return CSquadUtil.Settings.models_dir
var output_dir setget, _get_output_dir

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


var extractors: EntityMeshExtractors

# Generalized version of initial player test that attempts to match an extractor based on passed
# scene Node's name.
func export_scene_to_obj(scene: Node, out_path = null) -> void:
	if typeof(out_path) != TYPE_STRING or len(out_path) == 0:
		out_path = get_node_export_path(scene)
		dprint('out_path not passed or zero length, using computed output path: <%s>' % [ out_path ], 'export_scene_to_obj')

	var extractor = self.extractors.get_extractor_for_node(scene)
	if not is_instance_valid(extractor):
		dprint('Failed to resolve extractor for scene node: %s' % [ scene ], 'export_scene_to_obj')
		return
		
	var meshes = extractor.resolve_meshes(scene)
		
	obj_exporter.save_meshes_to_obj(meshes, scene.get_tree().edited_scene_root.filename.get_file().get_basename()) # , out_path)


func run_with_edited_scene(node: Node):
	dprint('node = @%s' % [ node ], 'run_with_edited_scene')
	var target_scene = node.get_tree().edited_scene_root
	dprint('=> @%s -> @%s' % [ node.name, target_scene.name ], 'run_with_edited_scene')
	export_scene_to_obj(target_scene)
