extends CanvasLayer

var is_paused: bool = false

@onready var pause_panel: Panel = $PauseMenu
@onready var resume_button: Button = $PauseMenu/VBoxContainer/Button
@onready var save_button: Button = $PauseMenu/VBoxContainer/Button2
@onready var load_button: Button = $PauseMenu/VBoxContainer/Button3
@onready var settings_button: Button = $PauseMenu/VBoxContainer/Button4
@onready var quit_button: Button = $PauseMenu/VBoxContainer/Button5


func _ready() -> void:
	hide()
	if pause_panel:
		pause_panel.hide()
		_center_panel()
	
	# Подписи на кнопках
	resume_button.text = "Продолжить"
	save_button.text = "Сохранить"
	load_button.text = "Загрузить"
	settings_button.text = "Настройки"
	quit_button.text = "Выйти в меню"
	
	# Сигналы
	resume_button.pressed.connect(_on_resume_pressed)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()


func toggle_pause() -> void:
	is_paused = !is_paused
	get_tree().paused = is_paused
	
	if is_paused:
		show_menu()
	else:
		hide_menu()


func show_menu() -> void:
	show()
	if pause_panel:
		pause_panel.show()


func hide_menu() -> void:
	if pause_panel:
		pause_panel.hide()
	hide()


func _center_panel() -> void:
	await get_tree().process_frame
	var screen_size := DisplayServer.window_get_size()
	pause_panel.position = (Vector2(screen_size) - pause_panel.size) / 2


func _on_resume_pressed() -> void:
	toggle_pause()


func _on_settings_pressed() -> void:
	# Здесь позже можно открыть отдельное меню настроек
	pass


func _on_save_pressed() -> void:
	SaveManager.save_game("quicksave")


func _on_load_pressed() -> void:
	SaveManager.load_game("quicksave")
	toggle_pause()


func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn")
