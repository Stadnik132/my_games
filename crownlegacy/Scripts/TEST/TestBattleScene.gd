# TestBattleScene.gd
extends Node2D

func _ready() -> void:
	print("=== ТЕСТОВАЯ СЦЕНА БОЯ ЗАГРУЖЕНА ===")
	create_test_ui()

func create_test_ui() -> void:
	var button_container = VBoxContainer.new()
	add_child(button_container)
	button_container.position = Vector2(50, 50)
	
	# Кнопка "Начать бой (Игрок инициатор)"
	var start_player_btn = Button.new()
	start_player_btn.text = "Начать бой (Игрок инициатор)"
	start_player_btn.pressed.connect(start_player_initiated_battle)
	button_container.add_child(start_player_btn)
	
	# Кнопка "Начать бой (Враг инициатор)"
	var start_enemy_btn = Button.new()
	start_enemy_btn.text = "Начать бой (Враг инициатор)"
	start_enemy_btn.pressed.connect(start_enemy_initiated_battle)
	button_container.add_child(start_enemy_btn)
	
	# Кнопка "Атака"
	var attack_btn = Button.new()
	attack_btn.text = "АТАКА"
	attack_btn.pressed.connect(BattleManager.player_attack)
	button_container.add_child(attack_btn)
	
	# Кнопка "Защита"
	var defend_btn = Button.new()
	defend_btn.text = "ЗАЩИТА"
	defend_btn.pressed.connect(BattleManager.player_defend)
	button_container.add_child(defend_btn)
	
	# Кнопка "Показать состояние"
	var status_btn = Button.new()
	status_btn.text = "ПОКАЗАТЬ СОСТОЯНИЕ"
	status_btn.pressed.connect(show_battle_status)
	button_container.add_child(status_btn)

func start_player_initiated_battle() -> void:
	print("--- ТЕСТ: Игрок инициатор ---")
	BattleManager.start_battle(null, "player")
	show_battle_status()

func start_enemy_initiated_battle() -> void:
	print("--- ТЕСТ: Враг инициатор ---")
	BattleManager.start_battle(null, "enemy")
	show_battle_status()

func show_battle_status() -> void:
	print("=== ТЕКУЩЕЕ СОСТОЯНИЕ БОЯ ===")
	print("Состояние: ", BattleManager.get_battle_state_name())
	print("Бой активен: ", BattleManager.is_battle_active())
	print("========================")
