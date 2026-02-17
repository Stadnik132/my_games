class_name WalkState extends CombatState

# Walk: передвижение в бою. Переходы: Idle, Attack, Dodge, Block, Aim.

func physics_process(delta: float) -> void:
	var input_vector = player._get_input_vector()
	if input_vector != Vector2.ZERO:
		player._handle_movement(input_vector, delta)
		player.last_movement_direction = input_vector
		fsm.last_dodge_direction = input_vector
	else:
		player._handle_stop_movement(delta)
		transition_requested.emit("Idle")
		return
	apply_movement()

func handle_command(command: String, data: Dictionary = {}) -> void:
	super.handle_command(command, data)
	match command:
		"attack":
			transition_requested.emit("Attack")
		"dodge":
			transition_requested.emit("Dodge")
		"block_start":
			transition_requested.emit("Block")
		"aiming_start":
			transition_requested.emit("Aiming")

func get_allowed_transitions() -> Array[String]:
	return ["Idle", "Attack", "Dodge", "Block", "Aiming", "Stun"]
