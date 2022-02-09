class_name CSquadUtilPlugin
extends EditorPlugin
tool

const debug: bool = true

const _plugin_name = 'csquad-util'
const _plugin_path := "res://addons/" + _plugin_name

const _EditorIconTextureRect_script_path = _plugin_path + "/src/ui/EditorIconTextureRect.gd"

export (String) var plugin_name setget , get_plugin_name
export (String) var plugin_path := _plugin_path

const nav_mesh_instance_base_path = _plugin_path + "/src/res/NavigationMesh-CrueltySquadBase.tres"
export (NavigationMesh) var nav_mesh_instance_base := preload(nav_mesh_instance_base_path) as NavigationMesh

const nav_builder_path = _plugin_path + '/src/NavMeshBuilder.gd'

var plugin
var nav_builder = load(nav_builder_path).new(self)

const dprint_base_ctx := _plugin_name
static func dprint(msg: String, ctx: String = "") -> void:
	if debug:
		print('[%s] %s' % [
			'%s%s' % [ dprint_base_ctx, ":" + ctx if len(ctx) > 0 else "" ],
			msg
		])

func get_plugin_name() -> String:
	return _plugin_name

# Expected structure:
#```
# Level
# ├─ Global Light
# ├─ Navigation
# │  └─ NavigationMeshInstance
# ├─ WorldEnvironment
# └─ QodotMap
#```
func handles(object: Object) -> bool:
	# Ignore non-node types
	if not object is Node:
		return false

	# handles_debug(object)

	var level_node = nav_builder.EditedScene.TryResolveLevelNode(object)
	if level_node:
		# dprint('- Found level node in handles check (@%s <- @%s' % [ level_node, object ], 'handles')
		return true
	else:
		return false

func edit(object: Object) -> void:
	# dprint('Saving edited object and its level owner (@%s)' % [ object ], 'edit')
	nav.builder.edited.edited_ref = weakref(object)
	nav.builder.edited.level_ref  = weakref(nav.builder.EditedScene.TryResolveLevelNode(object))

	# dprint('Scene path: %s' % [ edited.scene_path ], 'edit')

const _NavMeshBuilderContainer_path = _plugin_path + '/src/ui/NavMeshBuilderContainer.tscn'

class NavManager:
	const dprint_base_ctx = 'NavManager'
	static func dprint(msg: String, ctx: String = "") -> void:
		if debug:
			print('[%s] %s' % [
				'%s%s' % [ dprint_base_ctx, ":" + ctx if len(ctx) > 0 else "" ],
				msg
			])

	var ui:      NavMeshBuilderContainer
	var builder: NavMeshBuilder
	
	func _init(_builder, _ui): # : NavMeshBuilder, ui: NavMeshBuilderContainer):
		self.builder = _builder
		self.ui      = _ui
		builder.plugin.add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, ui)
		
	func link():
		dprint('Linking NavBuilder UI and script', 'NavManager:link')
		ui.register_builder(builder)
		
	func unload():
		builder.plugin.remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, ui)
		ui.queue_free()
		builder.queue_free()
		ui = null
		builder = null
		
var nav: NavManager

func make_visible(visible: bool) -> void:
	if is_instance_valid(nav) and is_instance_valid(nav.ui):
		nav.ui.set_visible(visible)

func _init():
	plugin = self

func _enter_tree() -> void:
	dprint('Initialzing nav', 'on:enter-tree')
	nav = NavManager.new(NavMeshBuilder.new(plugin), load(_NavMeshBuilderContainer_path).instance())
	nav.link()
	
	dprint('Running early check for active edited scene', 'on:enter-tree')
	# For Godot Plugin Refresher: Manually fire off a make_visible check right at tree entry
	var current_scene = get_editor_interface().get_edited_scene_root()
	if is_instance_valid(current_scene) and handles(current_scene):
		make_visible(true)
		edit(current_scene)
		
	add_custom_type(
		"EditorIconTextureRect",
		"TextureRect",
		preload(_EditorIconTextureRect_script_path),
		get_editor_interface().get_base_control().theme.get_icon("TextureRect", "EditorIcons"))

func _exit_tree() -> void:
	dprint('Unloading NavManager', 'on:exit-tree')
	nav.unload()
	nav = null
		
	remove_custom_type("EditorIconTextureRect")

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
