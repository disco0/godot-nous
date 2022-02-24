tool
class_name SceneObjBuilderMenuTool
extends Node

const MESHINFO = MeshInfo.MESHINFO

var dprint := Nous.dprint_for(self)
var plugin := Nous.plugin
var exporter: ObjExporter
var editor: EditorInterface
var prompt: FileDialog
const ProgressPopup := preload('./ExportObjProgressPopup.tscn')
var progress: ExportObjProgressPanel
var out_dir: String
var export_as_objects := false
var extractor = preload('res://addons/nous/src/extractors/AnyMeshExtractor.gd').new()
var root_node: Node
var attach_base: Node


# This exporter will be used differently than as originally intended (configurable settings loaded
# via Nous.Settings) so wrapping it in a custom builder for later
func create_exporter() -> ObjExporter:
	var instance = ObjExporter.new()
	return instance


func assert_exporter():
	if not is_instance_valid(exporter):
		exporter = create_exporter()


func assert_attach_base():
	if not is_instance_valid(attach_base):
		attach_base = Nous.editor.get_base_control()


func _init(_plugin = null):
	name = 'SceneObjBuilderMenuTool'
	dprint.colors.context = Colorful.BLUE_BRIGHT
	dprint.write('', 'on:init')

	# Handle refreshes
	if not is_instance_valid(plugin):
		if _plugin != null and is_instance_valid(_plugin):
			dprint.write('Using plugin instance from argument', 'on:init')
			plugin = _plugin
		elif Nous.plugin != null and is_instance_valid(Nous.plugin):
			dprint.write('Using plugin instance from singleton', 'on:init')
			plugin = Nous.plugin


	if not is_instance_valid(editor):
		editor = EditorScript.new().get_editor_interface()


func _enter_tree() -> void:
	dprint.write('', 'on:enter-tree')


func _ready() -> void:
	dprint.write('', 'on:ready')

	# Update parent node for attaching popups
	# (Failed here, but keeping it for now)
	assert_attach_base()


func _exit_tree() -> void:
	dprint.write('', 'on:exit-tree')


func register_plugin_init(_plugin = null):
	if _plugin is EditorPlugin:
		if not (plugin is EditorPlugin):
			plugin = _plugin

	if plugin == null:
		dprint.error('Called with null plugin member.', 'register_plugin_init')
	if plugin.is_inside_tree():
		build_ui()
	else:
		plugin.connect("ready", self, 'build_ui')
	plugin.connect('tree_exiting', self, 'destroy_ui')


# Add to menu
func build_ui() -> void:
	assert_exporter()
	assert_attach_base()
	dprint.write('', 'build_ui')
	plugin.add_tool_menu_item('Export Scene to .obj', self, "_on_tool_item_clicked", null)
	plugin.add_tool_menu_item('Export Scene to .obj as objects', self, "_on_tool_item_multi_clicked", null)
	pass


# Remove from menu
func destroy_ui() -> void:
	dprint.write('', 'destroy_ui')
	plugin.remove_tool_menu_item('Export Scene to .obj')
	plugin.remove_tool_menu_item('Export Scene to .obj as objects')
	pass


func _on_tool_item_clicked(ub):
	assert_exporter()
	root_node = editor.get_edited_scene_root() as Node
	if not is_instance_valid(root_node):
		dprint.error('No current scene', '_on_tool_item_clicked')
		export_as_objects = false
		return
	if not root_node is Spatial:
		dprint.error('Scene root is not a spatial node', '_on_tool_item_clicked')
		export_as_objects = false
		return

	Nous.editor.set_main_screen_editor('3D')

	_init_outdir_window()


func _on_tool_item_multi_clicked(ub):
	export_as_objects = true
	_on_tool_item_clicked(ub)


func export_current_scene_to_obj():
	var mesh_infos := (extractor as EntityMeshExtractor).resolve_meshes(root_node)
	if mesh_infos.empty():
		dprint.warn('No meshes found in scene.', 'export_current_scene_to_obj')
		progress.hide()
		disconnect_exporter_progress()
		disconnect_prompt()
		return

	# Manually duplicate each mesh to avoid scuffing it in the 3D view
	for info in mesh_infos:
		var dupe = info[MESHINFO.MESH].duplicate()
		info[MESHINFO.MESH] = dupe

	# Moved here to pass in the total mesh count for now
	exporter.connect("export_progress", self, "_update_progress", [ mesh_infos.size() ])

	# Scale meshes (moved from ObjExport, still not 100% on where this should be in the process)
	for info in mesh_infos:
		MeshUtils.ProcessMesh(info[MESHINFO.MESH], info[MESHINFO.TRANSFORM], 1.0)

	dprint.write('Running exporter', 'export_current_scene_to_obj')
	# Append models subfolder to emulate current game folder structure: <BASE>/models/<EXPORTED>
	var scene_basename = root_node.get_tree().edited_scene_root.filename.get_file().get_basename()

	dprint.write('-> exporter.save_meshes_to_obj', 'export_current_scene_to_obj')
	exporter.save_meshes_to_obj(
			mesh_infos,
			scene_basename,
			"",
			export_as_objects)
	dprint.write('<- exporter.save_meshes_to_obj', 'export_current_scene_to_obj')


