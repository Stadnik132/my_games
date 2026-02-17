class_name AttackState extends CombatState

var combo_step: int = 0
var attack_timer: float = 0.0
var can_combo_or_cancel: bool = false
var max_combo: int = 4
var attack_range: float = 150.0
var attack_angle_deg: float = 90.0

func enter() -> void:
	combo_step = fsm.attack_combo_step
	if combo_step == 0 or fsm.combo_window_timer <= 0.0:
		combo_step = 1
		fsm.attack_combo_step = 1
		fsm.combo_window_timer = attack_params.get("combo_window", 1.2)
	else:
		fsm.attack_combo_step = combo_step

	attack_timer = attack_params.get("attack_duration", 0.8)
	can_combo_or_cancel = false
	max_combo = attack_params.get("max_combo_steps", 4)

	_perform_attack()
	EventBus.Combat.basic_attack_hit.emit(combo_step, [])

func physics_process(_delta: float) -> void:
	set_battle_velocity(Vector2.ZERO)
	apply_movement()

func process(delta: float) -> void:
	attack_timer -= delta
	fsm.combo_window_timer -= delta
	if not can_combo_or_cancel and attack_timer <= 0.3:
		can_combo_or_cancel = true
		EventBus.Combat.combo_window_opened.emit()
	if attack_timer <= 0.0:
		_finish_attack()

func _finish_attack() -> void:
	if can_combo_or_cancel:
		EventBus.Combat.combo_window_closed.emit()
	transition_requested.emit("Idle")

func _perform_attack() -> void:
	var base_damage = attack_params.get("base_damage", 10)
	var combo_multipliers = attack_params.get("combo_damage", [1.0, 1.2, 1.5, 2.0])
	var idx = mini(combo_step - 1, combo_multipliers.size() - 1)
	var mult = combo_multipliers[idx] if idx >= 0 else 1.0
	var final_damage = int(base_damage * mult)
	var damage_data = DamageData.create_physical(final_damage, 0.0)
	var enemies = _find_enemies_in_cone()
	for enemy in enemies:
		if enemy.has_method("apply_damage_data"):
			enemy.apply_damage_data(damage_data, player)
		elif enemy.has_method("apply_combat_damage_data"):
			enemy.apply_combat_damage_data(damage_data, player)

func _find_enemies_in_cone() -> Array:
	var list: Array = []
	var pos = player.global_position
	var dir = player.last_movement_direction.normalized()
	if dir == Vector2.ZERO:
		dir = fsm.last_dodge_direction.normalized() if fsm.last_dodge_direction != Vector2.ZERO else Vector2.DOWN
	for node in get_tree().get_nodes_in_group("enemies"):
		var to_enemy = (node.global_position - pos).normalized()
		if pos.distance_to(node.global_position) <= attack_range:
			if rad_to_deg(acos(dir.dot(to_enemy))) <= attack_angle_deg * 0.5:
				list.append(node)
	return list

func handle_command(command: String, data: Dictionary = {}) -> void:
	super.handle_command(command, data)
	if not can_combo_or_cancel:
		return
	match command:
		"attack":
			if combo_step < max_combo:
				fsm.attack_combo_step = combo_step + 1
				EventBus.Combat.combo_window_closed.emit()
				transition_requested.emit("Attack")
			else:
				_reset_combo()
				transition_requested.emit("Idle")
		"dodge":
			_reset_combo()
			transition_requested.emit("Dodge")
		"block_start":
			_reset_combo()
			transition_requested.emit("Block")
		"aiming_start":
			_reset_combo()
			transition_requested.emit("Aiming")

func _reset_combo() -> void:
	fsm.attack_combo_step = 0
	fsm.combo_window_timer = 0.0
	EventBus.Combat.combo_window_closed.emit()

func can_exit() -> bool:
	return can_combo_or_cancel or attack_timer <= 0.0

func exit() -> void:
	if can_combo_or_cancel:
		EventBus.Combat.combo_window_closed.emit()

func get_allowed_transitions() -> Array[String]:
	if can_combo_or_cancel:
		return ["Idle", "Walk", "Attack", "Dodge", "Block", "Aiming", "Stun"]
	return ["Attack"]
