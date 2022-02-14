class_name NemesisBasedMeshExtractor extends EntityMeshExtractor

# Just a simple check for Nemesis child node for now, but should be elaborated later instead for
# adding another separate extractor implementation
static func FindNemesisNode(node: Node) -> Spatial:
	return node.find_node('Nemesis') as Spatial

func can_target(node: Node) -> bool:
	return FindNemesisNode(node) is Spatial

func _init() -> void:
	self._class_name = 'NemesisBasedMeshExtractor'
	self.dprint_conf['Base'] = _class_name

# Resolves base 
var SkeletonNodeLeafPath := 'Nemesis/Armature/Skeleton'

func resolve_meshes(node: Node = target) -> Array:
	dprint('Resolving meshes, passed node path %s' % [ node.get_tree().get_edited_scene_root().get_path_to(node) ], 'resolve_meshes')
	var meshes = [ ]
		
	var base = node.get_node(SkeletonNodeLeafPath)
	if not is_instance_valid(base):
		dprint('[WARNING] Failed to get skeleton child node with leaf path: %s' % [ SkeletonNodeLeafPath ], 'resolve_meshes')
		return meshes

	# Gonna try it dummy style
	AllChildMeshes(base, meshes, true)
	
	return meshes
