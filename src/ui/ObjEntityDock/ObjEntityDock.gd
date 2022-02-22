tool
class_name ObjEntityDock
extends Control


var dprint := CSquadUtil.dprint_for(self)

const MESHINFO = ObjBuilder.MESHINFO

onready var item_tree: ObjBuilderEntityTree = $VBoxContainer/EntityTreeScrollContainer/ObjBuilderEntityTree
onready var headers_box: HSplitContainer = $VBoxContainer/Headers
onready var fgd_button: Button = $VBoxContainer/OpenFGDResButton
onready var models_button: Button = $VBoxContainer/OpenFolderButton
onready var build_button: Button = $VBoxContainer/HBoxContainer/BuildButton
onready var progress: MarginContainer = $VBoxContainer/Progress
onready var progress_bar: ProgressBar = $VBoxContainer/Progress/Bar
onready var progress_text: Label = $VBoxContainer/Progress/Text
onready var update_entity_paths_button: Button = $VBoxContainer/HBoxContainer/UpdateFGDModelPaths
onready var exporter: ObjExporter = $Proc/ObjExporter


# @TODO: Move this to setting_changed signal instead of reading it every time
var output_dir: String setget, get_output_dir
var _output_dir: String


func _init() -> void:
	dprint.write('', 'on:init')
	pass


func _ready() -> void:
	dprint.write('', 'on:ready')
	item_tree.build_items()

	progress.visible = false

	models_button.hint_tooltip = "Open %s in OS file manager" % [ CSquadUtil.Settings.tb_game_dir.get_models_dir() ]
	fgd_button.hint_tooltip = "Open %s in inspector panel" % [ CSquadUtil.fgd.resource_path ]
	pass


func _enter_tree() -> void:
	dprint.write('', 'on:enter-tree')
	if CSquadUtil.Settings._loaded : pass
	else: yield(CSquadUtil.Settings, "ready")


func _exit_tree() -> void:
	dprint.write('', 'on:exit-tree')


func get_output_dir() -> String:
	_output_dir = CSquadUtil.Settings.tb_game_dir.models_dir
	return _output_dir


# Open output folder in operating system file manager
func _on_OpenFolderButton_pressed() -> void:
	var dir := Directory.new()
	var out_dir := self.output_dir

	if not (typeof(out_dir) == TYPE_STRING and out_dir.length() > 0):
		push_error('Invalid output_dir member value: "%s"' % [ output_dir ])
		return

	var g_output_dir = ProjectSettings.globalize_path(self.output_dir)
	if dir.dir_exists(g_output_dir):
		OS.shell_open(g_output_dir)


func _on_ObjBuilderEntityTree_item_activated():
	var root := item_tree.get_root()
	if not is_instance_valid(root):
		dprint.warn('No root in Tree.', 'on:Select-All-pressed')
		return

	# Double click implies last selected I guess
	var col_idx = item_tree.get_selected_column()
	if col_idx != item_tree.COLUMNS.CLASSNAME:
		return

	var sel = item_tree.get_selected()
	if not sel: return

	var data := sel.get_meta(item_tree.TREE_ITEM_DATA_KEYS.DATA) as FGDEntityObjectData
	if not data:
		return

	var interface := CSquadUtil.plugin.get_editor_interface()
	interface.set_main_screen_editor('3D')
	interface.open_scene_from_path(data.scene_path)
	interface.set_main_screen_editor('3D')


func set_all_buttons(value: bool) -> void:
	var root := item_tree.get_root()
	if not is_instance_valid(root):
		dprint.warn('No root in Tree.', 'on:Select-All-pressed')
		return
	root.call_recursive('set_checked', item_tree.COLUMNS.BUILD_BUTTON, value)


func _on_Select_All_pressed() -> void:
	if not is_inside_tree():
		dprint.write('Skipping, not in tree', 'on:Select-All-pressed')
	set_all_buttons(true)
	build_button.set_disabled(false)
	update_entity_paths_button.set_disabled(false)


func _on_DeselectAll_pressed():
	if not is_inside_tree():
		dprint.write('Skipping, not in tree', 'on:Deselect-All-pressed')
	set_all_buttons(false)
	build_button.set_disabled(true)
	update_entity_paths_button.set_disabled(true)


func _on_OpenFGDResButton_pressed() -> void:
	CSquadUtil.editor.inspect_object(CSquadUtil.fgd, "", true)


