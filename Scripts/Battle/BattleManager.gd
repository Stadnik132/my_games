# BattleManager.gd - ПРОСТОЙ И РАБОЧИЙ
extends Node2D

# Ссылки на узлы UI интерфейса боя
@onready var player_panel = $UI/PlayerPanel
@onready var enemy_panel = $UI/EnemyPanel
@onready var actions_panel = $UI/ActionsPanel
@onready var trust_label: Label = $UI/PlayerPanel/PlayerStats/PlayerTrustLabel
@onready var trust_bar: ProgressBar = $UI/PlayerPanel/PlayerStats/PlayerTrustBar
@onready var trust_status: Label = $UI/PlayerPanel/PlayerStats/PlayerTrustStatus

# Переменные для участников боя - ПРОСТО BattleUnit!
var player_unit: BattleUnitData
var enemy_unit: BattleUnitData

# Переменные для управления очередностью ходов
var is_player_turn: bool = true
var battle_active: bool = true
var available_actions: Array = []

func _ready():
	print("Боевая сцена загружена!")
	setup_battle()
	update_trust_display()
	setup_action_buttons()
	start_player_turn()

func start_player_turn():
	is_player_turn = true
	print("--- Ход игрока ---")
	enable_action_buttons(true)

func start_enemy_turn():
	is_player_turn = false
	print("--- Ход врага ---")
	enable_action_buttons(false)
	process_enemy_turn()

func enable_action_buttons(enabled: bool):
	for button in actions_panel.get_children():
		button.disabled = not enabled

func process_enemy_turn():
	print("Враг атакует!")
	var damage = 10
	player_unit.take_damage(damage)
	check_battle_end()
	if battle_active:
		start_player_turn()

func update_trust_display():
	var current_trust = RelationshipManager.sync_level
	trust_label.text = "Доверие: " + str(current_trust)
	trust_bar.value = current_trust
	
	var status_text = ""
	if current_trust <= -50: status_text = "Вражда"
	elif current_trust <= 0: status_text = "Неприязнь" 
	elif current_trust <= 50: status_text = "Нейтрально"
	else: status_text = "Доверие"
	trust_status.text = status_text

func attempt_player_action(action: BattleAction) -> bool:
	var has_enough_trust = RelationshipManager.sync_level >= action.sync_required
	
	if has_enough_trust:
		action.execute(player_unit, enemy_unit)
		RelationshipManager.change_sync(action.sync_change)
		update_trust_display()
		return true
	else:
		handle_refusal(action)
		update_trust_display()
		return false

func handle_refusal(action: BattleAction):
	var refusal_penalty = action.refusal_penalty
	RelationshipManager.change_sync(refusal_penalty)
	print("Алексей отказался! Вместо этого защищается")
	var defend_action = DefendAction.new()
	defend_action.execute(player_unit, enemy_unit)
	end_player_turn()

# САМАЯ ВАЖНАЯ ЧАСТЬ - ПРОСТОЙ setup_battle!
func setup_battle():
	# Игрок из RelationshipManager КАК РАНЬШЕ
	var player_data = RelationshipManager.player_data
	player_unit = load("res://Scenes/Units/Player/PlayerBattle.tscn").instantiate()
	player_unit.setup_from_data(player_data)
	
	# Враг из готовой сцены КАК РАНЬШЕ!
	enemy_unit = load("res://Scenes/Units/Enemies/GuardEnemy.tscn").instantiate()
	
	# Добавляем юнитов на сцену
	$Units.add_child(player_unit)
	$Units.add_child(enemy_unit)
	
	# Позиционируем юнитов
	player_unit.position = Vector2(200, 300)
	enemy_unit.position = Vector2(600, 300)
	player_unit.scale = Vector2(2, 2)
	enemy_unit.scale = Vector2(2, 2)
	
	print("Бой начался! Игрок: " + str(player_unit.current_hp) + " HP, Враг: " + str(enemy_unit.current_hp) + " HP")
	
	# Создаем действия
	var attack_action = AttackAction.new()
	var defend_action = DefendAction.new() 
	var persuade_action = PersuadeAction.new()
	
	available_actions.append(attack_action)
	available_actions.append(defend_action)
	available_actions.append(persuade_action)

func setup_action_buttons():
	for child in actions_panel.get_children():
		child.queue_free()
	
	for action in available_actions:
		var button = Button.new()
		button.text = action.action_name
		var action_data = action
		button.pressed.connect(_on_action_selected.bind(action_data))
		actions_panel.add_child(button)

func _on_action_selected(action: BattleAction): 
	if not is_player_turn or not battle_active:
		return
	print("Игрок выбрал: " + action.action_name)
	var action_success = attempt_player_action(action)
	if action_success:
		end_player_turn()

func end_player_turn():
	enable_action_buttons(false)
	check_battle_end()
	if battle_active:
		start_enemy_turn()

func check_battle_end():
	if not player_unit.is_alive():
		print("Игрок проиграл!")
		battle_active = false
	elif not enemy_unit.is_alive():
		print("Игрок победил!")
		battle_active = false
	else:
		print("Бой продолжается. Игрок HP: " + str(player_unit.current_hp) + ", Враг HP: " + str(enemy_unit.current_hp))
