tool
class_name NousSettingsPanel
extends MarginContainer

var dprint = preload('../../util/logger.gd').Builder.get_for(self)

const SETTING = Nous.Settings.SETTING

onready var settings_base = $VBoxContainer/Center/SettingListContainer
onready var settings_dir_label: Label = $VBoxContainer/SettingsFolderLabel


func _ready() -> void:
	#if not Nous.Settings._loaded:
	#	yield(Nous.Settings, "loaded")

	for node in settings_base.get_children():
		if not node is HBoxContainer: continue

		var result = node.rebuild()
		if result is GDScriptFunctionState: yield(result, "complete")

	populate_settings()

	Nous.Settings.connect("settings_change", self, "populate_setting")


# Getting a setting's label/value container by its enum value/key
func get_settings_box(setting) -> NousSettingsPanelItem:
	var node_name: String = (
			setting
				if typeof(setting) == TYPE_STRING
			else
				Nous.Settings._SETTING_KEYS[setting]
	).to_upper()

	dprint.write("Getting setting container for %s" % [ node_name ], 'get:settings-box')
	return settings_base.get_node_or_null(node_name)


const SettingsDirTemplate := 'Settings File: %s'
func update_settings_dir_label() -> void:
	var base_color := get_color("font_color", "Label")
	base_color.a *= 0.6
	settings_dir_label.add_color_override("font_color", base_color)

	#var ref_min_size: Vector2 = settings_base.get_child(0).get_minimum_size()
	#var base_min_size: Vector2 = settings_dir_label.get_minimum_size()
	#base_min_size.y = ref_min_size.y
	#settings_dir_label.set_custom_minimum_size(base_min_size)

	var cfg_path := Nous.Settings.get_settings_path().simplify_path()
	if OS.has_feature('Windows'):
		var APPDATA := OS.get_environment('APPDATA').simplify_path()
		if not APPDATA.empty():
			cfg_path = cfg_path.replace(APPDATA, '%APPDATA%')
	else:
		cfg_path = cfg_path.replace(OS.get_environment('HOME').simplify_path(), '$HOME')
	settings_dir_label.set_text(SettingsDirTemplate % [ cfg_path ])


func populate_settings() -> void:
	dprint.write('Repopulating ui elements', 'populate_settings')
	update_settings_dir_label()
	for setting in SETTING:
		dprint.write('  - %s' % [ setting ], 'populate_settings')
		var container := get_settings_box(setting)
		if not is_instance_valid(container): continue

		dprint.write('  Type: %s' % [ Nous.Settings.SETTING_UI_MODES.keys()[SETTING[setting]] ], 'populate_settings')
		var value = Nous.Settings.get_setting(setting)
		if value == null:
			dprint.warn('Read null value for setting %s' % [ setting ], 'populate_settings')
			continue

		container.update_value(value)


func populate_setting(value, setting) -> void:
	# Fix for weird double signal bug
	if not is_instance_valid(settings_base): return

	#if typeof(setting) == TYPE_INT:
		#setting = SETTING[setting]

	dprint.write('Received update signal for setting: %s' % [ setting ], "populate_setting")
	dprint.write('  New value: %s' % [ value ], "populate_setting")
	get_settings_box(setting).update_value(value)