#
# Updates `model` meta-properties on entities
#
func _on_UpdateFGDModelPaths_pressed() -> void:
	var dir: Directory = Directory.new()

	# Array of last generated ent_infos should be fine for this
	var entinfos := item_tree.collect_checked_ent_infos()
	if entinfos.empty():
		dprint.error('Gathered zero entities to update.', 'on:UpdateFGDModelPathsButton-pressed')
		return

	var raw_defs := CSquadUtil.fgd.get_fgd_classes()

	var entinfo: QodotFGDPointClass
	for idx in entinfos.size():
		entinfo = entinfos[idx].fgd_class
		var resource_path: String

		# Resolve original resource path
		for raw_defs_idx in raw_defs.size():
			var ent := (raw_defs[raw_defs_idx] as QodotFGDPointClass)
			if not ent or ent.classname != entinfo.classname:
				continue

			resource_path = ent.resource_path

			dprint.write('Found original resource path for %s: <%s>' % [
					entinfo.classname, resource_path ], 'on:UpdateFGDModelPathsButton-pressed')

		if not resource_path:
			dprint.warn('Failed to find resource_path for %s' % [ entinfo.classname ],
					'on:UpdateFGDModelPathsButton-pressed')
			continue

		if not dir.file_exists(resource_path):
			dprint.warn('Resolved resource path for %s not found: %s' % [ entinfo.classname, resource_path ],
					'on:UpdateFGDModelPathsButton-pressed')
			continue

		var new_model_path := CSquadUtil.Settings.tb_game_dir.global_to_usemtl(
					CSquadUtil.Settings.tb_game_dir.models_dir.plus_file(entinfo.classname + '.obj'))

		dprint.write('Updating resource: %s' % [ resource_path ], 'on:UpdateFGDModelPathsButton-pressed')
		dprint.write(' > New model path: %s' % [ new_model_path ], 'on:UpdateFGDModelPathsButton-pressed')

		load(resource_path).meta_properties['model'] = { path = new_model_path }


# TODO: Make into instanceable class so multiple can be active
var export_start_time_usec: int = -1
var export_time_usec: int = -1
func start_profile(title: String) -> void:
	if export_start_time_usec != -1:
		dprint.error('Profiling timer already started', 'stop_profile')
	export_start_time_usec = Time.get_ticks_usec()
func stop_profile() -> void:
	if export_start_time_usec == -1:
		dprint.error('Profiling timer not started yet', 'stop_profile')
		return
	export_time_usec = Time.get_ticks_usec() - export_start_time_usec
	export_start_time_usec == -1


#
# Batch processing starts/is called from here
#
func _on_BuildButton_pressed() -> void:
	_initialize_progress_bar_state()

	# Array of last generated ent_infos should be fine for this
	var entinfos := item_tree.collect_checked_ent_infos()
	if entinfos.empty():
		dprint.error('Gathered zero entities to export.', 'on:BuildButton-pressed')
		return

	indec_total = 0
	indec_total_digits = 0
	# Build all the data arrays for exporter at once to get total vert count
	var entinfo: FGDEntityObjectData
	var export_data_arr := [ ]
	for idx in entinfos.size():
		entinfo = entinfos[idx]
		var export_data := EntityExportData.new(entinfo, true)
		indec_total += export_data.indicies_count
		export_data_arr.push_back(export_data)
		#dprint.write('Total verts collected %d' % [ vert_total ], 'on:BuildButton-pressed')

	# Store length of vert total in decimal
	indec_total_digits = str(indec_total).length()

	_build_dprint('Built %d export data instances.' % [ export_data_arr.size() ])
	dump_build_debug_data(export_data_arr)

	# Show output panel and connect signals
	progress_text.text = ''
	progress.set_visible(true)
	progress_text.update()
	progress_bar.update()
	yield(get_tree().create_timer(exporter.YIELD_DURATION), exporter.YIELD_METHOD)
	exporter.connect("export_progress", self, '_update_progress_bar')

	start_profile('Export')
	var export_data: EntityExportData
	export_count = export_data_arr.size()
	for export_data_idx in export_count:
		# Progress bar
		curr_export_idx = export_data_idx
		export_data = export_data_arr[export_data_idx]

		dprint.write('Exporting obj for %s' % [ export_data.classname ])
		exporter.save_meshes_to_obj(export_data.get_mesh_data(), export_data.classname, "", false)

		# Await success or failure
		yield(exporter, "export_completed")

		# Commit to total
		indec_commit += export_data.indicies_count

		# Let ui breathe
		yield(get_tree().create_timer(exporter.YIELD_DURATION), exporter.YIELD_METHOD)
		progress.propagate_notification(NOTIFICATION_RESIZED)

	stop_profile()
	_on_export_complete(export_time_usec)
	exporter.disconnect("export_progress", self, '_update_progress_bar')


