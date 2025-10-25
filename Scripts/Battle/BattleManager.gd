# BattleManager.gd
extends Node2D

@onready var player_panel = $UI/PlayerPanel
@onready var enemy_panel = $UI/EnemyPanel
@onready var actions_panel = $UI/ActionsPanel
@onready var trust_label: Label = $UI/PlayerPanel/PlayerStats/PlayerTrustLabel
@onready var trust_bar: ProgressBar = $UI/PlayerPanel/PlayerStats/PlayerTrustBar
@onready var trust_status: Label = $UI/PlayerPanel/PlayerStats/PlayerTrustStatus

var player_unit: Node
var current_enemy: Node = null

var is_player_turn: bool = true
var battle_active: bool = true
var available_actions: Array = []

func _ready():
	print("Дочерние узлы: ", get_children())
	print("Боевая сцена загружена!")
	# Показываем что сцена загрузилась
	$UI.show()
	
	# Ждём когда нам передадут врага
	print("Ожидаю врага...")


func start_battle_with(enemy: Node):  # ← УБИРАЕМ static!
	var battle_scene = load("res://Scenes/Battle/BattleScene.tscn").instantiate()
	battle_scene.setup_battle_with_enemy(enemy)
	get_tree().current_scene.add_child(battle_scene)
	
func setup_battle_with_enemy(enemy: Node):
	current_enemy = enemy
	print("Бой начат с: ", current_enemy.npc_name)
	
	# Игрок
	var player_data = RelationshipManager.player_data
	player_unit = load("res://Scenes/Units/Player/PlayerBattle.tscn").instantiate()
	player_unit.setup_visual(player_data, player_unit.get_node("Sprite2D"))
	$Units.add_child(player_unit)
	player_unit.position = Vector2(200, 300)
	player_unit.scale = Vector2(2, 2)
	
	# Враг уже на сцене, просто позиционируем его
	current_enemy.position = Vector2(600, 300)
	current_enemy.scale = Vector2(2, 2)
	$Units.add_child(current_enemy)
	
	# Создаем действия
	var attack_action = AttackAction.new()
	var defend_action = DefendAction.new()
	var persuade_action = PersuadeAction.new()
	available_actions = [attack_action, defend_action, persuade_action]
	
	update_trust_display()
	setup_action_buttons()
	start_player_turn()

func setup_battle():
	# Игрок
	var player_data = RelationshipManager.player_data
	player_unit = load("res://Scenes/Units/Player/PlayerBattle.tscn").instantiate()
	player_unit.setup_visual(player_data)
	$Units.add_child(player_unit)
	player_unit.position = Vector2(200, 300)
	player_unit.scale = Vector2(2, 2)
	
	# Создаем действия
	var attack_action = AttackAction.new()
	var defend_action = DefendAction.new()
	var persuade_action = PersuadeAction.new()
	available_actions = [attack_action, defend_action, persuade_action]

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
		action.execute(player_unit, current_enemy)
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
	defend_action.execute(player_unit, current_enemy)
	end_player_turn()

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
	# Проверяем игрока
	if not player_unit.is_alive():
		print("Игрок проиграл!")
		battle_active = false
		end_battle(false)
	# Проверяем врага
	elif current_enemy and not current_enemy.is_alive():
		print("Игрок победил!")
		battle_active = false
		end_battle(true)
	else:
		var player_hp = player_unit.unit_data.current_hp
		var enemy_hp = current_enemy.unit_data.current_hp if current_enemy else 0
		print("Бой продолжается. Игрок HP: " + str(player_hp) + ", Враг HP: " + str(enemy_hp))

func end_battle(victory: bool):
	print("Бой завершен. Победа: ", victory)
	
	# Возвращаем врага в мир если он жив
	if current_enemy and current_enemy.is_alive():
		current_enemy.setup_world_mode()
	
	# Удаляем сцену боя
	get_tree().current_scene.remove_child(self)
	queue_free()
	
	# Возвращаем управление в мир
	GameStateManager.end_battle()
