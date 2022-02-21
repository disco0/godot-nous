tool
extends EditorPlugin


const MAIN_PANEL_ENABLED         := false
const HANDLES_DUMP_OBJ_PREVIEW   := true


var plugin := self
const plugin_name    := 'csquad-util'
const plugin_ui_name := 'CSquadUtil'
const plugin_path    := "res://addons/" + plugin_name

var dprint := preload("./util/logger.gd").Builder.get_for(self)

const MainPanelRes               := preload("./ui/MainPanel.tscn")
#const NavMeshBuilderContainerPath := plugin_path + '/src/ui/NavMeshBuilderContainer.tscn'
const NavMeshBuilderContainerRes := preload('./ui/NavMeshBuilderContainer.tscn')
const HANDLES_MAIN_SCREEN_WHITELIST := [ '3D' ]

var main_panel_instance:     Control
var last_scratch_instance:   EditorScript
var objbuild:                ObjBuilderManager # := load('res://addons/csquad-util/src/ObjBuilder3DMenuRes.gd').new(self)
var nav:                     NavManager        # := NavManager.new(NavMeshBuilder.new(self), NavMeshBuilderContainerRes.instance())
var export_obj_tool:         SceneObjBuilderMenuTool

var handled            := weakref(null)
var active_main_screen := ""
var last_event_stage   := '<NONE>'


func _init() -> void:
	dprint.write('', 'on:init')
	last_event_stage = 'INIT'


func _enter_tree() -> void:
	dprint.write('', 'on:enter-tree')
	last_event_stage = 'IN-TREE'

	# Load singleton
	add_autoload_singleton('CSquadUtil', 'res://addons/csquad-util/src/CSquadUtilGlobal.gd')
	if not CSquadUtil._loaded:
		dprint.write('Awaiting CSquadUtil ready', 'on:enter-tree')
		yield(CSquadUtil, "ready")
		dprint.write(' -> CSquadUtil ready', 'on:enter-tree')

	dprint.write('Passing plugin to singleton', 'on:enter-tree')
	CSquadUtil.register_plugin_instance(self)

	nav = NavManager.new(NavMeshBuilder.new(self), NavMeshBuilderContainerRes.instance())
	objbuild = ObjBuilderManager.new(self)
	CSquadUtil.add_child(objbuild)

	export_obj_tool = SceneObjBuilderMenuTool.new(self)
	CSquadUtil.add_child(export_obj_tool)
	export_obj_tool.register_plugin_init()

	if MAIN_PANEL_ENABLED:
		dprint.write('Adding main panel', 'on:enter-tree')
		main_panel_instance = MainPanelRes.instance()
		# Add the main panel to the editor's main viewport.
		get_editor_interface().get_editor_viewport().add_child(main_panel_instance)
		#Hide the main panel. Very much required.
		main_panel_instance.make_visible(false)

	add_tool_menu_item('Run CSquadUtil Scratch Script', self, 'run_scratch_script')

	_init_main_screen_checker()


func _ready() -> void:
	dprint.write('', 'on:ready')
	last_event_stage = 'READY'
	# Get plugin instance
	#var plugin_node := get_tree().root.get_node(plugin_ui_name)
	#plugin_node.add_child(export_obj_tool)


func _exit_tree() -> void:
	dprint.write('', 'on:exit-tree')
	last_event_stage = 'EXIT-TREE'

	if MAIN_PANEL_ENABLED:
		if main_panel_instance:
			main_panel_instance.queue_free()

	if export_obj_tool:
		export_obj_tool.queue_free()

	remove_tool_menu_item('Run CSquadUtil Scratch Script')

	self.queue_free()


func enable_plugin() -> void:
	dprint.write('', 'on:plugin-enabled')
	last_event_stage = 'PLUGIN-ENABLED'


func disable_plugin() -> void:
	dprint.write('', 'on:plugin-disabled')
	last_event_stage = 'PLUGIN-DISABLED'

	#remove_autoload_singleton('CSquadUtil')


func has_main_screen() -> bool:
	return MAIN_PANEL_ENABLED


