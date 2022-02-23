class_name QodotEntitySceneObjSaver
extends ResourceFormatSaver
tool

#
# Editor interface for saving out objs directly. Not sure if this is possible
# yet lol
#

func get_recognized_extensions(resource: Resource) -> PoolStringArray:
	var exts := PoolStringArray(['obj'])
	return exts

func recognize(resource: Resource) -> bool:
	if resource is PackedScene:
		(resource  as PackedScene).get_local_scene()

	return false

func save(path: String, resource: Resource, flags: int) -> int:
	return -1
