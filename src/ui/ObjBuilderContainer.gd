class_name ObjBuilderContainer
extends HBoxContainer
tool


const dprint_base_ctx := 'ObjBuilderContainer'
static func dprint(msg: String, ctx: String = "") -> void:
	print('[%s] %s' % [
		'%s%s' % [ dprint_base_ctx, ":" + ctx if len(ctx) > 0 else "" ],
		msg
	])


onready var obj_builder = $ObjBuilder
onready var scale_factor_box: SpinBox = $ScaleFactor / SpinBox
onready var extractor_info_label: Label = $ExtractorInfoLabel

# Update UI preview of resolved extractor given an extractor instance or name string. Will hide 
# label if passed null/empty string/non-string value
func update_extractor_info_label(extractor = null) -> void:
	var name: String
	if typeof(extractor) == TYPE_STRING:
		if len(extractor) == 0:
			extractor_info_label.set_visible(false)
			return
		else:
			pass
	elif extractor is EntityMeshExtractor:
		name = extractor.extractor_name
	else:
		extractor_info_label.set_visible(false)
		return

	extractor_info_label.set_text(name.trim_suffix('Extractor'))
	extractor_info_label.set_visible(true)


var edited_ref := weakref(null)

func get_derefed_edited_weakref() -> Spatial:
	return edited_ref.get_deref()

var edited: Spatial setget, get_derefed_edited_weakref


# Debugging
var last_event_stage := '<NONE>'

func _init() -> void:
	dprint('', 'on:init')
	last_event_stage = 'INIT'

func _ready() -> void:
	dprint('', 'on:ready')
	last_event_stage = 'READY'
	dprint('Initializing UI input values', 'on:ready')
	scale_factor_box.set_value(CSquadUtil.Settings.scale_factor)
	dprint('End UI values initialization', 'on:ready')

func _enter_tree() -> void:
	dprint('', 'on:enter-tree')
	last_event_stage = 'IN-TREE'

	if CSquadUtil.Settings._loaded : pass
	else: yield(CSquadUtil.Settings, "ready")


func clear_edited() -> void:
	edited_ref = weakref(null)

func edit(node: Node) -> void:
	if editable(node):
		edited_ref = weakref(node)
		
func _get_has_handle() -> bool:
	return is_instance_valid(edited_ref.get_ref())
var has_handle: bool setget, _get_has_handle

func handles(object) -> bool:
	return editable(object)

var last_editable_node_id := -1

func editable(node) -> bool:
	if not (node is Node and node.is_inside_tree()):
		return false
		
	if (node as Node).get_tree().edited_scene_root.name == 'Level':
		last_editable_node_id = -1
		return false

	var id := (node as Node).get_instance_id()
	if last_editable_node_id > 0 and id == last_editable_node_id:
		dprint('Passed node matches last validated node resource id: %s' % [ id ], 'editable')
		return true
		
	if not is_instance_valid(obj_builder.extractors):
		dprint('[WARNING] [Stage:%s] obj_builder.extractors not valid instance.' % [ last_event_stage ], 'editable')
		return false
		
	var resolved_extractor = obj_builder.extractors.get_extractor_for_node((node as Node).get_tree().edited_scene_root)
	if not is_instance_valid(resolved_extractor):
		update_extractor_info_label()
		return false

	last_editable_node_id = id
	update_extractor_info_label(resolved_extractor)

	return true


func _on_BuildSceneObj_pressed() -> void:
	var edited = edited_ref.get_ref()
	if not is_instance_valid(edited):
		dprint('Edited node reference unset, cancelling obj generation', 'editable')
		return

	print('[on:BuildSceneObj_pressed]')
	obj_builder.run_with_edited_scene(edited)


func _on_ScaleFactor_value_changed(value: float) -> void:
	dprint('Updating scale factor -> %s' % [ value ], 'on:ScaleFactor_value_changed')
	CSquadUtil.Settings.set_scale_factor(value)
	$ObjBuilder.scale_factor = CSquadUtil.Settings.scale_factor


func _exit_tree() -> void:
	last_event_stage = 'EXIT-TREE'
	obj_builder = null
	scale_factor_box = null
