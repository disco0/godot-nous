tool
class_name AnyMeshExtractor
extends EntityMeshExtractor

#
# Generic get-all extractor for project tool menu.
#
# _Do not add to Extractors register._
#

func get_class() -> String:
	return 'AnyMeshExtractor'

func _init() -> void:
	set_name(get_class())

func resolve_meshes(node: Node = target) -> Array:
	var meshes_info := [ ]

	MeshUtils.CollectChildMeshes(node, meshes_info, false)

	return meshes_info

# Just check if there's any meshes
func can_target(node: Node) -> bool:
	for child in node.get_children():
		if child is MeshInstance:
			return true

	return false
