class_name StunState extends CombatState

# Стан: при получении урона (из любого состояния кроме Cast). Игрок не может ничего делать.
# Выход в Idle по истечении длительности.

@export var stun_duration: float = 0.5
var stun_timer: float = 0.0

func enter() -> void:
	stun_timer = stun_duration
	set_battle_velocity(Vector2.ZERO)
	EventBus.Combat.player_stunned.emit(true)

func process(delta: float) -> void:
	stun_timer -= delta
	if stun_timer <= 0.0:
		transition_requested.emit("Idle")

func physics_process(_delta: float) -> void:
	set_battle_velocity(Vector2.ZERO)
	apply_movement()

func exit() -> void:
	EventBus.Combat.player_stunned.emit(false)

func can_exit() -> bool:
	return stun_timer <= 0.0

func get_allowed_transitions() -> Array[String]:
	return ["Idle"]
