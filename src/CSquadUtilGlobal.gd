extends Node
tool

#
# Plugin utility singleton for accessing common functionality.
#
# Current plan is: 
# - Make CSquadSettings singleton both a member and a child node
# - Add dprint base here (or as a loaded script)
#

var plugin: EditorPlugin

const plugin_name = 'csquad-util'
const plugin_name_ui = 'CSquadUtil'
const plugin_path := "res://addons/" + plugin_name

var Settings := CSquadUtilSettings.new()
var _settings_node_path: NodePath

const DEFAULT_FGD_PATH := "res://addons/qodot/game-definitions/fgd/qodot_fgd.tres"
var fgd: QodotFGDFile = preload(DEFAULT_FGD_PATH)

func _init() -> void:
	pass
	
func _ready() -> void:
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
