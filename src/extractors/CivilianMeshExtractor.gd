class_name CivilianMeshExtractor extends EntityMeshExtractor

func can_target(node: Node) -> bool:
	return node.name.begins_with('Civilian')

func _init() -> void:
	self._class_name = 'CivilianMeshExtractor'
	self.dprint_conf['Base'] = _class_name

# Resolves base 
var SkeletonNodeLeafPath := 'Nemesis/Armature/Skeleton'
var AnimationPlayerLeafPath := 'Nemesis/AnimationPlayer'
var animation: String = 'Run'

func resolve_meshes(node: Node = target) -> Array:
	dprint('Resolving meshes, passed node path %s' % [ node.get_tree().get_edited_scene_root().get_path_to(node) ], 'resolve_meshes')
	var meshes = [ ]
		
	var base = node.get_node(SkeletonNodeLeafPath)
	if not is_instance_valid(base):
		dprint('[WARNING] Failed to get skeleton child node with leaf path: %s' % [ SkeletonNodeLeafPath ], 'resolve_meshes')
		return meshes

	var animation_player: AnimationPlayer = node.get_node(AnimationPlayerLeafPath)
	if animation:
		if not is_instance_valid(animation_player):
			dprint('[WARNING] Failed to get animation player child node with leaf path: %s' % [ AnimationPlayerLeafPath ], 'resolve_meshes')
		else:
			var curr = animation_player.current_animation
			dprint('Current animation: %s' % [ curr if curr != "" else "<NONE>" ], 'resolve_meshes')
			# Set animation and seek one tick
			animation_player.current_animation = animation
			animation_player.seek(0.1, true)

	# Gonna try it dummy style
	AllChildMeshes(base, meshes, true)
	
	if animation and is_instance_valid(animation_player):
		animation_player.stop()

	return meshes
