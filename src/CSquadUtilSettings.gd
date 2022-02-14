class_name CSquadUtilSettings
extends Node
tool

#
# @TODO: Add a multi-mode settings change signal for broadcasting changes:
# settings_change(value, SETTING_TYPE)
# 

const plugin_name = "csquad-util"

var directory_name = plugin_name
var plugin_path: String = (
		ProjectSettings.globalize_path("user://").plus_file(directory_name)
			if ProjectSettings.get_setting('application/config/use_custom_user_dir')
		else ProjectSettings.globalize_path("user://") \
			.replace("app_userdata/%s/" % [ ProjectSettings.get_setting('application/config/name') ], directory_name) + "/"
	)

const setting_file : = "settings.cfg"
func get_settings_path() -> String:
	return plugin_path.plus_file(setting_file)

const DEFAULTS := {
	debug = true,
	auto_log = false,
	scale_factor = 4.5,
	# Trenchbroom game folder
	game_dir = 'res://Maps',
}

var debug:        bool   = DEFAULTS.debug
var auto_log:     bool   = DEFAULTS.auto_log
var scale_factor: float  = DEFAULTS.scale_factor
var game_dir:     String = DEFAULTS.game_dir

func _get_models_dir() -> String:
	models_dir = game_dir.plus_file('models')
	return models_dir
var models_dir: String = game_dir.plus_file('models') setget, _get_models_dir

var _loaded: bool = false

func _check_plugin_path():
	var dir = Directory.new()
	if not dir.dir_exists(plugin_path):
		dir.make_dir(plugin_path)
		if debug:
			printerr("[GitHub Integration] >> ","made custom directory in user folder, it is placed at ", plugin_path)

var config_file := ConfigFile.new()

func _init():
	print('[CSquadSettings:on:init]')
	name = 'Settings'
	_check_plugin_path()
	
func _enter_tree() -> void:
	print('[CSquadSettings:on:enter-tree]')
	
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
		scale_factor = config_file.get_value("settings", "scale_factor", scale_factor)
		
		config_file.save(get_settings_path())

	_loaded = true

func set_debug(d : bool):
	debug = d
	save_setting("debug", debug)

func set_auto_log(a : bool):
	auto_log = a
	save_setting("auto_log", auto_log)
	
func set_scale_factor(value: float) -> void:
	scale_factor = value	
	save_setting("scale_factor", scale_factor)
	
func set_game_dir(value: String) -> void:
	var dir := Directory.new()
	if dir.dir_exists(value):
		game_dir = value	
		save_setting("game_dir", game_dir)

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
