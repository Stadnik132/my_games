class_name EnemyMoveState extends EnemyCombatState

@export var move_speed: float = 100.0
@export var arrive_distance: float = 10.0  # Когда считаем, что дошли

var target_position: Vector2

func enter() -> void:
	print_debug("MoveState: ENTER")
	_update_target()

func process(delta: float) -> void:
	# Проверяем, не нужно ли переключиться на атаку
	if brain and brain.should_attack():
		print_debug("MoveState: вижу цель, перехожу в ATTACK")
		transition_requested.emit("ATTACK")
		return
	
	# Обновляем цель (игрок мог переместиться)
	if brain:
		var new_target = brain.get_target_position()
		if new_target != target_position:
			target_position = new_target
			print_debug("MoveState: новая цель: ", target_position)

func physics_process(delta: float) -> void:
	if target_position == Vector2.ZERO:
		print_debug("MoveState: нет цели, возврат в IDLE")
		transition_requested.emit("IDLE")
		return
	
	# Вычисляем направление к цели
	var direction = (target_position - actor.global_position).normalized()
	var distance = actor.global_position.distance_to(target_position)
	
	# Проверяем, достаточно ли близко
	if distance <= arrive_distance:
		print_debug("MoveState: цель достигнута, перехожу в IDLE")
		transition_requested.emit("IDLE")
		return
	
	# Применяем движение (просто устанавливаем velocity)
	actor.velocity = direction * move_speed
	
	# Не вызываем move_and_slide() здесь! Actor сделает это в своём _physics_process

func exit() -> void:
	# Останавливаем движение при выходе из состояния
	actor.velocity = Vector2.ZERO

func _update_target() -> void:
	if brain:
		target_position = brain.get_target_position()
		print_debug("MoveState: цель установлена: ", target_position)