func handles(object: Object) -> bool:
	# At the time of writing, this plugin works with map and entity scenes. Until that changes,
	# (or I notice its a problem dogfooding,) don't handle anything when not in the 3D panel.
	if not HANDLES_MAIN_SCREEN_WHITELIST.has(active_main_screen):
		return false

	# @NOTE: Doing this to avoid slowdowns when opening FGD file, this shouldn't effect anything
	#        but if something breaks this is the problem.
	# @NOTE: Main screen whitelist may make this unnecessary
	if not (object is Node):
		if HANDLES_DUMP_OBJ_PREVIEW:
			dprint.write('<%s> Skipped: %s' % [ last_event_stage, object ], 'handles')
		return false
	elif HANDLES_DUMP_OBJ_PREVIEW:
		dprint.write('<%s> Checking: %s' % [ last_event_stage, object ], 'handles')

	if not is_inside_tree():
		dprint.write('[Out of tree]', 'handles')
		push_error('%s >> handles called outside of tree. Passed object: %s' % [ plugin_name, object ])
		return false

	# handles_debug(object)

	if not is_instance_valid(nav):
		push_error('%s [%s] >> nav is not a valid instance.' % [ plugin_name, last_event_stage ])
	elif not is_instance_valid(nav.builder):
		push_error('%s [%s] >> nav.builder is not a valid instance.' % [ plugin_name, last_event_stage ])
		nav.set_visible(false)
	elif nav.builder.handles(object):
		handled = weakref(object)
		nav.builder.edited.update(object)
		nav.set_visible(true)
	else:
		nav.builder.edited.update(null)
		nav.set_visible(false)

	# For obj export (TODO: collect all this shit into UI script)

	if not is_instance_valid(objbuild):
		push_error('%s [%s] >> objbuild is not a valid instance.' % [ plugin_name, last_event_stage ])

	elif objbuild.editable(object):
		objbuild.edit(object)
		objbuild.set_visible(true)
	else:
		objbuild.ui_3d.clear_edited()
		objbuild.set_visible(false)
		return true

	return false


func edit(object: Object) -> void:
	if not is_inside_tree():
		dprint.write('<out of tree>', 'edit')

	if nav.builder.handles(object):
		nav.builder.edited.update(object)

	objbuild.edit(object)


func run_scratch_script(_arg):
	last_scratch_instance = ResourceLoader.load('res://addons/csquad-util/src/tool-menu-scratch.gd', "", false).new(plugin)


#region Main Screen Changes

func _on_main_screen_changed(screen_name) -> void:
	active_main_screen = screen_name
	# dprint.write('Updated main screen: %s' % [ active_main_screen ], 'on:main-screen-changed')

func _on_editor_base_ready() -> void:
	var editor_base = get_editor_interface().get_base_control()
	if (not editor_base.is_inside_tree() || editor_base.get_child_count() == 0):
		return

	#region big brain mode

	var asset_lib_button = editor_base.find_node('AssetLib', true, false)
	# If found iterate through all its sibling ToolButtons
	if asset_lib_button is ToolButton:
		for button_node in asset_lib_button.get_parent().get_children():
			if (button_node is ToolButton) and button_node.pressed:
				dprint.write('Resolved main screen node with find_node method: %s => %s' % [ button_node, button_node.text ], 'on:editor-base-ready')
				emit_signal("main_screen_changed", button_node.text)
				return

	#endregion big brain mode

	#region Original

	var editor_main_vbox
	for child_node in editor_base.get_children():
		if (child_node.get_class() == "VBoxContainer"):
			editor_main_vbox = child_node
			break
	if (!editor_main_vbox || !is_instance_valid(editor_main_vbox)):
		return
	if (editor_main_vbox.get_child_count() == 0):
		return

	var editor_menu_hb
	for child_node in editor_main_vbox.get_children():
		if (child_node.get_class() == "HBoxContainer"):
			editor_menu_hb = child_node
			break
	if (!editor_menu_hb || !is_instance_valid(editor_menu_hb)):
		return
	if (editor_menu_hb.get_child_count() == 0):
		return

	var match_counter = 0
	var editor_main_button_vb
	for child_node in editor_menu_hb.get_children():
		if (child_node.get_class() == "HBoxContainer"):
			match_counter += 1
		if (match_counter == 2):
			editor_main_button_vb = child_node
			break
	if (!editor_main_button_vb || !is_instance_valid(editor_main_button_vb)):
		return
	var main_screen_buttons = editor_main_button_vb.get_children()

	for button_node in main_screen_buttons:
		if !(button_node is ToolButton):
			continue
		if (button_node.pressed):
			dprint.write('Resolved main screen node: %s => %s' % [ button_node, button_node.text ], 'on:editor-base-ready')
			_on_main_screen_changed(button_node.text)
			break

	#endregion Original

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


# @TODO: Put this in its own separate node
func _input(event):
	if event is InputEventKey:
		if event.pressed:
			if event.scancode == KEY_F7:
				print("\n\n")
				run_scratch_script(null)
				print("\n\n")
