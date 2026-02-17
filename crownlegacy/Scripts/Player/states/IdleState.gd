class_name IdleState extends CombatState

# Idle: покой. Переходы во все кроме Cast — Walk, Attack, Dodge, Block, Aim.
# При вводе движения переходим в Walk.

func enter() -> void:
	set_battle_velocity(Vector2.ZERO)

func physics_process(_delta: float) -> void:
	var input_vector = player._get_input_vector()
	if input_vector != Vector2.ZERO:
		fsm.last_dodge_direction = input_vector
		transition_requested.emit("Walk")
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
	return ["Walk", "Attack", "Dodge", "Block", "Aiming", "Stun"]
