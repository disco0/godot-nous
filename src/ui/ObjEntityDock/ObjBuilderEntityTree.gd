tool
class_name ObjBuilderEntityTree # @TODO: Update to ObjBuilderItemTree after getting tree working
extends Tree


var dprint := CSquadUtil.dprint_for(self)


const UNKNOWN_EXTRACTOR_COLOR_MOD := Color(1.0, 1.0, 1.0, 0.4)
const TREE_ITEM_DATA_KEYS := {
	DATA = 'data'
}
enum COLUMNS {
	BUILD_BUTTON = 0,
	CLASSNAME,
	EXTRACTOR,
}
const ITEM_BUILD_BUTTON_MIN_WIDTH := 65

var buildable_searcher: FGDEntitySceneSearch
var extractors := CSquadUtil.Extractors
var ent_infos := [ ]
var root_item: TreeItem


func _init() -> void:
	dprint.write('', 'on:init')
	
	set_column_min_width(COLUMNS.BUILD_BUTTON, ITEM_BUILD_BUTTON_MIN_WIDTH)
	
	set_column_title(COLUMNS.BUILD_BUTTON, '')
	set_column_title(COLUMNS.CLASSNAME, 'ClassName')
	set_column_title(COLUMNS.EXTRACTOR, 'Extractor')
	
	set_column_expand(COLUMNS.BUILD_BUTTON, false)
	set_column_expand(COLUMNS.CLASSNAME,    true)
	set_column_expand(COLUMNS.EXTRACTOR,    true)
	
	set_column_titles_visible(true)
	
	hide_root = true


func _ready() -> void:
	dprint.write('', 'on:ready')
	
	## Modified theming from owner
	#if not is_instance_valid(theme):
	#	theme = Theme.new()
	#var parent_theme = owner.theme
	#if parent_theme:
	#	theme.copy_theme(parent_theme)
	#else:
	#	theme.copy_default_theme()
	
	extractors.register_extractors()
	buildable_searcher = FGDEntitySceneSearch.new(CSquadUtil.fgd)
	pass


func _enter_tree() -> void:
	dprint.write('', 'on:enter-tree')
	pass


func _exit_tree() -> void:
	dprint.write('', 'on:exit-tree')
	clear_items()
	pass


func clear_items() -> void:
	clear()


#func create_base_item(ent: FGDEntitySceneSearch.EntInfo, extractor: EntityMeshExtractor) -> void:
func create_base_item(ent_info: FGDEntityObjectData) -> void:
	var item := create_item(root_item)# DOCK_TREE_ITEM)
	item.set_meta(TREE_ITEM_DATA_KEYS.DATA, ent_info)
	
	item.set_cell_mode(COLUMNS.BUILD_BUTTON, TreeItem.CELL_MODE_CHECK)
	item.set_editable(COLUMNS.BUILD_BUTTON, true)
	item.set_selectable(COLUMNS.BUILD_BUTTON, true)
	item.set_expand_right(COLUMNS.BUILD_BUTTON, false)
	#item.set_custom_bg_color(COLUMNS.BUILD_BUTTON, Color(0,0,0,0), false)
	#item.set_custom_color(COLUMNS.BUILD_BUTTON, Color(0,0,0,0))
	#item.set_custom_as_button(COLUMNS.BUILD_BUTTON, true)
	
	item.set_text(COLUMNS.CLASSNAME, ent_info.fgd_class.classname)
	item.set_selectable(COLUMNS.CLASSNAME, true)
	item.set_expand_right(COLUMNS.CLASSNAME, true)

	item.set_expand_right(COLUMNS.EXTRACTOR, true)
	item.set_selectable(COLUMNS.EXTRACTOR, true)
	if is_instance_valid(ent_info.extractor):
		item.set_text(COLUMNS.EXTRACTOR, ent_info.extractor.extractor_type )
	else:
		item.set_text(COLUMNS.EXTRACTOR, 'Unknown')
		item.set_custom_color(COLUMNS.EXTRACTOR, 
				get_color('font_color', 'Label') * UNKNOWN_EXTRACTOR_COLOR_MOD)


func build_items() -> void:
	if not is_inside_tree():
		push_error('ObjBuilderItemList >> build_items called before entering tree.')

	if not is_instance_valid(root_item):
		root_item = create_item(null, 0)
		

	buildable_searcher.collect_entity_scenes()
	var ent_dict := buildable_searcher.point_ents
	var ents := buildable_searcher.point_ent_array

	ent_infos = ent_dict.values()

	for ent in ents:
		if ent is FGDEntityObjectData:
			#var extractor = resolve_packed_scene_extractor(ent.scene)
			add_ent_item(ent)

	return

	ent_infos = ent_dict.values()

	var ent_keys  = ent_dict.keys()
	var ent_count = ent_infos.size()

	for idx in ent_count:
		var ent = ent_dict[ent_keys[idx]]
		#dprint.write('[%03d/%03d] %s' % [ idx + 1, ent_count, ent ], 'build_items')

		if ent is FGDEntityObjectData:
			add_ent_item(ent)


func resolve_packed_scene_extractor(scene: PackedScene) -> EntityMeshExtractor:
	return extractors.get_extractor_for_node(scene.instance())


func add_ent_item(ent: FGDEntityObjectData):
	create_base_item(ent)


func _on_ReloadButton_pressed() -> void:
	clear_items()
	yield(get_tree(), "idle_frame")
	dprint.write('Rebuilding extractable list', 'on:RebuildButton-pressed')
	build_items()
