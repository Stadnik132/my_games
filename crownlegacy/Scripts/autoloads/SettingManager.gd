# SettingManager.gd (автозагрузка)
extends Node

# Графика
var resolution_index: int = 0
var window_mode_index: int = 0
var vsync: bool = true

# Аудио
var master_volume: float = 80.0
var music_volume: float = 80.0
var sfx_volume: float = 80.0

func _ready() -> void:
	load_settings()
	apply_audio_settings()

func get_resolution_index() -> int:
	return resolution_index

func set_resolution_index(index: int) -> void:
	resolution_index = index
	_apply_video_settings()

func get_window_mode_index() -> int:
	return window_mode_index

func set_window_mode_index(index: int) -> void:
	window_mode_index = index
	_apply_video_settings()

func get_vsync() -> bool:
	return vsync

func set_vsync(enabled: bool) -> void:
	vsync = enabled
	_apply_video_settings()

func get_volume(bus_name: String) -> float:
	match bus_name:
		"Master":
			return master_volume
		"Music":
			return music_volume
		"SFX":
			return sfx_volume
	return 50.0

func set_volume(bus_name: String, value: float) -> void:
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return
	
	# Преобразуем 0-100 в dB (от -60 до 0)
	var volume_db = linear_to_db(value / 100.0)
	AudioServer.set_bus_volume_db(bus_index, volume_db)
	
	# Сохраняем в словарь
	match bus_name:
		"Master":
			master_volume = value
		"Music":
			music_volume = value
		"SFX":
			sfx_volume = value
	
	save_settings()

func apply_audio_settings() -> void:
	"""Применяет сохранённые настройки громкости"""
	set_volume("Master", master_volume)
	set_volume("Music", music_volume)
	set_volume("SFX", sfx_volume)

func _apply_video_settings() -> void:
	# Применение разрешения
	match resolution_index:
		0:
			DisplayServer.window_set_size(Vector2i(1280, 720))
		1:
			DisplayServer.window_set_size(Vector2i(1366, 768))
		2:
			DisplayServer.window_set_size(Vector2i(1600, 900))
		3:
			DisplayServer.window_set_size(Vector2i(1920, 1080))
		4:
			DisplayServer.window_set_size(Vector2i(2560, 1440))
	
	# Применение режима окна
	match window_mode_index:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	
	# Применение VSync
	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("graphics", "resolution_index", resolution_index)
	config.set_value("graphics", "window_mode_index", window_mode_index)
	config.set_value("graphics", "vsync", vsync)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.save("user://settings.cfg")

func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") != OK:
		reset_to_default()
		return
	
	resolution_index = config.get_value("graphics", "resolution_index", 0)
	window_mode_index = config.get_value("graphics", "window_mode_index", 0)
	vsync = config.get_value("graphics", "vsync", true)
	master_volume = config.get_value("audio", "master_volume", 80.0)
	music_volume = config.get_value("audio", "music_volume", 80.0)
	sfx_volume = config.get_value("audio", "sfx_volume", 80.0)
	
	_apply_video_settings()
	apply_audio_settings()

func reset_to_default() -> void:
	resolution_index = 0
	window_mode_index = 0
	vsync = true
	master_volume = 80.0
	music_volume = 80.0
	sfx_volume = 80.0
	
	_apply_video_settings()
	apply_audio_settings()
	save_settings()
