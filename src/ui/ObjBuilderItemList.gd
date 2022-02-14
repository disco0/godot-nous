class_name ObjBuilderItemList
extends VBoxContainer
tool

var list_item_base := preload("./ObjEntityDockItem.tscn").instance()

const debug: bool = true
const dprint_base_ctx := 'ObjBuilderItemList'
static func dprint(msg: String, ctx: String = "") -> void:
	if debug:
		print('[%s] %s' % [
			'%s%s' % [ dprint_base_ctx, ":" + ctx if len(ctx) > 0 else "" ],
			msg
		])


func _init() -> void:
	dprint('', 'on:init')
	pass

func _ready() -> void:
	dprint('', 'on:ready')
	extractors = EntityMeshExtractors.new()
	extractors.register_extractors()
	buildable_searcher = FGDEntitySceneSearch.new(CSquadUtil.fgd)
	build_items()
	pass
	
func _enter_tree() -> void:
	dprint('', 'on:enter-tree')
	pass
	
func _exit_tree() -> void:
	dprint('', 'on:exit-tree')
	clear_items()
	pass
	
var buildable_searcher: FGDEntitySceneSearch
var ent_infos := [ ]

func clear_items() -> void:
	for child in get_children():
		if child.name == list_item_base.name:
			continue
		remove_child(child)

var extractors: EntityMeshExtractors

func create_list_item_node() -> ObjEntityDockItem:
	return  list_item_base.duplicate() as ObjEntityDockItem

#func add_item(ent: FGDEntitySceneSearch.EntInfo, extractor: EntityMeshExtractor) -> void:
func add_item(ent, extractor) -> void:
	var item := create_list_item_node()
	item.ent = ent
	item.extractor = extractor
	
	add_child(item)

func build_items() -> void:
	if not is_inside_tree():
		push_error('ObjBuilderItemList >> build_items called before entering tree.')
		
	buildable_searcher.collect_entity_scenes()
	ent_infos = buildable_searcher.point_ent_array
	
	for ent in ent_infos:
		if ent is FGDEntitySceneSearch.EntInfo:
			var extractor = resolve_packed_scene_extractor(ent.scene_file)
			add_ent_extactor(ent, extractor)
#		if is_instance_valid(extractor):
#		else:
#			pass
#			#dprint('[WARNING] No extractor for %s entity' % [ ent.name ], 'build_items')
	
func resolve_packed_scene_extractor(scene: PackedScene) -> EntityMeshExtractor:
	return extractors.get_extractor_for_node(scene.instance())

	
const ENT_ITEM_TEMPLATES := {
	NAME_PATH           = '%s: %s',
	NAME_EXTRACTOR_TYPE = '%s => %s'
}

func add_ent_extactor(ent: FGDEntitySceneSearch.EntInfo, extractor: EntityMeshExtractor):
	add_item(ent, extractor)
	
#
#func add_ent_item(ent: FGDEntitySceneSearch.EntInfo):
#	var name = ent.name
#	var path = ent.scene_file.resource_path
#	add_item(ENT_ITEM_TEMPLATES.NAME_PATH % [ name, path ], null, true)

func _on_RebuildButton_pressed() -> void:
	clear_items()
	yield(get_tree(), "idle_frame")
	dprint('Rebuilding extractable list', 'on:RebuildButton-pressed')
	build_items()
