tool
class_name PropMeshExtractor
extends EntityMeshExtractor

func get_class() -> String:
	return 'PropMeshExtractor'

func can_target(node: Node) -> bool:
	var name = node.get_name()
	if typeof(name) != TYPE_STRING or name.empty():
		return false

	return name.begins_with('Prop_') \
		or name.begins_with('Health_Kit') \
		or name in [ 'Crab', 'fullpizza' ]

func resolve_meshes(node: Node = target) -> Array:
	if node.is_inside_tree():
		dprint.write('Resolving meshes, passed node path %s' % [ node.get_tree().get_edited_scene_root().get_path_to(node) ], 'resolve_meshes')

	var meshes = [ ]

	var base = node.get_node('.')
	if not is_instance_valid(base):
		return meshes

	AllChildMeshes(base, meshes, true)

	return meshes
