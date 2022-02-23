tool
class_name NousSettingsPanel
extends MarginContainer

const SETTING = Nous.Settings.SETTING

var dprint = preload('../../util/logger.gd').Builder.get_for(self)

onready var settings_base = $VBoxContainer/Center/SettingListContainer


func _ready() -> void:
	if not Nous.Settings._loaded:
		yield(Nous.Settings, "loaded")

	for node in settings_base.get_children():
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

func populate_settings() -> void:
	dprint.write('Repopulating ui elements', 'populate_settings')
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
