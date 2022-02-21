tool
extends Node
#
# Plugin utility singleton for accessing common functionality.
#


signal loaded()


const plugin_name      := 'csquad-util'
const plugin_name_ui   := 'CSquadUtil'
const plugin_path      := "res://addons/" + plugin_name
const DEFAULT_FGD_PATH := "res://addons/qodot/game-definitions/fgd/qodot_fgd.tres"

var dprint := dprint_for(self, Colorful.RED_BRIGHT)

var Settings := CSquadUtilSettings.new()
var _settings_node_path := NodePath('Settings')
var NavGenerator = Engine.get_singleton('NavigationMeshGenerator')
var Exporter
var plugin: EditorPlugin
var editor: EditorInterface
var _loaded := false
onready var Extractors := EntityMeshExtractors.new()
onready var fgd: QodotFGDFile = preload(DEFAULT_FGD_PATH)


func _init() -> void:
	dprint.write('', 'on:init')


func _enter_tree() -> void:
	dprint.write('', 'on:enter-tree')
	add_child(Settings, true)
	for node in get_children():
		if node is CSquadUtilSettings:
			_settings_node_path = get_path_to(node)


func _ready() -> void:
	_loaded = true
	emit_signal('loaded')
	dprint.write('', 'on:ready')
	Exporter = load('res://addons/csquad-util/src/ObjExporter.gd').new()


func _exit_tree() -> void:
	dprint.write('', 'on:exit-tree')


func register_plugin_instance(instance: EditorPlugin) -> void:
	plugin = instance
	editor = plugin.get_editor_interface()


# Main dprint constructor interface
static func dprint_for(obj, base_color = preload('./util/logger.gd').DEFAULT_COLORS.BASE) -> DebugPrint.Base:
	return preload('./util/logger.gd').Builder.get_for(obj, null, base_color)
