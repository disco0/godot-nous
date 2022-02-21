tool
class_name CSquadUtilSettings
extends Node

signal settings_change(value, setting_name)

var dprint := preload('./util/logger.gd').Builder.get_for(self, null, Colorful.PURPLE_BRIGHT)


const setting_file : = "settings.cfg"
enum SETTING {
	GAME_DIR     = 0,
	SCALE_FACTOR = 1,
	AUTO_LOG     = 2,
	DEBUG        = 3,
}
const DEFAULTS := {
	SETTING.GAME_DIR:     'res://Maps',
	SETTING.SCALE_FACTOR: 4.5,
	SETTING.AUTO_LOG:     false,
	SETTING.DEBUG:        true,
}


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

# Used for reverse lookup of setting name from SETTING enum
var _SETTING_KEYS := PoolStringArray(SETTING.keys())
var debug: bool = DEFAULTS[SETTING.DEBUG]
var auto_log: bool = DEFAULTS[SETTING.AUTO_LOG]
var scale_factor: float = DEFAULTS[SETTING.SCALE_FACTOR]
# tb_game_dir should be used instead of game_dir directly.
var game_dir: String = DEFAULTS[SETTING.GAME_DIR] setget set_game_dir
var tb_game_dir: TrenchBroomGameFolder
var _loaded := false
var config_file := ConfigFile.new()


func _init():
	#dprint.write('', 'on:init')
	name = 'Settings'


func _enter_tree() -> void:
	dprint.write('', 'on:enter-tree')
	pass


func _ready() -> void:
	dprint.write('', 'on:ready')
	if config_file.load(get_settings_path()) == OK:
		debug        = config_file.get_value("settings", "debug", debug)
		auto_log     = config_file.get_value("settings", "auto_log", auto_log)
		scale_factor = config_file.get_value("settings", "scale_factor", scale_factor)
		game_dir     = config_file.get_value("settings", "game_dir", game_dir)
	else:
		config_file.save(get_settings_path())

		config_file.set_value("settings", "debug", debug)
		config_file.set_value("settings", "auto_log", auto_log)
		config_file.set_value("settings", "game_dir", game_dir)
		config_file.set_value("settings", "scale_factor", scale_factor)

		config_file.save(get_settings_path())

	# Initialize tb game folder
	dprint.write('Setting tb_game_dir', 'on:ready')
	_update_tb_game_dir()

	_loaded = true


# Generic setter based on SETTING enum
func set_setting(setting: int, value):
	if not setting in SETTING:
		push_error('Invalid setting index: %s' % [ setting ])

	var setting_name := _SETTING_KEYS[setting]

	# eh
	call("set_%s" % [ (setting_name as String).to_lower() ], value)


func set_debug(d : bool):
	debug = d
	save_setting("debug", debug)
	emit_signal("settings_change", debug, "debug")


func set_auto_log(a : bool):
	auto_log = a
	save_setting("auto_log", auto_log)
	emit_signal("settings_change", auto_log, "auto_log")


func set_scale_factor(value: float) -> void:
	scale_factor = value
	save_setting("scale_factor", scale_factor)
	emit_signal("settings_change", scale_factor, "scale_factor")


func set_game_dir(value: String) -> void:
	var dir := Directory.new()
	if dir.dir_exists(value):
		game_dir = value
		save_setting("game_dir", game_dir)
		_update_tb_game_dir()
		emit_signal("settings_change", game_dir, "game_dir")


func _update_tb_game_dir():
	var new_instance = TrenchBroomGameFolder.new(game_dir)
	if is_instance_valid(new_instance):
		tb_game_dir = new_instance
	else:
		push_error('Failed to re-initialize ')


func save_setting(key: String, value):
	_check_plugin_path()
	var file: ConfigFile = ConfigFile.new()
	var err = file.load(get_settings_path())
	if err == OK:
		file.set_value("settings", key, value)
	file.save(get_settings_path())


func get_setting(key: String, default_value = ""):
	_check_plugin_path()
	var file: ConfigFile = ConfigFile.new()
	var err = file.load(get_settings_path())
	if err == OK:
		if file.has_section_key("settings", key):
			return file.get_value("settings", key)
		else:
			print("[CSquadSettings:get_setting] setting '%s' not found, now created" % key)
			file.set_value("settings", key, default_value)


func get_settings_path() -> String:
	return plugin_path.plus_file(setting_file)


func reset_plugin():
	delete_all_files(plugin_path)
	print("[CSquadSettings:reset_plugin] %s folder completely removed."  % [ directory_name ])


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
		if debug:
			printerr("%s:_check_plugin_path >> ","made custom directory in user folder, it is placed at %s", [ plugin_name, plugin_path ])