func _initialize_progress_bar_state() -> void:
	curr_export_idx = -1
	export_count = -1
	# Total vert count for all exports
	indec_total = 0
	# For dynamic padding
	indec_total_digits = 1
	# Increased by obj's vert count after finishing (for calculating total progress)
	indec_commit = 0


# Progress bar context vars
var curr_export_idx := -1
var export_count := -1
# Total vert count for all exports
var indec_total := 0
# For dynamic padding
var indec_total_digits := 1
# Increased by obj's vert count after finishing (for calculating total progress)
var indec_commit := 0

# <TOTAL-VERT-PERCENT-COMPLETE>% | Model <CURRENT-EXPORTED-MODEL-INDEX + 1>/<TOTAL-EXPORTS> | Mesh <CURRENT-MESH-NUM>/<TOTAL-MESHES>
#const PROGRESS_TEXT_TEMPLATE = '%3.2f%% | Model %02d/%02d | Mesh %02d/%02d'
# <TOTAL-INDEC-PERCENT-COMPLETE>% | Model <CURRENT-EXPORTED-MODEL-INDEX + 1>/<TOTAL-EXPORTS> | <TOTAL-INDEC-PROCESSED>/<TOTAL-INDECS>
const PROGRESS_TEXT_TEMPLATE = '%3.2f%% | Model %02d/%02d | %*d/%d'
#func _update_progress_bar(mesh_idx: int, surface_idx: int, vertex_idx: int, curr_surface_vert_total: int)-> void:
func _update_progress_bar(mesh_idx: int, surface_idx: int, indec_idx: int, curr_surface_indec_total: int)-> void:

	if mesh_idx == -1 or surface_idx == -1 or indec_idx == -1:
		return

	#progress_bar.set_value((vertex_idx + vertex_commit) / float(vert_total))

	# @TODO: Fully rename variables after testing
	var vertex_idx := indec_idx
	var vertex_commit := indec_commit
	var vert_total := indec_total
	var vert_total_digits := indec_total_digits

	progress_bar.set_value((vertex_idx + vertex_commit) / float(vert_total))
	dprint.write('Position: %8d | Curr Index: %8d | Commit: %8d | Total: %8d' % [
				vertex_idx + vertex_commit,
				vertex_idx,
				vertex_commit,
				vert_total
			], '_update_progress_bar')
	progress_text.set_text(PROGRESS_TEXT_TEMPLATE % [
			# %3.2f%%
			progress_bar.get_value() * 100.0,

			# Model %02d/%02d
			curr_export_idx + 1,
			export_count,

			# %*d/%d
			vert_total_digits,
			vertex_idx + vertex_commit,
			vert_total,
			#mesh_idx + 1,
			#curr_export_idx,
		])

	progress_bar.update()
	progress_text.update()

	# @TODO Figure out if this is still necessary
	progress.propagate_notification(NOTIFICATION_RESIZED)


# Just to make sure its actually at 100% when it should be (in theory)
func _on_export_complete(export_usec: int = -1) -> void:
	if export_usec < 1:
		progress_text.text = '100% ' + progress_text.text.substr(progress_text.text.find('%') + 1)
	else:
		var ms := export_time_usec / 1000 % 1000
		var sec := export_time_usec / 1000 / 1000 % 1000
		var mins := export_time_usec / 1000 / 1000 / 60 % 60
		var hours := export_time_usec / 1000 / 1000 / 60 / 60 % 60

		var time_str := "%02d:%02d:%02d.%03d" % [ hours, mins, sec, ms ]

		progress_text.text = '[%s] ' % [ time_str ] \
			+ progress_text.text.substr(progress_text.text.find('%') + 1)


export (bool) var BUILD_VERBOSE := true


func _build_dprint(msg: String) -> void:
	if not BUILD_VERBOSE: return
	dprint.write(msg, 'on:BuildButton-pressed')


