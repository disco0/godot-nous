tool
class_name WeaponMeshExtractor
extends EntityMeshExtractor

func _init() -> void:
	set_name('WeaponMeshExtractor')

func can_target(node: Node) -> bool:
	return node.name.begins_with('P_')

func resolve_meshes(node: Node = target) -> Array:
	dprint.write('Resolving meshes, passed node path %s' % [ node.get_tree().get_edited_scene_root().get_path_to(node) ], 'resolve_meshes')
	var meshes = [ ]

	var base = node.get_node('.')
	if not is_instance_valid(base):
		return meshes

	AllChildMeshes(base, meshes, true)

	return meshes
