class_name ObjEntityDock
extends Control
tool

const debug: bool = true
const dprint_base_ctx := 'ObjEntityDock'
static func dprint(msg: String, ctx: String = "") -> void:
	if debug:
		print('[%s] %s' % [
			'%s%s' % [ dprint_base_ctx, ":" + ctx if len(ctx) > 0 else "" ],
			msg
		])

onready var item_list := $VBoxContainer/ScrollContainer/ObjBuilderItemList

func _init() -> void:
	dprint('', 'on:init')
	pass

func _ready() -> void:
	dprint('', 'on:ready')
	pass
	
func _enter_tree() -> void:
	dprint('', 'on:enter-tree')
	if CSquadUtil.Settings._loaded : pass
	else: yield(CSquadUtil.Settings, "ready")
	
func _exit_tree() -> void:
	dprint('', 'on:exit-tree')

var _output_dir: String = CSquadUtil.Settings.game_dir + "/models"
func _get_output_dir() -> String:
	return CSquadUtil.Settings.game_dir + "/models"
var output_dir setget, _get_output_dir

# Open output folder in operating system file manager
func _on_OpenFolderButton_pressed() -> void:
	var dir := Directory.new()
	if not (typeof(_output_dir) == TYPE_STRING and _output_dir.length() > 0):
		push_error('Invalid output_dir member value: "%s"' % [ output_dir ])
		return
		
	var g_output_dir = ProjectSettings.globalize_path(_output_dir)
	if dir.dir_exists(g_output_dir):
		OS.shell_open(g_output_dir)