# Outdated now, moved to indicies
func dump_build_debug_data(export_data_arr, ctx := 'on:BuildButton-pressed') -> void:
	if not BUILD_VERBOSE: return
	var export_data: EntityExportData
	for idx in export_data_arr.size():
		export_data = export_data_arr[idx]

		dprint.write('', ctx)
		dprint.write('Export #%02d: %s' % [ idx + 1, export_data.classname ], ctx)

		var mesh_data := export_data.get_mesh_data()
		for mesh_data_idx in mesh_data.size():
			var mesh_data_item = mesh_data[mesh_data_idx]

			dprint.write('    Mesh %d' % [ mesh_data_idx ], ctx)

			for datum_idx in mesh_data_item.size():
				var datum = mesh_data_item[datum_idx]

				if datum is ArrayMesh:
					var vert_count := 0
					for surf_idx in datum.get_surface_count():
						vert_count += datum.surface_get_arrays(surf_idx)[ArrayMesh.ARRAY_VERTEX].size()
					dprint.write('        Verticies: %d' % [ vert_count ], ctx)
				elif datum is Material:
					if not (datum as Material).get_name().empty():
						dprint.write('        Override:  %s' % [ (datum as Material).get_name() ], ctx)
				else:
					dprint.write('        Offset:    %s' % [ datum ], ctx)


# Using this kitchen sink class I figure out the best way to pack this
class EntityExportData:
	const MESHINFO = ObjBuilder.MESHINFO

	var dprint := CSquadUtil.dprint_for('EntityExportData')

	var data: FGDEntityObjectData
	var classname: String setget, get_classname
	var _mesh_data: Array
	var mesh_data: Array setget, get_mesh_data
	var vert_count := -1
	var indicies_count := -1

	func get_mesh_data() -> Array:
		if typeof(_mesh_data) == TYPE_NIL or _mesh_data.empty():
			build_mesh_data()

		return _mesh_data

	#func get_mesh() -> Mesh:
	#	return mesh_data[MESHINFO.MESH]

	func get_extractor() -> EntityMeshExtractor:
		return data.extractor

	func get_classname() -> String:
		return data.fgd_class.classname

	func build_mesh_data() -> void:
		_mesh_data.clear()
		_mesh_data = get_extractor().resolve_meshes(data.scene.instance())

		# Apply transforms/normalization for various mesh forms
		for info in _mesh_data:
			info[MESHINFO.MESH] = MeshUtils.ProcessMesh(
					info[MESHINFO.MESH],
					info[MESHINFO.OFFSET],
					CSquadUtil.Settings.scale_factor)

		# Also update vert count for progress
		update_vert_count()

	func update_vert_count() -> void:
		vert_count = 0
		for info in _mesh_data:
			var mesh = info[MESHINFO.MESH]
			for surf_idx in mesh.get_surface_count():
				vert_count += mesh.surface_get_arrays(surf_idx)[ArrayMesh.ARRAY_VERTEX].size()

	func update_indicies_count() -> void:
		vert_count = 0
		var item_idx := -1
		for info in _mesh_data:
			item_idx += 1
			var mesh = info[MESHINFO.MESH]
			for surf_idx in mesh.get_surface_count():
				if mesh.surface_get_arrays(surf_idx)[ArrayMesh.ARRAY_INDEX]:
					indicies_count += mesh.surface_get_arrays(surf_idx)[ArrayMesh.ARRAY_INDEX].size()
				else:
					# Fuck this is why I need to index problem meshes before
					print('------ No indicies on %s, Mesh %d, Surface %d -------' % [ self.classname, item_idx + 1, surf_idx ])

	func _init(ent_info: FGDEntityObjectData, build_mesh_data_immediate := true):
		self.data = ent_info
		if build_mesh_data_immediate:
			self.build_mesh_data()
			self.update_indicies_count()


func _on_ObjBuilderEntityTree_item_edited() -> void:
	var edited := item_tree.get_edited()
	if edited.is_checked(item_tree.COLUMNS.BUILD_BUTTON):
		build_button.set_disabled(false)
		update_entity_paths_button.set_disabled(false)
	elif item_tree.has_checked_item():
		build_button.set_disabled(false)
		update_entity_paths_button.set_disabled(false)
	else:
		build_button.set_disabled(true)
		update_entity_paths_button.set_disabled(true)


func _on_ObjBuilderEntityTree_button_pressed(item: TreeItem, column: int, id: int) -> void:
	dprint.write('Pressed: %s{ %s, %s }' % [ item, column, id ], 'on:tree-item-button-pressed')


# Some debug signals while I figure out whats not working
func _on_ObjExporter_export_started(object_name, mesh_count) -> void:
	pass
	#  print('Export Started: %s: %d' % [ object_name, mesh_count ])


func _on_ObjExporter_export_completed(object_name) -> void:
	pass
	#print('Export Completed: %s' % [ object_name ])
