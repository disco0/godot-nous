tool
class_name PlayerMeshExtractor
extends EntityMeshExtractor


var node_whitelist := [
	"Head_Mesh", "Torso_Mesh",
	# Shades
	"Plane001"
]
var SkeletonNodeLeafPath := 'Body_Mesh/Armature/Skeleton'
var AnimationPlayerLeafPath := 'Body_Mesh/AnimationPlayer'
var animation: String = 'Phone'


func get_class() -> String:
	return 'PlayerMeshExtractor'


#func _init() -> void:
#	set_name(get_class())


func can_target(node: Node) -> bool:
	return node.name == 'Player'


func resolve_meshes(node: Node = target) -> Array:
	var meshes = [ ]

	var animation_player: AnimationPlayer
	if ANIMATION_SEARCH_OVERRIDE_DISABLED == true:
		pass
	else:
		animation_player = node.get_node(AnimationPlayerLeafPath)
		if not is_instance_valid(animation_player):
			dprint.write('[WARNING] Failed to get animation player child node with leaf path: %s' % [ AnimationPlayerLeafPath ], 'resolve_meshes')
		else:
			var curr = animation_player.current_animation
			dprint.write('Current animation: %s' % [ curr if curr != "" else "<NONE>" ], 'resolve_meshes')
			# Set animation and seek one tick
			animation_player.current_animation = animation
			animation_player.seek(0.1, true)

	var base = node.get_child(0).get_node(SkeletonNodeLeafPath)
	if not is_instance_valid(base):
		dprint.write('[WARNING] Failed to get skeleton child node with leaf path: %s' % [ SkeletonNodeLeafPath ], 'resolve_meshes')
		return meshes

	# Gonna try it dummy style
	MeshUtils.CollectChildMeshes(base, meshes, true, node_whitelist)
	#dprint.write('Collected %d child meshes' % [ meshes.size() ])


	if ANIMATION_SEARCH_OVERRIDE_DISABLED == true:
		pass
	else:
		if is_instance_valid(animation_player):
			animation_player.stop()

	return meshes
