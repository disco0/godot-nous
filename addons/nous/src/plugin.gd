tool
extends EditorPlugin

var plugin := self
var dprint = load(plugin_path.plus_file("src/util/logger.gd")).Builder.get_for('NousPlugin')

const MAIN_PANEL_ENABLED := true
const HANDLES_DUMP_OBJ_PREVIEW := true
const HANDLES_MAIN_SCREEN_WHITELIST := [ '3D' ]

const plugin_name     := 'nous'
const plugin_path     := "res://addons/" + plugin_name
const plugin_ui_name  := 'Nous'
const MainPanelRes    := preload("./ui/main-panels/MainPanel.tscn")
const MdlImportPlugin := preload('./mdl/mdl_importer/mdl_importer.gd')

var mdl_import:              MdlImportPlugin
var main_panel_instance:     Control
var last_scratch_instance:   EditorScript
var objbuild:                ObjBuilderManager
var export_obj_tool:         SceneObjBuilderMenuTool
var handled                  := weakref(null)
var active_main_screen       := ""


func _init() -> void:
	dprint.write('', 'on:init')
	add_autoload_singleton('Nous', 'res://addons/nous/src/NousGlobal.gd')


func _enter_tree() -> void:
	dprint.write('', 'on:enter-tree')

	if not Nous._loaded:
		yield(Nous, "loaded")

	Nous.register_plugin_instance(self)

	objbuild = ObjBuilderManager.new(self)
	Nous.add_child(objbuild)

	export_obj_tool = SceneObjBuilderMenuTool.new(self)
	Nous.add_child(export_obj_tool)
	export_obj_tool.register_plugin_init(self)

	mdl_import = MdlImportPlugin.new()
	add_import_plugin(mdl_import)

	if MAIN_PANEL_ENABLED:
		dprint.write('Adding main panel', 'on:enter-tree')
		main_panel_instance = MainPanelRes.instance()
		get_editor_interface().get_editor_viewport().add_child(main_panel_instance)
		main_panel_instance.visible = false

	add_tool_menu_item('Run Nous Scratch Script', self, 'run_scratch_script')

	_init_main_screen_checker()


func _ready() -> void:
	dprint.write('', 'on:ready')


func _destroy_interface() -> void:

	#remove_tool_menu_item('Run Nous Scratch Script')

	if MAIN_PANEL_ENABLED:
		if is_instance_valid(main_panel_instance):
			main_panel_instance.get_parent().remove_child(main_panel_instance)
			main_panel_instance.queue_free()

	if is_instance_valid(export_obj_tool):
		export_obj_tool.queue_free()

	if is_instance_valid(mdl_import):
		remove_import_plugin(mdl_import)
		mdl_import.queue_free()


func _exit_tree() -> void:
	dprint.write('', 'on:exit-tree')
	_destroy_interface()
	if is_instance_valid(self): self.queue_free()


func enable_plugin() -> void:
	dprint.write('', 'on:plugin-enabled')


func disable_plugin() -> void:
	dprint.write('', 'on:plugin-disabled')
	_destroy_interface()
	if is_instance_valid(self): self.queue_free()


func has_main_screen() -> bool: return MAIN_PANEL_ENABLED


func handles(object: Object) -> bool:
	# At the time of writing, this plugin works with map and entity scenes. Until that changes,
	# don't handle anything when not in the 3D panel.
	if not HANDLES_MAIN_SCREEN_WHITELIST.has(active_main_screen):
		return false

	# @NOTE: Doing this to avoid slowdowns when opening FGD file, this shouldn't effect anything
	#        but if something breaks this is the problem.
	if not (object is Node):
		return false

	if not is_inside_tree():
		dprint.error('handles called outside of tree. Passed object: %s' % [ object ], 'handles')
		return false

	# handles_debug(object)

	# For obj export (TODO: collect all this shit into UI script)
	if not is_instance_valid(objbuild):
		dprint.error('objbuild is not a valid instance', 'handles')

	elif objbuild.editable(object):
		objbuild.edit(object)
		objbuild.set_visible(true)
	else:
		objbuild.ui_3d.clear_edited()
		objbuild.set_visible(false)
		return false

	return false


#region Main Screen Changes

func _on_main_screen_changed(screen_name) -> void:
	active_main_screen = screen_name
	if MAIN_PANEL_ENABLED:
		main_panel_instance.visible = active_main_screen == plugin_ui_name

	dprint.write('Updated main screen: %s' % [ active_main_screen ], 'on:main-screen-changed')


func _on_editor_base_ready() -> void:
	var editor_base = get_editor_interface().get_base_control()
	if not editor_base.is_inside_tree() or editor_base.get_child_count() == 0:
		return

	var asset_lib_button = editor_base.find_node('AssetLib', true, false)
	# If found iterate through all its sibling ToolButtons
	if asset_lib_button is ToolButton:
		for button_node in asset_lib_button.get_parent().get_children():
			if (button_node is ToolButton) and button_node.pressed:
				dprint.write('Resolved main screen node with find_node method: %s => %s' % [ button_node, button_node.text ], 'on:editor-base-ready')
				emit_signal("main_screen_changed", button_node.text)
				return


func _init_main_screen_checker() -> void:
	_on_editor_base_ready()
	# Also connect to the ready signal, so that it is correctly detected then.
	var editor_base = get_editor_interface().get_base_control()
	editor_base.connect("ready", self, "_on_editor_base_ready")
	# And connect to the signal that will trigger when a user actually interacts with top buttons.
	connect("main_screen_changed", self, "_on_main_screen_changed")

#endregion Main Screen Changes


func get_plugin_name() -> String:
	return plugin_ui_name


func get_plugin_icon() -> Texture:
	return preload("../icons/main-screen.png")


#region Debugging

func handles_debug(object: Node) -> void:
	if not object is Node:
		return

	dprint.write("Inspecting Node: @%s" % [ object ], 'handles')
	dprint.write(" - Owner: @%s" % [ object.owner ], 'handles')

	var parent := (object as Node).get_parent()
	if parent:
		var count = parent.get_child_count()
		dprint.write(" - Preview of @%s's parent's %s children:" % [ object, count ], 'handles')
		dprint.write("   @%s:" % [ parent ], 'handles')
		var idx = 0
		for child in parent.get_children():
			idx = idx + 1
			dprint.write("     [%s/%s] %s─ @%s" % [ idx, count, "├" if idx < count else "└", child ], 'handles')
	else:
		dprint.write("@%s has no parent node." % [ object ], 'handles')

#endregion Debugging
