tool
extends Node
#
# Plugin utility singleton for accessing common functionality.
#
# Current plan is:
# - Make CSquadSettings singleton both a member and a child node
# - Add dprint base here (or as a loaded script)
#

const plugin_name      := 'csquad-util'
const plugin_name_ui   := 'CSquadUtil'
const plugin_path      := "res://addons/" + plugin_name
const DEFAULT_FGD_PATH := "res://addons/qodot/game-definitions/fgd/qodot_fgd.tres"

var DPRINT: DebugPrint = preload('./util/logger.gd').new()

var plugin: EditorPlugin

var Settings := CSquadUtilSettings.new()
var Extractors := EntityMeshExtractors.new()

var _settings_node_path: NodePath
var fgd: QodotFGDFile = preload(DEFAULT_FGD_PATH)

var _loaded := false

var NavGenerator = Engine.get_singleton(
	'NavigationMeshGenerator'
		if Engine.get_version_info().hex >= 0x030500
	else 'EditorNavigationMeshGenerator' )

#func _init
#var _extractors
#var extractors := Extractors

func _init() -> void:
	pass

func _ready() -> void:
	_loaded = true
	pass

func _enter_tree() -> void:
	add_child(Settings, true)
	for node in get_children():
		if node is CSquadUtilSettings:
			_settings_node_path = get_path_to(node)
			break
	pass

func _exit_tree() -> void:
	pass

# Main dprint constructor interface
func dprint_for(obj) -> DebugPrint.Base:
	return DPRINT.Builder.get_for(obj)
