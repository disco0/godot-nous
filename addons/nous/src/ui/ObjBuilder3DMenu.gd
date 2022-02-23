tool
class_name ObjBuilder3DMenu
extends HBoxContainer


var dprint := Nous.dprint_for(self)


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
	dprint.write('', 'on:init')
	last_event_stage = 'INIT'

func _ready() -> void:
	dprint.write('', 'on:ready')
	last_event_stage = 'READY'
	dprint.write('Initializing UI input values', 'on:ready')
	scale_factor_box.set_value(Nous.Settings.scale_factor)
	dprint.write('End UI values initialization', 'on:ready')

func _enter_tree() -> void:
	dprint.write('', 'on:enter-tree')
	last_event_stage = 'IN-TREE'


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
		dprint.write('Passed node matches last validated node resource id: %s' % [ id ], 'editable')
		return true

	if not is_instance_valid(obj_builder.extractors):
		dprint.write('[WARNING] [Stage:%s] obj_builder.extractors not valid instance.' % [ last_event_stage ], 'editable')
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
		dprint.write('Edited node reference unset, cancelling obj generation', 'editable')
		return

	print('[on:BuildSceneObj_pressed]')
	obj_builder.run_with_edited_scene(edited)


func _on_ScaleFactor_value_changed(value: float) -> void:
	dprint.write('Updating scale factor -> %s' % [ value ], 'on:ScaleFactor_value_changed')
	Nous.Settings.set_scale_factor(value)
	$ObjBuilder.scale_factor = Nous.Settings.scale_factor


func _exit_tree() -> void:
	last_event_stage = 'EXIT-TREE'
	obj_builder = null
	scale_factor_box = null