func _on_export_complete():
	dprint.write('Export complete.', 'on:export-complete')
	SignalUtils.DisconnectIfConnected(exporter, "export_completed", self, "_on_export_complete")
	SignalUtils.DisconnectIfConnected(exporter, "export_progress", self, "_update_progress")
	disconnect_prompt()
	disconnect_exporter_progress()

	# @TODO: Show completion screen or just hide?
	progress.hide()

	export_as_objects = false


func _on_prompt_visiblity_change() -> void:
	if prompt.visible:
		return

	disconnect_prompt()

	var dir: Directory = Directory.new()
	if (not out_dir.empty()) and dir.dir_exists(out_dir):
		dprint.write('Received valid directory <%s>' % [ out_dir], 'on:prompt-visibility-change')

		prompt.hide()
		progress.popup_centered()
		yield(progress.get_tree(), "idle_frame")
		progress.connect("popup_hide", self, "disconnect_exporter_progress")
		exporter.connect("export_completed", self, "_on_export_complete")

		export_current_scene_to_obj()

	else:
		disconnect_exporter_progress()
		export_as_objects = false

	root_node = null


func disconnect_exporter_progress() -> void:
	dprint.write('', 'disconnect_exporter_progress')
	SignalUtils.DisconnectIfConnected(exporter, "export_progress", self, "_update_progress")
	SignalUtils.DisconnectIfConnected(exporter, "export_progress", progress, "_update_progress")


func disconnect_prompt() -> void:
	dprint.write('', 'disconnect_prompt')
	SignalUtils.DisconnectIfConnected(prompt, 'confirmed', self, "_on_prompt_confirmed")
	SignalUtils.DisconnectIfConnected(prompt, 'dir_selected', self, "_on_dir_selected")
	SignalUtils.DisconnectIfConnected(prompt, "popup_hide", self, "_on_prompt_confirmed")
	SignalUtils.DisconnectIfConnected(prompt, 'visibility_changed', self, "_on_prompt_visiblity_change")


func _on_prompt_confirmed():
	# Use current dir if none selected
	if not out_dir or out_dir.empty() or prompt.current_dir != out_dir:
		out_dir = prompt.current_dir
		exporter.set_custom_tb_game_dir(out_dir)
	dprint.write('Output Path: <%s>' % [ out_dir ], 'on:prompt-confirmed')
	prompt.set_visible(false)


func _on_dir_selected(dir: String) -> void:
	dprint.write('Updated output path: <%s>' % [ dir ], 'on:dir-selected')
	out_dir = dir


func init_prompt() -> void:
	prompt = attach_base.get_node_or_null('OutDirPrompt')
	var last_dir: String = ""
	# Check for existing
	if prompt:
		last_dir = prompt.current_dir
		prompt.get_parent().remove_child(prompt)
		prompt.queue_free()
		prompt = null

	prompt = FileDialog.new()
	prompt.name = 'OutDirPrompt'
	prompt.set_mode_overrides_title(true)
	prompt.set_mode(FileDialog.MODE_OPEN_DIR)
	prompt.window_title = 'Select Output Directory'
	prompt.set_access(FileDialog.ACCESS_FILESYSTEM)
	if not last_dir.empty():
		prompt.current_dir = last_dir

	attach_base.add_child(prompt)

	dprint.write('Created output directory picker', 'init_prompt')


func init_progress() -> void:
	# Check for existing
	progress = attach_base.get_node_or_null('ExportObjProgressPopup')
	if progress:
		progress.get_parent().remove_child(progress)
		progress.queue_free()
		progress = null

	progress = ProgressPopup.instance()
	progress.name = 'ExportObjProgressPopup'
	progress.hide()

	attach_base.add_child(progress)

	dprint.write('Created export progress window', 'init_progress')


func _update_progress(m_idx, s_idx, vert_idx, vert_total, mesh_total):
	progress._update_progress(m_idx, s_idx, vert_idx, vert_total, mesh_total)


func _init_outdir_window():
	assert_attach_base()
	assert_exporter()
	dprint.write('Initializing interface popups', '_init_outdir_window')

	init_prompt()
	init_progress()

	# Set default now
	exporter.set_custom_tb_game_dir(prompt.current_dir)

	prompt.connect("confirmed", self, "_on_prompt_confirmed")
	prompt.connect("dir_selected", self, "_on_dir_selected")
	prompt.connect("popup_hide", self, "_on_prompt_visiblity_change")

	prompt.popup_centered_clamped(prompt.get_viewport_rect().size)

	#exporter.connect("export_completed", self, "_on_export_complete")
