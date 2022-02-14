class_name ObjBuilderManager
extends Node
tool

const debug := false

const dprint_base_ctx = 'ObjBuilderManager'
static func dprint(msg: String, ctx: String = "") -> void:
	if debug:
		print('[%s] %s' % [
			'%s%s' % [ dprint_base_ctx, ":" + ctx if len(ctx) > 0 else "" ],
			msg
		])


const plugin_name = 'csquad-util'
const plugin_path := "res://addons/" + plugin_name

const ObjBuilderContainerResPath = plugin_path + '/src/ui/ObjBuilderContainer.tscn'
const ObjBuilderContainerRes = preload(ObjBuilderContainerResPath)

var plugin:  EditorPlugin
var ui:      ObjBuilderContainer
var builder: ObjBuilder

# Debugging
var last_event_stage := '<NONE>'

func _init(plugin: EditorPlugin, ui := ObjBuilderContainerRes.instance(), start_visible := false): # : NavMeshBuilder, ui: NavMeshBuilderContainer):
	dprint('', 'on:init')
	last_event_stage = 'INIT'

	self.plugin  = plugin
	self.ui      = ui

	ui.set_visible(start_visible)

	if plugin.is_inside_tree():
		link()
	else:
		plugin.connect("tree_entered", self, 'link')
	
	plugin.connect('tree_exiting', self, 'unload')

func _ready() -> void:
	last_event_stage = 'READY'
	if CSquadUtil.Settings._loaded: pass
	else: yield(CSquadUtil.Settings,"ready")

func _enter_tree() -> void:
	dprint('', 'on:enter-tree')
	last_event_stage = 'IN-TREE'

func _exit_tree() -> void:
	last_event_stage = 'EXIT-TREE'

# Set/clear reference
func edit(node) -> void:
	ui.edit(node)

func editable(node) -> bool:
	return ui.editable(node)

func handles(object) -> bool:
	return ui.handles(object)

func link():
	dprint('', 'link')
	plugin.add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, ui)

func unload():
	dprint('', 'unload')
	if is_instance_valid(ui):
		ui = null
	#if is_instance_valid(builder):
	#	builder = null
	if is_instance_valid(plugin):
		plugin.remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, ui)
		plugin = null

func set_visible(value: bool) -> void:
	if is_instance_valid(ui) and ui.is_inside_tree():
		ui.set_visible(value)
