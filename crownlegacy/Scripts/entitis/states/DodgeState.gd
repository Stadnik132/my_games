class_name DodgeState extends CombatState

var dodge_timer: float = 0.0
var dodge_direction: Vector2 = Vector2.ZERO
var dodge_speed: float = 0.0

# Уворот: только выход в Idle по окончании

func enter() -> void:
	super.enter()
	
	# Получаем направление из fsm (устанавливается в CombatComponent)
	dodge_direction = fsm.last_dodge_direction
	if dodge_direction == Vector2.ZERO:
		dodge_direction = Vector2.DOWN
	dodge_direction = dodge_direction.normalized()
	
	var distance = dodge_params.get("distance", 200.0)
	var duration = dodge_params.get("duration", 0.3)
	dodge_timer = duration
	dodge_speed = distance / duration if duration > 0 else 0.0
	
	set_battle_velocity(dodge_direction * dodge_speed)
	
	# Анимация
	EventBus.Animations.requested.emit(entity, "dodge", duration)
	
	# Сигнал о начале уворота
	EventBus.Combat.dodge.started.emit()

func physics_process(_delta: float) -> void:
	set_battle_velocity(dodge_direction * dodge_speed)
	apply_movement()

func process(delta: float) -> void:
	dodge_timer -= delta
	if dodge_timer <= 0.0:
		transition_requested.emit("Idle")

func handle_command(command: String, data: Dictionary = {}) -> void:
	match command:
		"stun":
			transition_requested.emit("Stun")

func exit() -> void:
	super.exit()
	set_battle_velocity(Vector2.ZERO)
	EventBus.Combat.dodge.completed.emit()

func can_exit() -> bool:
	return dodge_timer <= 0.0

func get_allowed_transitions() -> Array[String]:
	return ["Idle", "Stun"]
