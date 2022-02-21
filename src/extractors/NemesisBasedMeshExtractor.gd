tool
class_name NemesisBasedMeshExtractor
extends EntityMeshExtractor

func get_class() -> String:
	return 'NemesisBasedMeshExtractor'

func _init() -> void:
	set_name(get_class())

func can_target(node: Node) -> bool:
	return FindNemesisNode(node) is Spatial

func resolve_meshes(node: Node = target) -> Array:
	if node.is_inside_tree():
		dprint.write('Resolving meshes, passed node path %s' % [ node.get_tree().get_edited_scene_root().get_path_to(node) ], 'resolve_meshes')
	var meshes = [ ]

	var base = node.get_node(SkeletonNodeLeafPath)
	if not is_instance_valid(base):
		dprint.write('[WARNING] Failed to get skeleton child node with leaf path: %s' % [ SkeletonNodeLeafPath ], 'resolve_meshes')
		return meshes

	# Gonna try it dummy style
	AllChildMeshes(base, meshes, true)

	return meshes

# Just a simple check for Nemesis child node for now, but should be elaborated later instead for
# adding another separate extractor implementation
static func FindNemesisNode(node: Node) -> Spatial:
	return node.find_node('Nemesis') as Spatial

# Resolves base
var SkeletonNodeLeafPath := 'Nemesis/Armature/Skeleton'
