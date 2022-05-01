tool
class_name ObjBuilderManager
extends Node

var dprint := Nous.dprint_for(self)

#const ObjBuilderContainerResPath = plugin_path + '/src/ui/ObjBuilder3DMenu.tscn'
const ObjBuilder3DMenuRes := preload('./ui/ObjBuilder3DMenu.tscn')
const ObjEntityDocRes     := preload('./ui/ObjEntityDock/ObjEntityDock.tscn')

var plugin:  EditorPlugin
var ui_3d:   ObjBuilder3DMenu
var builder: ObjBuilder
var ui_dock: Control
var ui_visible_start := false
# Debugging
var last_event_stage := '<NONE>'


func _init(plugin: EditorPlugin, ui_3d := ObjBuilder3DMenuRes.instance(), start_visible := false): # : NavMeshBuilder, ui3d: NavMeshBuilderContainer):
	dprint.write('', 'on:init')
	last_event_stage = 'INIT'

	# Handle refreshes
	if not is_instance_valid(self.plugin):
		if is_instance_valid(plugin):
			self.plugin = plugin
		else:
			self.plugin = Nous.plugin

	self.ui_3d = ui_3d
	self.ui_visible_start = start_visible
	self.ui_dock = ObjEntityDocRes.instance()

	if plugin.is_inside_tree():
		link()
	else:
		plugin.connect("tree_entered", self, 'link')

	plugin.connect('tree_exiting', self, 'unload')


func _ready() -> void:
	last_event_stage = 'READY'


func _enter_tree() -> void:
	dprint.write('', 'on:enter-tree')
	last_event_stage = 'IN-TREE'


func _exit_tree() -> void:
	last_event_stage = 'EXIT-TREE'


# Set/clear reference
func edit(node) -> void:
	ui_3d.edit(node)


func editable(node) -> bool:
	return ui_3d.editable(node)


func handles(object) -> bool:
	return ui_3d.handles(object)


func link():
	dprint.write('', 'link')

	plugin.add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, ui_3d)
	ui_3d.set_visible(ui_visible_start)

	plugin.add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, ui_dock)
	ui_dock.set_visible(false)


func unload():
	dprint.write('', 'unload')

	var _plugin = plugin if is_instance_valid(plugin) else Nous.plugin
	if not is_instance_valid(_plugin):
		dprint.error('plugin member is not a valid instance, failed to access global plugin reference.', 'unload')

	else:
		if is_instance_valid(ui_3d):
			ui_3d.queue_free()
			plugin.remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, ui_3d)

		if is_instance_valid(ui_dock):
			ui_dock.queue_free()
			plugin.remove_control_from_docks(ui_dock)

		plugin = null

	#if is_instance_valid(builder):
	#	builder = null


func set_visible(value: bool) -> void:
	if is_instance_valid(ui_3d) and ui_3d.is_inside_tree():
		ui_3d.set_visible(value)
