class_name IdleState extends CombatState
# Общий для Player и остальных NPC типа Actor/Enemy и т.д

func enter() -> void:
	super.enter()
	set_battle_velocity(Vector2.ZERO)
	
	# Определяем направление только влево/вправо
	var anim_direction = _get_horizontal_direction()
	EventBus.Animations.requested.emit(entity, "idle_battle_" + anim_direction, 0)

func _get_horizontal_direction() -> String:
	"""Возвращает 'left' или 'right' на основе последнего направления"""
	var dir = fsm.last_movement_direction
	if dir.x < 0:
		return "left"
	return "right"  # по умолчанию вправо

func physics_process(_delta: float) -> void:
	var move_vector = combat_component.get_move_vector()
	
	if move_vector != Vector2.ZERO:
		fsm.last_movement_direction = move_vector
		fsm.last_dodge_direction = move_vector
		transition_requested.emit("Walk")
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
			transition_requested.emit("Aim")

func get_allowed_transitions() -> Array[String]:
	return ["Walk", "Attack", "Dodge", "Block", "Aim", "Stun", "Cast"]
