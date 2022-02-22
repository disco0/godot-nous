tool
class_name ObjBuilderEntityTree # @TODO: Update to ObjBuilderItemTree after getting tree working
extends Tree

signal update_request()

export (bool) var filter_case_sensitive := true


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
const ITEM_BUILD_BUTTON_MIN_WIDTH := 25

var buildable_searcher: FGDEntitySceneSearch
var extractors := CSquadUtil.Extractors
var ent_infos := [ ]
var root_item: TreeItem
var classname_filter := ""


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


func initialize_root(rebuild: bool = true):
	if rebuild:
		clear()
		root_item = create_item(null, 0)
	elif not is_instance_valid(root_item):
		root_item = create_item(null, 0)


func _ready() -> void:
	dprint.write('', 'on:ready')
	extractors.register_extractors()
	buildable_searcher = FGDEntitySceneSearch.new(CSquadUtil.fgd)

	set_hide_root(true)

	_queue_update()


func _enter_tree() -> void:
	dprint.write('', 'on:enter-tree')
	pass


func _exit_tree() -> void:
	dprint.write('', 'on:exit-tree')
	clear()
	pass


var _update_queued := false
func _queue_update():
	if not is_inside_tree():
		return

	if _update_queued:
		return

	_update_queued = true
	call_deferred("build_items", true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var evt := event as InputEventMouseButton
		if evt.pressed == false:
			return

		# Open entity definition in inspector if middle clicked
		match evt.get_button_index():
			BUTTON_MIDDLE:
				var item := get_item_at_position(get_global_mouse_position() - get_global_position()) as TreeItem
				if item:
					dprint.write('Inspecting %s -> <%s>' % [
							item,
							(item.get_meta(TREE_ITEM_DATA_KEYS.DATA) as FGDEntityObjectData).fgd_class ])
					inspect_item_fgd(item)


# Temporary workaround for receiving a duplicate instance of an FGD entity resource with no path.
func resolve_source_res(ent_info: FGDEntityObjectData):
	var target = ent_info.fgd_class.classname
	var defs := CSquadUtil.fgd.get_entity_definitions()
	for name in defs.keys():
		if name == target:
			return defs[name]

	dprint.warn('Failed to find original resource file for %s' % [ ent_info ], 'resolve_source_res')
	return ""


func inspect_item_fgd(item: TreeItem) -> void:
	var data := item.get_meta(TREE_ITEM_DATA_KEYS.DATA) as FGDEntityObjectData
	if is_instance_valid(data):
		var orig = resolve_source_res(data)
		if not orig:
			return
		else:
			CSquadUtil.editor.inspect_object(orig, "", true)

			var inspector_tab = CSquadUtil.editor.get_tree().root.find_node('Inspector', true, false)
			var tab_container := inspector_tab.get_parent() as TabContainer
			tab_container.set_current_tab(inspector_tab.get_position_in_parent())
			#for idx in tab_container.get_child_count():
			#	if tab_container.get_child(idx).name == inspector_tab.name:
			#		return

			# @TODO: Implement this properly in utils, and use it focus the inspector
			# root.find_node('Inspector', true, false).get_parent().set_current_tab(0)
	else:
		dprint.warn('Failed to read metadata on tree item: %s' % [ item ], 'inspect_item_fgd')


#func create_base_item(ent: FGDEntitySceneSearch.EntInfo, extractor: EntityMeshExtractor) -> void:
func create_base_item(ent_info: FGDEntityObjectData) -> void:
	var item := create_item(root_item)# DOCK_TREE_ITEM
	item.set_meta(TREE_ITEM_DATA_KEYS.DATA, ent_info)

	item.set_cell_mode(COLUMNS.BUILD_BUTTON, TreeItem.CELL_MODE_CHECK)
	item.set_editable(COLUMNS.BUILD_BUTTON, true)
	item.set_selectable(COLUMNS.BUILD_BUTTON, false)
	item.set_expand_right(COLUMNS.BUILD_BUTTON, false)


	item.set_text(COLUMNS.CLASSNAME, ent_info.fgd_class.classname)
	item.set_selectable(COLUMNS.CLASSNAME, true)
	item.set_expand_right(COLUMNS.CLASSNAME, true)

	item.set_expand_right(COLUMNS.EXTRACTOR, true)
	item.set_selectable(COLUMNS.EXTRACTOR, false)
	if is_instance_valid(ent_info.extractor):
		item.set_text(COLUMNS.EXTRACTOR, ent_info.extractor.extractor_type )
	else:
		item.set_text(COLUMNS.EXTRACTOR, 'Unknown')
		item.set_custom_color(COLUMNS.EXTRACTOR,
				get_color('font_color', 'Label') * UNKNOWN_EXTRACTOR_COLOR_MOD)
		item.set_selectable(COLUMNS.BUILD_BUTTON, false)
		item.set_editable(COLUMNS.BUILD_BUTTON, false)
		item.set_checked(COLUMNS.BUILD_BUTTON, false)
		item.set_cell_mode(COLUMNS.BUILD_BUTTON, TreeItem.CELL_MODE_STRING)
		#item.set_button_disabled(COLUMNS.BUILD_BUTTON, 0, true)


func build_items(rebuild := false) -> void:
	#dprint.write('Building')
	# Fix for reloads during development
	if not buildable_searcher:
		buildable_searcher = FGDEntitySceneSearch.new(CSquadUtil.fgd)

	if not is_inside_tree():
		dprint.error('build_items called before entering tree', 'build_items')
		return

	initialize_root(rebuild)

	buildable_searcher.collect_entity_scenes()
	var ent_dict := buildable_searcher.point_ents
	var ents := buildable_searcher.point_ent_array

	ent_infos = ent_dict.values()

	#var yield_interval := 5
	#var idx := 0

	if classname_filter.empty():
		#dprint.write('Empty search filter', 'build_items')
		for ent in ents:
			if ent is FGDEntityObjectData:
				#var extractor = resolve_packed_scene_extractor(ent.scene)
				add_ent_item(ent)
				#if idx % yield_interval == 0:
				#	yield(get_tree().create_timer(0.0), "timeout")
				#idx += 1
	else:
		#dprint.write('Using filter <%s>' % [ classname_filter ], 'build_items')
		for ent in ents:
			if ent is FGDEntityObjectData:
				if (
					(classname_filter.to_lower() in (ent as FGDEntityObjectData).fgd_class.classname.to_lower())
						if filter_case_sensitive else
					(classname_filter in (ent as FGDEntityObjectData).fgd_class.classname)
				):
					#var extractor = resolve_packed_scene_extractor(ent.scene)
					add_ent_item(ent)
					#if idx % yield_interval == 0:
					#	yield(get_tree().create_timer(0.0), "timeout")
					#idx += 1

	_update_queued = false

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


func has_checked_item() -> bool:
	var item = get_root().get_children()
	while item is TreeItem:
		if item.is_checked(COLUMNS.BUILD_BUTTON):
			return true
		item = item.get_next()

	return false


func _on_ReloadListButton_pressed() -> void:
	clear()
	yield(get_tree(), "idle_frame")
	#dprint.write('Rebuilding extractable list', 'on:ReloadListButton-pressed')
	build_items()


func collect_checked_ent_infos() -> Array:
	var collected := [ ]
	var item = get_root().get_children()
	while item is TreeItem:
		# Recursive set_checked call will set non-editable values to checked,
		# so an additional check here is necessary for now
		if item.is_editable(COLUMNS.BUILD_BUTTON) \
				and item.is_checked(COLUMNS.BUILD_BUTTON):

			collected.push_back(item.get_meta(TREE_ITEM_DATA_KEYS.DATA))
		item = item.get_next()

	return collected


# Input from search input
func _on_FilterLineEdit_text_changed(new_text: String) -> void:
	var new_filter := new_text.strip_edges()

	# Ignore empty/identical inputs iff zero items listed
	if (get_root().get_next()) and (new_filter.empty() or classname_filter == new_filter):
		return

	classname_filter = new_filter
	#dprint.write('Updated filter: <%s>' % [ classname_filter ], 'on:FilterLineEdit-text-changed')

	emit_signal("update_request")


func _on_update_request() -> void:
	#dprint.write('Received', 'on:update_request')
	_queue_update()


# On enter pressed in search input
func _on_FilterLineEdit_text_entered(new_text: String) -> void:
	_on_FilterLineEdit_text_changed(new_text)
