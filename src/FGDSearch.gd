class_name FGDEntitySceneSearch
extends Node
tool


const dprint_base_ctx := 'FGDEntitySceneSearch'
static func dprint(msg: String, ctx: String = "") -> void:
	print('[%s] %s' % [
		'%s%s' % [ dprint_base_ctx, ":" + ctx if len(ctx) > 0 else "" ],
		msg
	])


#
# Scans qodot FGD resource and returns scenes for obj building
#

const DEFAULT_FGD_PATH = 'res://addons/qodot/game-definitions/fgd/qodot_fgd.tres'

var fgd: QodotFGDFile

func _init(fgd: QodotFGDFile) -> void:
	if not is_instance_valid(fgd):
		dprint('Using default fgd path', 'on:init')
		self.fgd = preload(DEFAULT_FGD_PATH)
	else:
		self.fgd = fgd

class EntInfo:
	var classname: String
	var scene_file: PackedScene
	
	func _init(classname: String, scene_file: PackedScene) -> void:
		self.classname  = classname
		self.scene_file = scene_file
		
		
	func _to_string() -> String:
		return '%s%s => <%s>' % [ classname, ' '.repeat(15 - len(classname)), scene_file.resource_path ]

var point_ents: Dictionary = { } # Record<String, EntInfo>

func clear_point_ents() -> void:
	point_ents = { }

func _get_point_ent_array() -> Array:
	return point_ents.values()
var point_ent_array: Array setget, _get_point_ent_array

func collect_entity_scenes() -> void:
	clear_point_ents()
	
	var defs = fgd.get_entity_definitions()
	for key in defs.keys():
		var def = defs[key]
		var ent_name: String = (def as QodotFGDClass).classname
		if typeof(ent_name) != TYPE_STRING:
			dprint('[WARNING] FGD entity has no classname.', 'collect_entity_scenes')
			continue
			
		# Just checks if entity has a defined packed scene for now
		if def is QodotFGDPointClass:
			var scene = (def as QodotFGDPointClass).scene_file
			if scene is PackedScene:
				#dprint('  %s => <%s>' % [ ent_name, scene.resource_path ], 'collect_entity_scenes')
				point_ents[ent_name] = EntInfo.new(ent_name, scene)
				
		
	return
	
	# Debug print for now
	var idx := 0
	var size = point_ents.size()
	for ent in point_ents:
		idx += 1
		dprint('[%03d/%03d] %s' % [ idx, size, ent ])

