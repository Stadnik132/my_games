# GameMenu.gd (исправленная версия - без прямых обращений к GameStateManager)
extends CanvasLayer

enum MenuState { CLOSED, MAIN, INVENTORY, SETTINGS, STATS }

# Константы состояний
const STATE_WORLD = 0
const STATE_DIALOGUE = 1
const STATE_BATTLE = 2
const STATE_MENU = 3
const STATE_CUTSCENE = 4
const STATE_GAME_OVER = 5

var menu_state: MenuState = MenuState.CLOSED
var _return_state: int = STATE_WORLD

@onready var main_panel: Panel = $MainPanel
@onready var inventory_panel: Panel = $InventoryPanel
@onready var settings_panel: Panel = $SettingsPanel
@onready var stats_panel: Panel = $StatsPanel  # Прямой путь к StatsPanel (на уровне CanvasLayer)
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	hide_all_panels()
	
	# Кнопки главного меню
	main_panel.get_node("VBoxContainer/InventoryButton").pressed.connect(_on_inventory_pressed)
	main_panel.get_node("VBoxContainer/SettingsButton").pressed.connect(_on_settings_pressed)
	main_panel.get_node("VBoxContainer/StatsButton").pressed.connect(_on_stats_pressed)
	main_panel.get_node("VBoxContainer/QuitButton").pressed.connect(_on_quit_pressed)
	
	# Кнопки возврата в подменю - ИСПРАВЛЕННЫЕ ПУТИ
	inventory_panel.get_node("BackButton").pressed.connect(_on_back_pressed)
	settings_panel.get_node("BackButton").pressed.connect(_on_back_pressed)
	stats_panel.get_node("VBoxContainer/BackButton").pressed.connect(_on_back_pressed)  # Исправлено!
	
	# Подписка на изменения глобального состояния
	EventBus.Game.state_changed.connect(_on_game_state_changed)
	
	set_process_input(true)

func _input(event: InputEvent) -> void:
	# Закрытие меню по Esc (если меню открыто)
	if event.is_action_pressed("ui_cancel") and menu_state != MenuState.CLOSED:
		# Запрашиваем переключение меню через EventBus
		EventBus.Game.menu_requested.emit()
		get_viewport().set_input_as_handled()

func _on_game_state_changed(new_state: int, old_state: int) -> void:
	match new_state:
		STATE_MENU:
			# Игра перешла в состояние MENU - открываем меню
			if menu_state == MenuState.CLOSED:
				_open_menu(old_state)
		_:
			# Игра вышла из MENU в другое состояние - закрываем меню
			if menu_state != MenuState.CLOSED:
				_close_menu_immediate()

func _open_menu(previous_state: int) -> void:
	_return_state = previous_state  # запоминаем, откуда пришли
	menu_state = MenuState.MAIN
	show_main_menu()
	animation_player.play("fade_in")

func _close_menu() -> void:
	animation_player.play("fade_out")
	await animation_player.animation_finished
	hide_all_panels()
	menu_state = MenuState.CLOSED
	# НЕ вызываем change_state - GameStateManager сам переключит состояние
	# по сигналу menu_requested при следующем нажатии

func _close_menu_immediate() -> void:
	hide_all_panels()
	menu_state = MenuState.CLOSED

func show_main_menu() -> void:
	hide_all_panels()
	main_panel.show()

func hide_all_panels() -> void:
	main_panel.hide()
	inventory_panel.hide()
	settings_panel.hide()
	stats_panel.hide()

func _on_inventory_pressed() -> void:
	menu_state = MenuState.INVENTORY
	hide_all_panels()
	inventory_panel.show()

	
	# Передаём компонент инвентаря в панель
	var player = get_tree().get_first_node_in_group("player")

	
	if inventory_panel.has_method("setup"):
		if player and player.has_node("InventoryComponent"):
			var inv = player.get_node("InventoryComponent")

			inventory_panel.setup(inv)

func _on_settings_pressed() -> void:
	menu_state = MenuState.SETTINGS
	hide_all_panels()
	settings_panel.show()
	if settings_panel.has_method("load_settings"):
		settings_panel.load_settings()

func _on_stats_pressed() -> void:
	menu_state = MenuState.STATS
	hide_all_panels()
	stats_panel.show()
	# StatsPanel сам обновит данные через _enter_tree

func _on_back_pressed() -> void:
	menu_state = MenuState.MAIN
	show_main_menu()

func _on_quit_pressed() -> void:
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Выйти в главное меню?"
	dialog.confirmed.connect(_quit_to_main_menu)
	dialog.close_requested.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func _quit_to_main_menu() -> void:
	# Закрываем меню через сигнал
	EventBus.Game.menu_requested.emit()
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn")
