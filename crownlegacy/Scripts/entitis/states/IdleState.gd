class_name IdleState extends CombatState

func enter() -> void:
	super.enter()
	set_battle_velocity(Vector2.ZERO)
	
	# Включаем анимацию idle при входе в состояние
	var anim_direction = _get_animation_direction_from_fsm()
	EventBus.Animations.requested.emit(entity, "idle_" + anim_direction, 0)

func _get_animation_direction_from_fsm() -> String:
	var dir = fsm.last_movement_direction
	if abs(dir.x) > abs(dir.y):
		return "right" if dir.x > 0 else "left"
	else:
		return "down" if dir.y > 0 else "up"

func physics_process(_delta: float) -> void:
	# Получаем вектор движения из компонента (Input для Player, AI для Actor)
	var move_vector = combat_component.get_move_vector()
	
	if move_vector != Vector2.ZERO:
		# Запоминаем направление для уворота/анимаций
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
