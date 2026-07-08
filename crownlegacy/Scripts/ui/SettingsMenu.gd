extends Panel

@onready var graphics_root := $VBoxContainer/TabContainer/GraphicsTab
@onready var audio_root := $VBoxContainer/TabContainer/AudioTab
@onready var controls_root := $VBoxContainer/TabContainer/ControlsTab

func _ready() -> void:
	hide()
	_setup_controls()
	load_settings()
	
	$VBoxContainer/HBoxContainer/ApplyButton.pressed.connect(_on_apply_pressed)
	$VBoxContainer/HBoxContainer/ResetButton.pressed.connect(_on_reset_pressed)
	$VBoxContainer/HBoxContainer/BackButton.pressed.connect(_on_back_pressed)

func _setup_controls() -> void:
	var resolution_btn: OptionButton = graphics_root.get_node("Resolution")
	resolution_btn.clear()
	var resolutions = [
		"1280x720",
		"1366x768", 
		"1600x900",
		"1920x1080",
		"2560x1440"
	]
	for res in resolutions:
		resolution_btn.add_item(res)
	
	var window_btn: OptionButton = graphics_root.get_node("WindowMode")
	window_btn.clear()
	window_btn.add_item("Оконный")
	window_btn.add_item("Полноэкранный")
	window_btn.add_item("Без рамки")
	
	var master_slider: HSlider = audio_root.get_node("Master")
	master_slider.min_value = 0
	master_slider.max_value = 100
	master_slider.value_changed.connect(_on_master_volume_changed)
	
	var music_slider: HSlider = audio_root.get_node("Music")
	music_slider.min_value = 0
	music_slider.max_value = 100
	music_slider.value_changed.connect(_on_music_volume_changed)
	
	var sfx_slider: HSlider = audio_root.get_node("SFX")
	sfx_slider.min_value = 0
	sfx_slider.max_value = 100
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)

func load_settings() -> void:
	if not SettingManager:
		return
	
	var resolution_idx: int = SettingManager.get_resolution_index()
	var window_mode_idx: int = SettingManager.get_window_mode_index()
	var vsync: bool = SettingManager.get_vsync()
	
	graphics_root.get_node("Resolution").select(resolution_idx)
	graphics_root.get_node("WindowMode").select(window_mode_idx)
	graphics_root.get_node("VSync").button_pressed = vsync
	
	var master_vol: float = SettingManager.get_volume("Master")
	var music_vol: float = SettingManager.get_volume("Music")
	var sfx_vol: float = SettingManager.get_volume("SFX")
	
	audio_root.get_node("Master").value = master_vol
	audio_root.get_node("Music").value = music_vol
	audio_root.get_node("SFX").value = sfx_vol

func _on_master_volume_changed(value: float) -> void:
	SettingManager.set_volume("Master", value)

func _on_music_volume_changed(value: float) -> void:
	SettingManager.set_volume("Music", value)

func _on_sfx_volume_changed(value: float) -> void:
	SettingManager.set_volume("SFX", value)

func _on_apply_pressed() -> void:
	if not SettingManager:
		return
	
	SettingManager.set_resolution_index(graphics_root.get_node("Resolution").selected)
	SettingManager.set_window_mode_index(graphics_root.get_node("WindowMode").selected)
	SettingManager.set_vsync(graphics_root.get_node("VSync").button_pressed)
	
	SettingManager.save_settings()
	SettingManager.apply_audio_settings()
	
	hide()
	
	var main_menu = get_parent()
	if main_menu.has_method("show_main_menu"):
		main_menu.show_main_menu()

func _on_reset_pressed() -> void:
	if not SettingManager:
		return
	
	SettingManager.reset_to_default()
	load_settings()

func _on_back_pressed() -> void:
	load_settings()
	hide()
	
	var main_menu = get_parent()
	if main_menu.has_method("show_main_menu"):
		main_menu.show_main_menu()
