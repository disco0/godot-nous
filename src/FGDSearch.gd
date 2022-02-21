tool
class_name FGDEntitySceneSearch
extends Node
#
# Scans qodot FGD resource and returns scenes for obj building
#


var dprint := CSquadUtil.dprint_for(self)


const DEFAULT_FGD := preload('res://addons/qodot/game-definitions/fgd/qodot_fgd.tres')
const VERBOSE := false

var fgd: QodotFGDFile
var point_ents: Dictionary = { } # Record<String, FGDEntityObjectData>
var point_ent_array: Array setget, _get_point_ent_array


func _init(fgd := DEFAULT_FGD) -> void:
	if not is_instance_valid(fgd):
		dprint.write('Using default fgd path', 'on:init')
		self.fgd = DEFAULT_FGD
	else:
		self.fgd = fgd


func clear_point_ents() -> void:
	point_ents = { }


func collect_entity_scenes() -> void:
	clear_point_ents()

	var ent_defs: Dictionary = fgd.get_entity_definitions()
	dprint.write('Processing %d entity definitions' % [ ent_defs.size() ], 'collect_entity_scenes')
	var keys := ent_defs.keys()
	var keys_count := keys.size()
	var last_failed
	for key_idx in keys_count:
		var key: String = keys[key_idx]
		if VERBOSE: dprint.write('[%03d/%03d] -> %s' % [ key_idx + 1, keys_count, key ], 'collect_entity_scenes')

		var ent_def := ent_defs[key] as QodotFGDPointClass
		if not is_instance_valid(ent_def):
			#dprint.warn('[Not QodotFGDPointClass]', 'collect_entity_scenes')
			continue

		if typeof(ent_def.classname) != TYPE_STRING:
			dprint.warn('[WARNING] FGD entity has no classname.', 'collect_entity_scenes')
			continue
		elif not is_instance_valid(ent_def.scene_file):
			dprint.warn('Point entity %s has no scene_file' % [ ent_def.classname ], 'collect_entity_scenes')
			continue
		elif not ent_def.scene_file.can_instance():
			dprint.warn('Point entity %s contains non-instanceable scene_file: %s' % [ ent_def.classname, ent_def.scene_file ], 'collect_entity_scenes')
			continue

		var ent_data := FGDEntityObjectData.new(ent_def)
		if ent_data is FGDEntityObjectData:
			point_ents[ent_def.classname] = ent_data
		else:
			last_failed = ent_data

	return

	#if last_failed:
	#	dprint.write('Inspecting last failed item in definition list', 'collect_entity_scenes')
	#	CSquadUtil.plugin.get_editor_interface().inspect_object(last_failed)

	# Debug print for now
	var idx := 0
	var size = point_ents.size()
	for ent in point_ents:
		idx += 1
		dprint.write('[%03d/%03d] %s' % [ idx, size, ent ])


func _get_point_ent_array() -> Array:
	if point_ents.size() == 0:
		collect_entity_scenes()

	return point_ents.values()
