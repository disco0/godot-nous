class_name PlayerMeshExtractor extends EntityMeshExtractor

func can_target(node: Node) -> bool:
	return node.name == 'Player'
	
func _init() -> void:
	self._class_name = 'PlayerMeshExtractor'
	self.dprint_conf['Base'] = _class_name

var SkeletonNodeLeafPath := 'Body_Mesh/Armature/Skeleton'
var AnimationPlayerLeafPath := 'Body_Mesh/AnimationPlayer'
var animation: String = 'Phone'

func resolve_meshes(node: Node = target) -> Array:
	var meshes = [ ]

	var animation_player: AnimationPlayer = node.get_node(AnimationPlayerLeafPath)
	if not is_instance_valid(animation_player):
		dprint('[WARNING] Failed to get animation player child node with leaf path: %s' % [ AnimationPlayerLeafPath ], 'resolve_meshes')
	else:
		var curr = animation_player.current_animation
		dprint('Current animation: %s' % [ curr if curr != "" else "<NONE>" ], 'resolve_meshes')
		# Set animation and seek one tick
		animation_player.current_animation = animation
		animation_player.seek(0.1, true)
		
	var base = node.get_node(SkeletonNodeLeafPath)
	if not is_instance_valid(base):
		dprint('[WARNING] Failed to get skeleton child node with leaf path: %s' % [ SkeletonNodeLeafPath ], 'resolve_meshes')
		return meshes

	# Gonna try it dummy style
	AllChildMeshes(base, meshes, true, ["Head_Mesh", "Torso_Mesh"])
	
	if is_instance_valid(animation_player):
		animation_player.stop()

	return meshes
