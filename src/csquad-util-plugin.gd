extends EditorPlugin
tool

var plugin

const plugin_name = 'csquad-util'
const plugin_ui_name = 'CSquadUtil'
func get_plugin_name() -> String:
	return plugin_ui_name

const plugin_path := "res://addons/" + plugin_name

func get_plugin_icon() -> Texture:
	return preload("../icons/main-screen.png")


const debug: bool = true
const dprint_base_ctx := plugin_name
static func dprint(msg: String, ctx: String = "") -> void:
	if debug:
		print('[%s] %s' % [
			'%s%s' % [ dprint_base_ctx, ":" + ctx if len(ctx) > 0 else "" ],
			msg
		])


const MainPanel := preload("./ui/MainPanel.tscn")
var main_panel_instance: Node
const MAIN_PANEL_ENABLED := false

var ObjEntityDocRes := load('res://addons/csquad-util/src/ui/ObjEntityDock.tscn')
var objentity_dock_instance: Control

const NavMeshBuilderContainerPath := plugin_path + '/src/ui/NavMeshBuilderContainer.tscn'
const NavMeshBuilderContainerRes := preload(NavMeshBuilderContainerPath)

#var nav      := NavManager.new(NavMeshBuilder.new(self), NavMeshBuilderContainerRes.instance())
var objbuild: ObjBuilderManager
var nav: NavManager
# var objbuild = load('res://addons/csquad-util/src/ObjBuilderManager.gd').new(self)

# Debugging
var last_event_stage := '<NONE>'

func _init() -> void:
	dprint('', 'on:init')
	last_event_stage = 'INIT'

func _ready() -> void:
	dprint('', 'on:ready')
	last_event_stage = 'READY'
	dprint('Initializing input values', 'on:ready')

func _enter_tree() -> void:
	dprint('', 'on:enter-tree')
	last_event_stage = 'IN-TREE'
	
	# Load singleton
	add_autoload_singleton('CSquadUtil', 'res://addons/csquad-util/src/CSquadUtilGlobal.gd')
	CSquadUtil.plugin = self
	
	nav      = load('res://addons/csquad-util/src/NavManager.gd').new(NavMeshBuilder.new(self), NavMeshBuilderContainerRes.instance())
	objbuild = ObjBuilderManager.new(self)

	if MAIN_PANEL_ENABLED:
		dprint('Adding main panel', 'on:enter-tree')
		main_panel_instance = MainPanel.instance()
		# Add the main panel to the editor's main viewport.
		get_editor_interface().get_editor_viewport().add_child(main_panel_instance)
		#Hide the main panel. Very much required.
		main_panel_instance.make_visible(false)

	objentity_dock_instance = ObjEntityDocRes.instance()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, objentity_dock_instance)

	add_tool_menu_item('Run CSquadUtil Script', self, 'run_scratch_script')

	#region Main Screen Detection -  Init

	# Try to find controls immediately (it will fail if not ready yet).
	_on_editor_base_ready()
	# Also connect to the ready signal, so that it is correctly detected then.
	var editor_base = get_editor_interface().get_base_control()
	editor_base.connect("ready", self, "_on_editor_base_ready")
	# And connect to the signal that will trigger when a user actually interacts with top buttons.
	connect("main_screen_changed", self, "_on_main_screen_changed")

	#endregion Main Screen Detection -  Init

func _exit_tree() -> void:
	dprint('', 'on:exit-tree')
	last_event_stage = 'EXIT-TREE'

	#if main_panel_instance:
	#	main_panel_instance.queue_free()

	if objentity_dock_instance:
		dprint('Removing obj entity dock control', 'on:exit-tree')
		remove_control_from_docks(objentity_dock_instance)
		#objentity_dock_instance.queue_free()

	remove_tool_menu_item('Run CSquadUtil Script')

func enable_plugin() -> void:
	dprint('', 'on:plugin-enabled')
	last_event_stage = 'PLUGIN-ENABLED'

func disable_plugin() -> void:
	dprint('', 'on:plugin-disabled')
	last_event_stage = 'PLUGIN-DISABLED'

	remove_autoload_singleton('CSquadUtilGlobal')

func has_main_screen() -> bool:
	return MAIN_PANEL_ENABLED

var handled: WeakRef = weakref(null)

const HANDLES_DUMP_OBJ_PREVIEW := true
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
			dprint('<%s> Skipped: %s' % [ last_event_stage, object ], 'handles')
		return false
	elif HANDLES_DUMP_OBJ_PREVIEW:
		dprint('<%s> Checking: %s' % [ last_event_stage, object ], 'handles')

	if not is_inside_tree():
		dprint('[Out of tree]', 'handles')
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
		objbuild.ui.clear_edited()
		objbuild.set_visible(false)
		return true

	return false


# @NOTE: Originally wrote assuming it was a necessary part of the process of updating the various 
# components of the plugin, but not sure anymore
#func make_visible(visible: bool) -> void:
#	dprint('', 'make_visible')
#
#	if not is_inside_tree():
#		return
#
#	var curr_scene = get_editor_interface().get_edited_scene_root()
#	if is_instance_valid(nav):
#		nav.set_visible(visible if nav.builder.edited.has_handle else false)
#
#	if is_instance_valid(objbuild.ui) and objbuild.ui.is_visible_in_tree():
#		dprint('objbuild.ui.has_handle => %s' % [ objbuild.ui.has_handle ], 'make_visible')
#		objbuild.set_visible(visible if objbuild.ui.has_handle else false)


func edit(object: Object) -> void:
	if not is_inside_tree():
		dprint('<out of tree>', 'edit')

	if nav.builder.handles(object):
		nav.builder.edited.update(object)

	objbuild.edit(object)


var last_scratch_instance: EditorScript
func run_scratch_script(_arg):
	last_scratch_instance = load('res://addons/csquad-util/src/tool-menu-scratch.gd').new(plugin)


#region Main Screen Changes

const HANDLES_MAIN_SCREEN_WHITELIST := [
	'3D'
]

var active_main_screen: String = ""

func _on_main_screen_changed(screen_name) -> void:
	active_main_screen = screen_name
	# dprint('Updated main screen: %s' % [ active_main_screen ], 'on:main-screen-changed')

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
				dprint('Resolved main screen node with find_node method: %s => %s' % [ button_node, button_node.text ], 'on:editor-base-ready')
				_on_main_screen_changed(button_node.text)
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
			dprint('Resolved main screen node: %s => %s' % [ button_node, button_node.text ], 'on:editor-base-ready')
			_on_main_screen_changed(button_node.text)
			break

	#endregion Original

#endregion Main Screen Changes


#region Debugging

func handles_debug(object: Node) -> void:
	if not object is Node:
		return

	dprint("Inspecting Node: @%s" % [ object ], 'handles')
	dprint(" - Owner: @%s" % [ object.owner ], 'handles')

	var parent := (object as Node).get_parent()
	if parent:
		var count = parent.get_child_count()
		dprint(" - Preview of @%s's parent's %s children:" % [ object, count ], 'handles')
		dprint("   @%s:" % [ parent ], 'handles')
		var idx = 0
		for child in parent.get_children():
			idx = idx + 1
			dprint("     [%s/%s] %s─ @%s" % [ idx, count, "├" if idx < count else "└", child ], 'handles')
	else:
		dprint("@%s has no parent node." % [ object ], 'handles')

#endregion Debugging
