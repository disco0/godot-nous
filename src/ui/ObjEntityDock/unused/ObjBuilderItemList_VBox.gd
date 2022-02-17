class_name ObjBuilderItemList_VBox
extends VBoxContainer
tool
#
#
#var dprint := CSquadUtil.dprint_for(self)
#
#
#const DOCK_LIST_ITEM := preload('./ObjEntityDockItem_HBox.tscn')
#const ENT_ITEM_TEMPLATES := {
#	NAME_PATH           = '%s: %s',
#	NAME_EXTRACTOR_TYPE = '%s => %s'
#}
#
#
#var list_item_base := DOCK_LIST_ITEM.instance()
#var buildable_searcher: FGDEntitySceneSearch
#var extractors: EntityMeshExtractors
#var ent_infos := [ ]
#
#
#func _init() -> void:
#	dprint.write('', 'on:init')
#	pass
#
#
#func _ready() -> void:
#	dprint.write('', 'on:ready')
#	extractors = EntityMeshExtractors.new()
#	extractors.register_extractors()
#	buildable_searcher = FGDEntitySceneSearch.new(CSquadUtil.fgd)
#	build_items()
#	pass
#
#
#func _enter_tree() -> void:
#	dprint.write('', 'on:enter-tree')
#	pass
#
#
#func _exit_tree() -> void:
#	dprint.write('', 'on:exit-tree')
#	clear_items()
#	pass
#
#
#func clear_items() -> void:
#	for child in get_children():
#		if child.name == list_item_base.name:
#			continue
#		remove_child(child)
#
#
#func create_list_item_node() -> ObjEntityDockItem_HBox:
#	return  list_item_base.duplicate() as ObjEntityDockItem_HBox
#
#
##func add_item(ent: FGDEntitySceneSearch.EntInfo, extractor: EntityMeshExtractor) -> void:
#func add_item(ent, extractor) -> void:
#	var item := create_list_item_node()
#	item.ent = ent
#	item.extractor = extractor
#
#	add_child(item)
#
#
#func build_items() -> void:
#	if not is_inside_tree():
#		push_error('ObjBuilderItemList >> build_items called before entering tree.')
#
#	buildable_searcher.collect_entity_scenes()
#	ent_infos = buildable_searcher.point_ent_array
#
#	for ent in ent_infos:
#		if ent is FGDEntitySceneSearch.EntInfo:
#			var extractor = resolve_packed_scene_extractor(ent.scene_file)
#			add_ent_extactor(ent, extractor)
#
#
#func resolve_packed_scene_extractor(scene: PackedScene) -> EntityMeshExtractor:
#	return extractors.get_extractor_for_node(scene.instance())
#
#
#func add_ent_extactor(ent: FGDEntitySceneSearch.EntInfo, extractor: EntityMeshExtractor):
#	add_item(ent, extractor)
#
#
#func _on_ReloadButton_pressed() -> void:
#	clear_items()
#	yield(get_tree(), "idle_frame")
#	dprint.write('Rebuilding extractable list', 'on:RebuildButton-pressed')
#	build_items()
