tool
class_name CarMeshExtractor
extends EntityMeshExtractor

func get_class() -> String:
	return 'CarMeshExtractor'

func can_target(node: Node) -> bool:
	return node.name.begins_with('Car')

func resolve_meshes(node: Node = target) -> Array:
	if node.is_inside_tree():
		dprint.write('Resolving meshes, passed node path %s' % [ node.get_tree().get_edited_scene_root().get_path_to(node) ], 'resolve_meshes')
	var meshes_info = [ ]

	var base = node.get_node('.')
	if not is_instance_valid(base):
		return meshes_info

	MeshUtils.CollectChildMeshes(node, meshes_info, false)

	return meshes_info
