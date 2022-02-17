tool
class_name ObjEntityDock
extends Control


var dprint := CSquadUtil.dprint_for(self)


onready var item_tree := $VBoxContainer/EntityTreeScrollContainer/ObjBuilderEntityTree as ObjBuilderEntityTree
onready var headers_box := $VBoxContainer/Headers as HSplitContainer
# For storing indicies each header
onready var headers: Array setget, get_header_labels


# @TODO: Move this to setting_changed signal instead of reading it every time
var output_dir: String setget, get_output_dir
var _output_dir: String


func _init() -> void:
	dprint.write('', 'on:init')
	pass


func _ready() -> void:
	dprint.write('', 'on:ready')
	_on_ReloadButton_pressed()
	pass


func _enter_tree() -> void:
	dprint.write('', 'on:enter-tree')
	if CSquadUtil.Settings._loaded : pass
	else: yield(CSquadUtil.Settings, "ready")
	
	#if not is_instance_valid(item_tree.theme):
	#	item_tree.theme = Theme.new()
	#	if theme:
	#		item_tree.theme.copy_theme(theme)
	#var theme_base = Theme.new()
	#theme_base.copy_default_theme()
	#var bg_base = theme_base.get_stylebox('bg', 'TreeItem')
	#item_tree.theme.set_stylebox('bg', 'TreeItem', bg_base)
	#item_tree.theme.set_stylebox('bg_focus', 'TreeItem', bg_base)
	#var title_normal
		

func _exit_tree() -> void:
	dprint.write('', 'on:exit-tree')


func get_output_dir() -> String:
	_output_dir = CSquadUtil.Settings.tb_game_dir.models_dir
	return _output_dir


# Open output folder in operating system file manager
func _on_OpenFolderButton_pressed() -> void:
	var dir := Directory.new()
	var out_dir := self.output_dir

	if not (typeof(out_dir) == TYPE_STRING and out_dir.length() > 0):
		push_error('Invalid output_dir member value: "%s"' % [ output_dir ])
		return

	var g_output_dir = ProjectSettings.globalize_path(self.output_dir)
	if dir.dir_exists(g_output_dir):
		OS.shell_open(g_output_dir)


func _update_theme() -> void:
	if (!Engine.editor_hint || !is_inside_tree()):
		return


func get_header_labels() -> Array:
	return $VBoxContainer/Headers.get_children()


func _on_ReloadButton_pressed() -> void:
	if is_inside_tree():
		item_tree.build_items()
	else:
		dprint.warn('Called outside of tree.', 'on:ReloadButton-pressed')


func _on_ObjBuilderEntityTree_item_activated():
	var root := item_tree.get_root()
	if not is_instance_valid(root):
		dprint.warn('No root in Tree.', 'on:Select-All-pressed')
		return
		
	# Double click implies last selected I guess
	var col_idx = item_tree.get_selected_column()
	if col_idx != item_tree.COLUMNS.CLASSNAME:
		return
		
	var sel = item_tree.get_selected()
	if not sel: return
	
	var data := sel.get_meta(item_tree.TREE_ITEM_DATA_KEYS.DATA) as FGDEntityObjectData
	if not data:
		return
	
	var interface := CSquadUtil.plugin.get_editor_interface()
	interface.set_main_screen_editor('3D')
	interface.open_scene_from_path(data.scene_path)
	interface.set_main_screen_editor('3D')
	

func set_all_buttons(value: bool) -> void:
	var root := item_tree.get_root()
	if not is_instance_valid(root):
		dprint.warn('No root in Tree.', 'on:Select-All-pressed')
		return
	root.call_recursive('set_checked', item_tree.COLUMNS.BUILD_BUTTON, value)


func _on_Select_All_pressed() -> void:
	set_all_buttons(true)


func _on_DeselectAll_pressed():
	set_all_buttons(false)
