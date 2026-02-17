class_name PlayerCombatFSM extends Node

signal state_changed(old_state: String, new_state: String)

# Состояния: Idle, Walk, Attack, Dodge, Block, Aim, Cast, Stun
var states: Dictionary = {}
var current_state: CombatState = null

# Комбо атаки (сбрасывается при смене состояния)
var attack_combo_step: int = 0
var combo_window_timer: float = 0.0
var last_dodge_direction: Vector2 = Vector2.DOWN

# Контекст
var player: CharacterBody2D
var player_data: PlayerData
var combat_component: Node

# Aim/Cast
var current_slot_index: int = -1
var current_ability: AbilityResource = null
var cast_target_position: Vector2 = Vector2.ZERO

func setup(p_player: CharacterBody2D, p_data: PlayerData, p_component: Node) -> void:
	player = p_player
	player_data = p_data
	combat_component = p_component

	for child in get_children():
		if child is CombatState:
			var state_name = child.name.replace("State", "")
			states[state_name] = child
			child.player = player
			child.player_data = p_data
			child.combat_component = p_component
			child.fsm = self
			child.setup_params()
			child.transition_requested.connect(_on_transition_requested)

	change_state("Idle")

func change_state(state_name: String) -> void:
	print("=== FSM CHANGE STATE: ТЕКУЩЕЕ=", get_current_state_name(), " НОВОЕ=", state_name)  # NEW
	
	if not states.has(state_name):
		push_error("FSM: состояние не найдено: " + state_name)
		return

	var old_name = get_current_state_name()

	if current_state and not current_state.can_exit():
		print("FSM: текущее состояние не может выйти")
		return
	if current_state and not state_name in current_state.get_allowed_transitions():
		print("FSM: переход ", old_name, " -> ", state_name, " не разрешён")
		return

	if current_state:
		current_state.exit()

	current_state = states[state_name]
	current_state.enter()

	state_changed.emit(old_name, state_name)

func send_command(command: String, data: Dictionary = {}) -> void:
	print("FSM send_command: ", command, " data: ", data)
	
	# СНАЧАЛА обновляем данные FSM
	match command:
		"ability_selected":
			if data.has("slot_index"):
				current_slot_index = data.slot_index
			if data.has("ability"):
				current_ability = data.ability
		"cast":
			if data.has("slot_index"):
				current_slot_index = data.slot_index
			if data.has("ability"):
				current_ability = data.ability
	
	# ПОТОМ отправляем команду в текущее состояние с полными данными
	if current_state:
		current_state.handle_command(command, data)
	
	# Дополнительная обработка
	match command:
		"aim_cancel":
			cast_target_position = Vector2.ZERO
			current_slot_index = -1
			current_ability = null

func request_stun() -> void:
	"""Вызов при получении урона: переход в Stun, если не в Cast."""
	if get_current_state_name() == "Cast":
		return
	if not states.has("Stun"):
		return
	var old_name = get_current_state_name()
	if current_state:
		current_state.exit()
	current_state = states["Stun"]
	current_state.enter()
	state_changed.emit(old_name, "Stun")

func _on_transition_requested(state_name: String) -> void:
	change_state(state_name)

func _process(delta: float) -> void:
	if current_state:
		current_state.process(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_process(delta)

func get_current_state_name() -> String:
	if current_state:
		return current_state.name.replace("State", "")
	return "None"

func is_in_state(state_name: String) -> bool:
	return get_current_state_name() == state_name

func get_state_object(state_name: String) -> CombatState:
	return states.get(state_name)
