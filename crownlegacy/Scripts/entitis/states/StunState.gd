class_name StunState extends CombatState

# Стан: при получении урона (из любого состояния кроме Cast). Сущность не может ничего делать.
# Выход в Idle по истечении длительности.

@export var stun_duration: float = 0.5
var stun_timer: float = 0.0

func enter() -> void:
	super.enter()
	stun_timer = stun_duration
	set_battle_velocity(Vector2.ZERO)
	
	# Анимация
	EventBus.Animation.requested.emit(entity, "stun", stun_duration)
	
	# Общий сигнал о начале стана
	EventBus.Combat.entity_stunned.emit(entity, true)
	
	print_debug("StunState: вход, длительность ", stun_duration)

func process(delta: float) -> void:
	super.process(delta)
	stun_timer -= delta
	if stun_timer <= 0.0:
		transition_requested.emit("Idle")

func physics_process(_delta: float) -> void:
	# В стане не двигаемся
	set_battle_velocity(Vector2.ZERO)
	apply_movement()

func handle_command(command: String, data: Dictionary = {}) -> void:
	# В стане игнорируем все команды
	pass

func exit() -> void:
	super.exit()
	EventBus.Combat.entity_stunned.emit(entity, false)

func can_exit() -> bool:
	return stun_timer <= 0.0

func get_allowed_transitions() -> Array[String]:
	return ["Idle"]
