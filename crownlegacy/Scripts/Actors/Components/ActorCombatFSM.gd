# enemy_combat_fsm.gd
class_name ActorCombatFSM extends Node
## Конечный автомат для управления состояниями врага в бою.
## Содержит все возможные состояния и переключается между ними.

# Перечисление всех возможных состояний
enum State {
	IDLE,    # Ожидание
	MOVE,    # Движение к игроку
	ATTACK,  # Атака
	STUN     # Оглушение
}

# Текущее активное состояние (объект)
var current_state: ActorCombatState
# Тип текущего состояния (для быстрого сравнения)
var current_state_type: State

# Словарь для хранения всех состояний: тип -> объект
var _states: Dictionary = {}

# Ссылки на владельцев
var actor: Actor
var brain: AIBrain

# Сигнал об изменении состояния (для отладки и UI)
signal state_changed(old_state: State, new_state: State)

func setup(p_actor: Actor, p_brain: AIBrain) -> void:
	actor = p_actor
	brain = p_brain
	_create_states()

func _create_states() -> void:
	# Создаём каждое состояние
	_add_state(State.IDLE, ActorIdleState.new())
	_add_state(State.MOVE, ActorMoveState.new())
	_add_state(State.ATTACK, ActorAttackState.new())
	_add_state(State.STUN, ActorStunState.new())

func _add_state(state_type: State, state_instance: ActorCombatState) -> void:
	state_instance.setup(self, actor, brain)
	state_instance.name = State.keys()[state_type]
	
	# Подключаем сигнал перехода
	state_instance.transition_requested.connect(_on_state_transition_requested)
	
	add_child(state_instance)
	_states[state_type] = state_instance

func change_state(new_state: State) -> void:
	var old_state_type = current_state_type
	var old_state_name = State.keys()[old_state_type] if current_state != null else "none"
	var new_state_name = State.keys()[new_state]
	
	print_debug("FSM: попытка перехода ", old_state_name, " → ", new_state_name)
	
	# Если нет текущего состояния - просто устанавливаем новое
	if current_state == null:
		print_debug("FSM: первое состояние, устанавливаю ", new_state_name)
		current_state_type = new_state
		current_state = _states[new_state]
		current_state.enter()
		state_changed.emit(old_state_type, new_state)
		return
	
	# Если уже в этом состоянии - игнорируем
	if current_state_type == new_state:
		print_debug("FSM: уже в состоянии ", new_state_name, ", игнорирую")
		return
	
	# Нормальный переход
	print_debug("FSM: выход из ", old_state_name)
	current_state.exit()
	
	current_state_type = new_state
	current_state = _states[new_state]
	
	print_debug("FSM: вход в ", new_state_name)
	current_state.enter()
	
	state_changed.emit(old_state_type, new_state)
	print_debug("FSM: переход завершён")

func process(delta: float) -> void:
	if current_state:
		current_state.process(delta)

func physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_process(delta)

# Вспомогательные методы для проверки текущего состояния
func is_in_state(state: State) -> bool:
	return current_state_type == state

func get_state_name() -> String:
	if current_state:
		return State.keys()[current_state_type]
	return "NONE"

func _on_state_transition_requested(state_name: String) -> void:
	print_debug("FSM получил запрос перехода в: ", state_name)
	
	# Конвертируем строку в enum State
	match state_name:
		"IDLE":
			change_state(State.IDLE)
		"MOVE":
			change_state(State.MOVE)
		"ATTACK":
			change_state(State.ATTACK)
		"STUN":
			change_state(State.STUN)
		_:
			print_debug("FSM: неизвестное состояние: ", state_name)
