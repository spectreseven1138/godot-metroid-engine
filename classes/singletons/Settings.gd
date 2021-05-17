extends Node

signal settings_changed

const _settings_file_path: String = "res://settings.cfg"
var _config: ConfigFile = ConfigFile.new()

func _ready():
	load_file()

func save_file():
	_config.save(_settings_file_path)

func load_file():
	_config.load(_settings_file_path)

func get(value_path: String):
	return get_split(value_path.split("/")[0], value_path.split("/")[1])

func set(value_path: String, value):
	set_split(value_path.split("/")[0], value_path.split("/")[1], value)

func get_split(category: String, option: String):
	return _config.get_value(category, option)

func set_split(category: String, option: String, value):
	emit_signal("settings_changed", category + "/" + option, value)
	_config.set_value(category, option, value)
