class_name NavManager
extends Node
tool

const debug := false

const dprint_base_ctx = 'NavManager'
static func dprint(msg: String, ctx: String = "") -> void:
	if debug:
		print('[%s] %s' % [
			'%s%s' % [ dprint_base_ctx, ":" + ctx if len(ctx) > 0 else "" ],
			msg
		])

var ui:      NavMeshBuilderContainer
var builder: NavMeshBuilder

func _init(_builder, _ui, start_visible := false): # : NavMeshBuilder, ui: NavMeshBuilderContainer):
	self.builder = _builder
	self.ui      = _ui
	
	ui.set_visible(start_visible)
	
	builder.plugin.add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, ui)
	builder.plugin.connect('tree_exiting', self, 'unload')
	
func _enter_tree() -> void:
	if CSquadUtil.Settings._loaded : pass
	else: yield(CSquadUtil.Settings,"ready")

func link():
	dprint('Linking NavBuilder UI and script', 'link')
	ui.register_builder(builder)

func unload():
	builder.plugin.remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, ui)
	ui.queue_free()
	if is_instance_valid(builder):
		builder = null
	ui = null

func set_visible(value: bool) -> void:
	ui.set_visible(value)
