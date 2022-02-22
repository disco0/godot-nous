tool
class_name ArrayMeshToObjSaver
extends ResourceFormatSaver

# Saving for possible reference later
# https://old.reddit.com/r/godot/comments/m2ufz2/help_with_surfacetoolcommit_not_working_with/gqlij9l/


func recognize(resource: Resource) -> bool:
	return resource is ArrayMesh


func get_recognized_extensions(resource: Resource) -> PoolStringArray:
	return PoolStringArray([ "obj" ])


func save(path: String, resource: Resource, flags: int) -> int:
	return OK
