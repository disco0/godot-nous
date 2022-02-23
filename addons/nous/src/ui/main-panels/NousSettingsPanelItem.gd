tool
class_name NousSettingsPanelItem
extends HBoxContainer

signal setting_value_changed(value, setting_name)


const TEMPLATE_NAME := 'NousSettingsPanelItem'
const SETTING = Nous.Settings.SETTING
const SETTING_UI = Nous.Settings.SETTING_UI
const SETTING_UI_MODE = Nous.Settings.SETTING_UI_MODE
const UI_MODES = Nous.Settings.SETTING_UI_MODES

var mode: int setget ,get_mode

func get_mode() -> int:
	return Nous.Settings.SETTING_UI_MODE[get_setting_idx()]

func get_setting_idx() -> int:
	return SETTING[name]

var value_node: Control


func _ready() -> void:
	_update_name_label()


func set_setting_name(value: String) -> void:
	if not is_inside_tree():
		yield(self, "ready")

	var new_name := value.strip_edges()
	if new_name.empty(): return


func _update_name_label():
	if name == TEMPLATE_NAME or name.empty():
		$Label.set_text("")
		return
	$Label.set_text(SETTING_UI[get_setting_idx()] + ":")


func update_value(value) -> void:
	if not is_inside_tree():
		yield(self, "ready")

	if _mode > 0:
		rebuild()

	match _mode:
		UI_MODES.PATH:
			(value_node as LineEdit).set_text(value)

		UI_MODES.CHECKBOX:
			(value_node as CheckBox).set_value(value)

		UI_MODES.SPINBOX:
			(value_node as SpinBox).set_value(value)


func _initialize_mode() -> void:
	rebuild(get_mode())

var _mode: int = -1

func rebuild(new_mode: int = get_mode()) -> void:
	if not is_inside_tree():
		yield(self, "ready")

	if _mode >= 0 and _mode == new_mode: return


	match new_mode:
		UI_MODES.PATH:
			print('[rebuild] Item Mode: UI_MODES.PATH')
			$Value/LineEdit.set_visible(true)
			$Value/CheckBox.set_visible(false)
			$Value/SpinBox.set_visible(false)
			value_node = $Value/LineEdit

		UI_MODES.CHECKBOX:
			print('[rebuild] Item Mode: UI_MODES.CHECKBOX')
			$Value/LineEdit.set_visible(false)
			$Value/CheckBox.set_visible(true)
			$Value/SpinBox.set_visible(false)
			value_node = $Value/CheckBox

		UI_MODES.SPINBOX:
			print('[rebuild] Item Mode: UI_MODES.SPINBOX')
			$Value/LineEdit.set_visible(false)
			$Value/CheckBox.set_visible(false)
			$Value/SpinBox.set_visible(true)
			value_node = $Value/SpinBox

	_mode = new_mode


func _on_LineEdit_text_entered(new_text: String) -> void:
	emit_signal('setting_value_changed', new_text, name)

func _on_CheckBox_toggled(button_pressed: bool) -> void:
	emit_signal('setting_value_changed', button_pressed, name)

func _on_SpinBox_value_changed(value: float) -> void:
	emit_signal('setting_value_changed', value, name)


#func _get_property_list() -> Array:
#	var props := [ ]
#	props.push_back(property_dict('setting_name', TYPE_STRING, -1)) # , 'Name used for child label'))
#	return props
#
#static func category_dict(name: String) -> Dictionary:
#	return property_dict(name, TYPE_STRING, - 1, "", PROPERTY_USAGE_CATEGORY)
#
#static func property_dict(name: String, type: int, hint: int = -1, hint_string: String = "", usage: int = -1) -> Dictionary:
#	var dict: = {
#		"name":name,
#		"type":type
#	}
#
#	if hint != - 1:
#		dict["hint"] = hint
#
#	if hint_string != "":
#		dict["hint_string"] = hint_string
#
#	if usage != - 1:
#		dict["usage"] = usage
#
#	return dict


func _on_Label_renamed() -> void:
	_update_name_label()

var dialog: SettingPathValueDialog
func _on_PathButton_button_pressed() -> void:
	# Use for current_dir
	var curr := ($Value/LineEdit as LineEdit).get_text()

	dialog = SettingPathValueDialog.new(
			# Duct tape for now
			FileDialog.MODE_OPEN_DIR if name.ends_with('DIR')
			else FileDialog.MODE_OPEN_FILE)

	var curr_dir = curr
	# Duct tape for now
	if   name.ends_with("DIR"): pass
	elif name.ends_with("FILE_PATH"):
		curr_dir = curr_dir.get_base_dir()
		if "FGD" in name:
			dialog.filters = PoolStringArray([ '*.tres ; Resource File' ])

	dialog.set_text("Select %s" % [ $Label.get_text() ])
	dialog.current_dir = curr_dir
	dialog.name = 'PathSettingPopup'
	add_child(dialog)
	dialog.popup_centered_ratio(.75)
	var result = yield(dialog, "resolved")
	remove_child(dialog)
	dialog.queue_free()

	match result:
		null:
			print('[Failed]')

		false:
			print('[Cancelled]')

		_:
			Nous.Settings.set_setting(get_setting_idx(), result)


class SettingPathValueDialog extends FileDialog:
	# Emitted with:
	#   - path string on success
	#   - false on cancelled
	#   - null on failure
	signal resolved(value)

	var completed := false
	var value
	func _update_value(new_value) -> void:
		if new_value != null:
			value = new_value

	func _confirmed(path = null) -> void:
		if path != null:
			value = path

		if completed: return
		completed = true

		if value:
			emit_signal("resolved", value)
		else:
			emit_signal("resolved", null)

	func _cancel() -> void:
		completed = true
		emit_signal("resolved", false)

	func _init(type: int = FileDialog.MODE_OPEN_ANY, text := "", current_dir := "res://") -> void:
		self.current_dir = current_dir
		if not text.empty(): set_text(text)
		mode = type
		resizable = true

		get_cancel().connect("button_up", self, "_cancel")
		connect("popup_hide", self, "_cancel")
		match mode:
			MODE_OPEN_FILE:
				print('[File Mode]')
				connect("file_selected", self, "_confirmed")
			MODE_OPEN_DIR:
				print('[Directory Mode]')
				connect("dir_selected", self, "_confirmed")
