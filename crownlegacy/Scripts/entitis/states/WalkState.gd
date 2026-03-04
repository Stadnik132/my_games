class_name WalkState extends CombatState

func physics_process(delta: float) -> void:
	# Получаем ввод
	var input_vector = _get_input_vector()
	
	if input_vector != Vector2.ZERO:
		fsm.update_facing_direction(input_vector)
		# Двигаемся
		_handle_movement(input_vector, delta)
		
		# Запоминаем направления
		entity.last_movement_direction = input_vector
		fsm.last_dodge_direction = input_vector
	else:
		# Нет ввода - возвращаемся в Idle
		_handle_stop_movement(delta)
		transition_requested.emit("Idle")
		return
	
	apply_movement()

func handle_command(command: String, data: Dictionary = {}) -> void:
	match command:
		"attack":
			transition_requested.emit("Attack")
		"dodge":
			if data.has("direction"):
				fsm.last_dodge_direction = data["direction"]
			transition_requested.emit("Dodge")
		"block_start":
			transition_requested.emit("Block")
		"ability_selected":  # было aiming_start
			# Сохраняем выбранную способность
			if data.has("ability"):
				fsm.current_ability = data["ability"]
				fsm.current_slot_index = data.get("slot_index", -1)
			transition_requested.emit("Aim")

func get_allowed_transitions() -> Array[String]:
	return ["Idle", "Attack", "Dodge", "Block", "Aim", "Stun"]

# ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ====================
func _get_input_vector() -> Vector2:
	var input = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	return input.normalized() if input.length() > 0 else Vector2.ZERO

func _handle_movement(input_vector: Vector2, delta: float) -> void:
	if not entity is CharacterBody2D:
		return
	
	# Используем параметры из combat_config
	var speed = combat_config.move_speed
	var target_velocity = input_vector * speed
	entity.velocity = entity.velocity.lerp(target_velocity, combat_config.acceleration * delta)
	
	# Анимация
	var anim_direction = _get_animation_direction(input_vector)
	EventBus.Animations.requested.emit(entity, "walk_" + anim_direction, 0)

func _handle_stop_movement(delta: float) -> void:
	if not entity is CharacterBody2D:
		return
	
	entity.velocity = entity.velocity.lerp(Vector2.ZERO, combat_config.friction * delta)

func _get_animation_direction(input_vector: Vector2) -> String:
	if abs(input_vector.x) > abs(input_vector.y):
		return "right" if input_vector.x > 0 else "left"
	else:
		return "down" if input_vector.y > 0 else "up"
