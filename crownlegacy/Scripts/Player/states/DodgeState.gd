class_name DodgeState extends CombatState

var dodge_timer: float = 0.0
var dodge_direction: Vector2 = Vector2.DOWN
var dodge_speed: float = 400.0  # Высокая скорость для уворота
var can_aim: bool = false
var aiming_during_dodge: bool = false

func enter():
	print("DodgeState: уворот в направлении ", fsm.last_dodge_direction)
	
	dodge_direction = fsm.last_dodge_direction.normalized()
	if dodge_direction == Vector2.ZERO:
		dodge_direction = Vector2.DOWN
	
	dodge_timer = dodge_params.get("duration", 0.3)
	dodge_speed = dodge_params.get("distance", 80.0) / dodge_timer
	can_aim = false  # УБРАТЬ aiming_during_dodge логику
	
	# Проверяем выносливость
	if not player_data.use_stamina(dodge_params.get("stamina_cost", 25)):
		EventBus.Combat.dodge_failed.emit()
		transition_requested.emit("Idle")
		return
	
	# Блокируем обычное управление
	if player.has_method("set_movement_allowed"):
		player.set_movement_allowed(false)
	
	EventBus.Combat.dodge_started.emit()

func physics_process(delta: float):
	# ПРИНУДИТЕЛЬНОЕ ДВИЖЕНИЕ В НАПРАВЛЕНИИ УВОРОТА
	player.velocity = dodge_direction * dodge_speed
	player.move_and_slide()

func process(delta: float):
	dodge_timer -= delta
	
	# Разрешаем прицеливание во второй половине
	if dodge_timer <= dodge_params.get("duration", 0.3) * 0.5 and not can_aim:
		can_aim = true
	
	if dodge_timer <= 0:
		_finish_dodge()

func _finish_dodge():
	# Восстанавливаем управление
	if player.has_method("set_movement_allowed"):
		player.set_movement_allowed(true)
	
	# Останавливаем
	player.velocity = Vector2.ZERO
	
	# ВСЕГДА в Idle после уворота
	transition_requested.emit("Idle")
	
	EventBus.Combat.dodge_completed.emit()

func can_exit() -> bool:
	return dodge_timer <= 0

func exit():
	# Гарантированно восстанавливаем управление
	if player.has_method("set_movement_allowed"):
		player.set_movement_allowed(true)
	player.velocity = Vector2.ZERO

func get_allowed_transitions() -> Array[StringName]:
	return ["Idle", "Aiming"]
