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
	# В Idle проверяем ввод движения только если мы в бою
	# (в WORLD движением управляет Player.gd, не FSM)
	
	# Получаем ввод через Input (глобально)
	var input_vector = _get_input_vector()
	if input_vector != Vector2.ZERO:
		# Запоминаем направление для уворота/анимаций
		fsm.last_movement_direction = input_vector
		fsm.last_dodge_direction = input_vector
		transition_requested.emit("Walk")
		return
	
	apply_movement()

func handle_command(command: String, data: Dictionary = {}) -> void:
	match command:
		"attack":
			transition_requested.emit("Attack")
		"dodge":
			# Направление для уворота может прийти из data
			if data.has("direction"):
				fsm.last_dodge_direction = data["direction"]
			transition_requested.emit("Dodge")
		"block_start":
			transition_requested.emit("Block")
		"ability_selected":  # было "aiming_start"
			transition_requested.emit("Aim")

func get_allowed_transitions() -> Array[String]:
	return ["Walk", "Attack", "Dodge", "Block", "Aim", "Stun"]

# Вспомогательный метод для получения ввода
func _get_input_vector() -> Vector2:
	var input = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	return input.normalized() if input.length() > 0 else Vector2.ZERO
