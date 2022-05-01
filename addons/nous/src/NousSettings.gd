tool
class_name NousSettings
extends Node

signal loaded()
signal settings_change(value, setting_idx)

var dprint := preload('./util/logger.gd').Builder.get_for(self)

enum SETTING {
	GAME_DIR      = 0,
	FGD_FILE_PATH = 1,
	SCALE_FACTOR  = 2,
}

const DEFAULT_FGD_PATH := "res://addons/qodot/game-definitions/fgd/qodot_fgd.tres"
const setting_file: = "settings.cfg"
const SETTING_DEFAULTS := {
	SETTING.GAME_DIR:      'res://Maps',
	SETTING.FGD_FILE_PATH: DEFAULT_FGD_PATH,
	SETTING.SCALE_FACTOR:  4.5,
}
const SETTING_MEMBER := {
	SETTING.GAME_DIR:      "game_dir",
	SETTING.FGD_FILE_PATH: "fgd_file_path",
	SETTING.SCALE_FACTOR:  "scale_factor",
}
const SETTING_UI := {
	SETTING.GAME_DIR:      "TrenchBroom Game Directory",
	SETTING.FGD_FILE_PATH: "FGD Definiton Resource Path",
	SETTING.SCALE_FACTOR:  "Default Inverse Scale Factor",
}
enum SETTING_UI_MODES {
	PATH     = 0,
	CHECKBOX = 1,
	SPINBOX  = 2,
}
const SETTING_UI_MODE := {
	SETTING.GAME_DIR:      SETTING_UI_MODES.PATH,
	SETTING.FGD_FILE_PATH: SETTING_UI_MODES.PATH,
	SETTING.SCALE_FACTOR:  SETTING_UI_MODES.SPINBOX,
}

# Used for reverse lookup of setting name from SETTING enum
var _SETTING_KEYS := PoolStringArray(SETTING.keys())
var scale_factor: float = SETTING_DEFAULTS[SETTING.SCALE_FACTOR]
var fgd_file_path: String = SETTING_DEFAULTS[SETTING.FGD_FILE_PATH]
# tb_game_dir should be used instead of game_dir directly
var game_dir: String = SETTING_DEFAULTS[SETTING.GAME_DIR] setget set_game_dir
var tb_game_dir: TrenchBroomGameFolder
var _loaded := false
var config_file := ConfigFile.new()

onready var plugin_name: String = get_node('../').plugin_name
onready var directory_name: String = plugin_name
onready var plugin_path: String = (
		ProjectSettings.globalize_path("user://").plus_file(directory_name)
			if ProjectSettings.get_setting('application/config/use_custom_user_dir')
		else ProjectSettings.globalize_path("user://").replace(
				"app_userdata/%s/" % [
						ProjectSettings.get_setting('application/config/name') ],
				directory_name
		) + "/"
	)


func _init():
	#dprint.write('', 'on:init')
	name = 'Settings'


func _enter_tree() -> void:
	dprint.write('', 'on:enter-tree')
	pass


func _ready() -> void:
	dprint.write('', 'on:ready')
	if config_file.load(get_settings_path()) == OK:
		scale_factor  = config_file.get_value("settings", "scale_factor", scale_factor)
		game_dir      = config_file.get_value("settings", "game_dir", game_dir)
		fgd_file_path = config_file.get_value("settings", "fgd_file_path", fgd_file_path)
	else:
		config_file.save(get_settings_path())

		config_file.set_value("settings", "scale_factor", scale_factor)
		config_file.set_value("settings", "game_dir", game_dir)
		config_file.set_value("settings", "fgd_file_path", fgd_file_path)

		config_file.save(get_settings_path())

	# Initialize tb game folder
	dprint.write('Setting tb_game_dir', 'on:ready')
	_update_tb_game_dir()

	_loaded = true
	emit_signal("loaded")


# Generic setter based on SETTING enum
func set_setting(setting: int, value):
	if 0 > setting or setting > _SETTING_KEYS.size() - 1:
		push_error('Invalid setting index: %s' % [ setting ])

	var setting_name := _SETTING_KEYS[setting]

	var method := "set_%s" % [ (setting_name as String).to_lower() ]
	dprint.write('Calling setter: %s' % [ method ], 'set_setting')
	call(method, value)


func set_scale_factor(value: float) -> void:
	scale_factor = value
	save_setting("scale_factor", scale_factor)
	emit_signal("settings_change", scale_factor, SETTING.SCALE_FACTOR)


func set_fgd_file_path(value: String) -> void:
	if not ResourceLoader.exists(value):
		dprint.error('FGD file not found at new path: <%s>' % [ value ], 'set_fgd_file_path')

	fgd_file_path = value
	save_setting("fgd_file_path", fgd_file_path)
	_update_fgd()
	emit_signal("settings_change", fgd_file_path, SETTING.FGD_FILE_PATH)


func set_game_dir(value: String) -> void:
	var dir := Directory.new()
	if dir.dir_exists(value):
		game_dir = value
		save_setting("game_dir", game_dir)
		_update_tb_game_dir()
		emit_signal("settings_change", game_dir, SETTING.GAME_DIR)


func _update_fgd():
	var inst = load(fgd_file_path)
	if is_instance_valid(inst):
		Nous.fgd = inst
	else:
		dprint.error('Failed to load from configured path <%s>' % [ fgd_file_path ], '_update_fgd')


func _update_tb_game_dir():
	var new_instance = TrenchBroomGameFolder.new(game_dir)
	if is_instance_valid(new_instance):
		tb_game_dir = new_instance
	else:
		dprint.error('Failed to re-initialize ', '_update_tb_game_dir')


func save_setting(key: String, value):
	_check_plugin_path()
	var file: ConfigFile = ConfigFile.new()
	var err = file.load(get_settings_path())
	if err == OK:
		file.set_value("settings", key.to_lower(), value)
	file.save(get_settings_path())


func get_setting(key, default_value = ""):
	if typeof(key) == TYPE_INT:
		key = _SETTING_KEYS[key]

	_check_plugin_path()

	var norm_key = key.to_lower()

	var file: ConfigFile = ConfigFile.new()
	var err = file.load(get_settings_path())
	if err == OK:
		if file.has_section_key("settings", norm_key):
			return file.get_value("settings", norm_key)
		else:
			dprint.write("setting '%s' not found, now created" % [ norm_key ], 'get_setting')
			file.set_value("settings", norm_key, default_value)
			return default_value


func get_settings_path() -> String:
	return plugin_path.plus_file(setting_file)


func reset_plugin():
	delete_all_files(plugin_path)
	dprint.write("%s folder completely removed." % [ directory_name ], 'reset_plugin')


func delete_all_files(path : String):
	var directories = []
	var dir: Directory = Directory.new()
	dir.open(path)
	dir.list_dir_begin(true,false)
	var file = dir.get_next()
	while (file != ""):
		if dir.current_is_dir():
			var directorypath := dir.get_current_dir().plus_file(file)
			directories.append(directorypath)
		else:
			var filepath := dir.get_current_dir().plus_file(file)
			dir.remove(filepath)

		file = dir.get_next()

	dir.list_dir_end()

	for directory in directories:
		delete_all_files(directory)
	dir.remove(path)


func _check_plugin_path():
	var dir = Directory.new()
	if not dir.dir_exists(plugin_path):
		dir.make_dir(plugin_path)
		dprint.write("Created custom directory in user folder, it is placed at %s" % [ plugin_path ], '_check_plugin_path')
