# PlayerCombatFSM.gd
class_name PlayerCombatFSM extends Node

signal state_changed(old_state: String, new_state: String)

@onready var states: Dictionary = {}
var current_state: CombatState = null
var attack_combo_step = 0
var	combo_window_timer = 0
var last_dodge_direction: Vector2 = Vector2.DOWN 
var cast_target_position: Vector2 = Vector2.ZERO

# Контекст
var player: CharacterBody2D
var player_data: PlayerData
var combat_component: Node
var current_ability: AbilityResource = null

func setup(p_player: CharacterBody2D, p_data: PlayerData, p_component: Node):
	player = p_player
	player_data = p_data
	combat_component = p_component
	
	# Инициализация состояний
	for child in get_children():
		if child is CombatState:
			var state_name = child.name.replace("State", "")
			states[state_name] = child
			
			# Передаём контекст
			child.player = player
			child.player_data = player_data
			child.combat_component = combat_component
			child.fsm = self
			child.setup_params()
			
			child.transition_requested.connect(_on_transition_requested)
	
	change_state("Idle")

func change_state(state_name: StringName):
	if not state_name in states:
		push_error("Состояние не найдено:", state_name)
		return
	
	var old_state = current_state.name.replace("State", "") if current_state else "None"
	
	# Проверка возможности выхода из СТАРОГО состояния
	if current_state and not current_state.can_exit():
		print("Нельзя выйти из состояния:", old_state)
		return
	
	# Проверка допустимости перехода
	if current_state and not state_name in current_state.get_allowed_transitions():
		print("Запрещён переход:", old_state, "->", state_name)
		return
	
	# Сброс комбо если выходим из Attack не в новую атаку
	if old_state == "Attack" and state_name != "Attack":
		attack_combo_step = 0
		combo_window_timer = 0
	
	if old_state == "Cast":
		cast_target_position = Vector2.ZERO
	
	# Выход из старого состояния
	if current_state:
		current_state.exit()
	
	# Вход в новое состояние
	var new_state = states[state_name]
	current_state = new_state
	current_state.enter()
	
	print("FSM:", old_state, "->", state_name)
	state_changed.emit(old_state, state_name)

func send_command(command: String, data: Dictionary = {}):
	"""Отправка команды текущему состоянию"""
	if current_state:
		current_state.handle_command(command, data)

func _on_transition_requested(state_name: StringName):
	change_state(state_name)

func _process(delta: float):
	if current_state:
		current_state.process(delta)

func _physics_process(delta: float):
	if current_state:
		current_state.physics_process(delta)

func get_current_state_name() -> String:
	if current_state:
		return current_state.name.replace("State", "")
	return "None"

func is_in_state(state_name: StringName) -> bool:
	return get_current_state_name() == state_name

func get_state_object(state_name: StringName) -> CombatState:
	return states.get(state_name)
