class_name WalkState extends CombatState

func physics_process(delta: float) -> void:
	var move_vector = combat_component.get_move_vector()

	if move_vector != Vector2.ZERO:
		fsm.update_facing_direction(move_vector)
		_handle_movement(move_vector, delta)

		fsm.last_movement_direction = move_vector
		fsm.last_dodge_direction = move_vector
	else:
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
		"ability_selected":
			if data.has("ability"):
				fsm.current_ability = data["ability"]
				fsm.current_slot_index = data.get("slot_index", -1)
			transition_requested.emit("Aim")


func get_allowed_transitions() -> Array[String]:
	return ["Idle", "Attack", "Dodge", "Block", "Aim", "Stun", "Cast"]


func _handle_movement(input_vector: Vector2, delta: float) -> void:
	if not entity is CharacterBody2D:
		return

	var speed = combat_config.move_speed

	if combat_component.has_method("get_ai_speed_multiplier"):
		speed *= combat_component.ai_speed_multiplier
	elif "ai_speed_multiplier" in combat_component:
		speed *= combat_component.ai_speed_multiplier

	var target_velocity = input_vector * speed
	entity.velocity = entity.velocity.lerp(target_velocity, combat_config.acceleration * delta)

	var anim_direction = _get_horizontal_direction(input_vector)
	EventBus.Animations.requested.emit(entity, "walk_" + anim_direction, 0)


func _handle_stop_movement(delta: float) -> void:
	if not entity is CharacterBody2D:
		return
	entity.velocity = entity.velocity.lerp(Vector2.ZERO, combat_config.friction * delta)


func _get_horizontal_direction(input_vector: Vector2) -> String:
	if input_vector.x < 0:
		return "left"
	return "right"
