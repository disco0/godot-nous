tool
class_name FGDEntityObjectData


var dprint = Nous.dprint_for('FGDEntityObjectData')

var fgd_class: QodotFGDPointClass
var scene: PackedScene
var scene_path: String setget , get_scene_path
var extractor: EntityMeshExtractor
var _instance: Node


func _init(fgd_class: QodotFGDPointClass, extractor = null):
	set_fgd_class(fgd_class)
	self.scene = fgd_class.scene_file
	if is_instance_valid(extractor) and extractor is EntityMeshExtractor:
		self.extractor = extractor
	else:
		_instance = fgd_class.scene_file.instance()
		self.extractor = Nous.Extractors.get_extractor_for_node(_instance)



func set_fgd_class(fgd: QodotFGDPointClass):
	if fgd is QodotFGDPointClass:
		fgd_class = fgd
		scene = fgd_class.scene_file
	else:
		if fgd is QodotFGDClass:
			push_warning('Passed non-point entity definition.')
		else:
			push_error('Passed non fgd entity definition')


func get_scene() -> PackedScene:
	return fgd_class.scene_file

func get_scene_path() -> String:
	if scene is PackedScene:
		return scene.resource_path
	else:
		push_error('FGDEntityObjectData._get_scene_path >> scene member is not valid PackedScene instance.')
		return ""
