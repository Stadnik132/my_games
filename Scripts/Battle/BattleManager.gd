# BattleManager.gd
extends Node2D

# Ссылки на узлы UI - мы их создали вчера
@onready var player_panel = $UI/PlayerPanel
@onready var enemy_panel = $UI/EnemyPanel  
@onready var actions_panel = $UI/ActionsPanel

# Ссылки на кнопки действий (пока пустые, создадим позже)
@onready var attack_button: Button
@onready var defend_button: Button
@onready var persuade_button: Button

# Переменные для участников боя
var player_unit
var enemy_unit
# еременные для системы ходов
var is_player_turn: bool = true
var battle_active: bool = true

# Список доступных действий
var available_actions: Array = []

# Текущее состояние боя
var current_turn: String = "player"  # "player" или "enemy" (Кто начинает бой)

#Загрузка боевой сцены
func _ready():
	print("Боевая сцена загружена!")
	# Сначала настраиваем бой
	setup_battle()
	start_player_turn()  # Начинаем с хода игрока
	# Потом показываем действия
	setup_action_buttons()
	
func start_player_turn():
	is_player_turn = true
	print("--- Ход игрока ---")
	# Включаем кнопки действий для игрока
	enable_action_buttons(true)
	
func start_enemy_turn():
	is_player_turn = false
	print("--- Ход врага ---")
	# Выключаем кнопки действий для игрока
	enable_action_buttons(false)
		# Враг делает ход автоматически
	process_enemy_turn()
	
func enable_action_buttons(enabled: bool):
	for button in actions_panel.get_children():
		button.disabled = not enabled
		
func process_enemy_turn():
	# Временная реализация - враг всегда атакует
	print("Враг атакует!")
	var damage = 10  # Временное значение
	player_unit.take_damage(damage)
	
		# Проверяем не закончился ли бой
	check_battle_end()
	
	# Если бой продолжается - снова ход игрока
	if battle_active:
		start_player_turn()
	
#Настроки боевой системы: Атака, защита, убеждение
func setup_battle(enemy_type: String = "GuardEnemy"):
	player_unit = load("res://Scenes/Units/Player/PlayerUnit.tscn").instantiate()
	enemy_unit = load("res://Scenes/Units/Enemies/" + enemy_type + ".tscn").instantiate()
	
	$Units.add_child(player_unit)
	$Units.add_child(enemy_unit)
	
	player_unit.position = Vector2(100, 200)
	enemy_unit.position = Vector2(400, 200)
	
	print("Бой начался! Игрок: " + str(player_unit.current_hp) + " HP, Враг: " + str(enemy_unit.current_hp) + " HP")
	
	# СОЗДАЕМ ДЕЙСТВИЯ используя наши классы
	var attack_action = AttackAction.new()
	var defend_action = DefendAction.new() 
	var persuade_action = PersuadeAction.new()
	
	# Добавляем действия в массив available_actions
	available_actions.append(attack_action)
	available_actions.append(defend_action)
	available_actions.append(persuade_action)
	
	print("Создано действий: " + str(available_actions.size()))

func setup_action_buttons():
	print("Создаем кнопки действий...")
	
	# Очищаем старые кнопки (если есть)
	for child in actions_panel.get_children():
		child.queue_free()
	
	# Создаем кнопки для КАЖДОГО действия в массиве
	for action in available_actions:
		# Создаем новую кнопку
		var button = Button.new()
		# Устанавливаем текст кнопки = название действия
		button.text = action.action_name
		
		# Создаем локальную копию action для передачи в функцию
		var action_data = action
		# ПОДКЛЮЧАЕМ сигнал pressed: когда кнопку нажмут -> вызвать _on_action_selected
		button.pressed.connect(_on_action_selected.bind(action_data))
		
		# Добавляем кнопку в контейнер actions_panel
		actions_panel.add_child(button)
		
		print("Создана кнопка: " + action.action_name)

# Обработчик выбора действия
func _on_action_selected(action: BattleAction):
	if not is_player_turn or not battle_active:
		return  # Игрок не может ходить не в свой ход или если бой окончен
	
	print("Игрок выбрал: " + action.action_name)
	
	# Временно просто выполняем действие
	action.execute(player_unit, enemy_unit)
	
	# Завершаем ход игрока и передаем ход врагу
	end_player_turn()
	
func end_player_turn():
	# Выключаем кнопки действий
	enable_action_buttons(false)
	
	#Проверяем не закончился ли бой
	check_battle_end()
	
	if battle_active:
		start_enemy_turn()
	
func check_battle_end():
	if not player_unit.is_alive():
		print("игрок проиграл!")
		battle_active = false
	elif not enemy_unit.is_alive():
		print("Игрок победил!")
		battle_active = false
