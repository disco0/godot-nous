tool
class_name NemesisBasedMeshExtractor
extends EntityMeshExtractor


func get_class() -> String:
	return 'NemesisBasedMeshExtractor'


func _init() -> void:
	set_name(get_class())


func can_target(node: Node) -> bool:
	return FindNemesisNode(node) is Spatial


func resolve_meshes(node: Node = target):
	if node.is_inside_tree():
		dprint.write('Resolving meshes, passed node path %s' % [ node.get_tree().get_edited_scene_root().get_path_to(node) ], 'resolve_meshes')
	var meshes = [ ]

	var base: Skeleton = node.get_node(SkeletonNodeLeafPath)
	if not is_instance_valid(base):
		dprint.write('[WARNING] Failed to get skeleton child node with leaf path: %s' % [ SkeletonNodeLeafPath ], 'resolve_meshes')
		return meshes

	#var animation := base.get_parent().find_node('AnimationPlayer') as AnimationPlayer
	#if animation and animation.has_animation('Idle'):
	#	animation.set_active(true)
	#	animation.set_current_animation('Idle')
	#	animation.seek(0, true)

	#var bone_count := base.get_bone_count()
	#for bone_idx in bone_count:
	#	dprint.write('Bone: %s' % [ base.get_bone_name(bone_idx) ], 'resolve_meshes')
	#	var bone_nodes := base.get_bound_child_nodes_to_bone(bone_idx)
	#	var bone_xform := base.get_bone_rest(bone_idx)
	#
	#	var bone_node: Spatial
	#	for bone_node_idx in bone_nodes.size():
	#		bone_node = bone_nodes[bone_node_idx]
	#		dprint.write(' - Bone Node %s' % [ bone_node ], 'resolve_meshes')
	#		#meshes.push_back([bone_node.])

	MeshUtils.CollectChildMeshes(base, meshes, true)

	return meshes


# Just a simple check for Nemesis child node for now, but should be elaborated later instead for
# adding another separate extractor implementation
static func FindNemesisNode(node: Node) -> Spatial:
	return node.find_node('Nemesis', true) as Spatial


# Resolves base
var SkeletonNodeLeafPath := 'Nemesis/Armature/Skeleton'
