class_name AttackState extends CombatState

var combo_step: int = 0
var attack_timer: float = 0.0
var can_combo_or_cancel: bool = false
var max_combo: int = 3

func enter():
	print("AttackState: вход, fsm комбо = ", fsm.attack_combo_step)
	
	combo_step = fsm.attack_combo_step
	
	if combo_step == 0 or fsm.combo_window_timer <= 0:
		combo_step = 1
		fsm.attack_combo_step = combo_step
		fsm.combo_window_timer = 2.0
	
	attack_timer = attack_params.get("attack_duration", 1.0)
	can_combo_or_cancel = false
	max_combo = attack_params.get("max_combo_steps", 3)
	
	if player.has_method("set_movement_allowed"):
		player.set_movement_allowed(false)
	
	_perform_attack()
	EventBus.Combat.basic_attack_hit.emit(combo_step, [])

func _perform_attack():
	var base_damage = attack_params.get("base_damage", 10)
	var combo_multiplier = attack_params.get("combo_damage", [1.0, 1.2, 1.5])[combo_step - 1]
	var final_damage = int(base_damage * combo_multiplier)
	
	var damage_data = DamageData.create_physical(final_damage, 0.0)
	var enemies = _find_enemies_in_attack_cone()
	
	for enemy in enemies:
		if enemy.has_method("apply_combat_damage_data"):
			enemy.apply_combat_damage_data(damage_data, player)
	
	print("Атака комбо #", combo_step, ", врагов: ", enemies.size())

func _find_enemies_in_attack_cone() -> Array:
	var enemies = []
	var attack_range = 50.0
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var distance = player.global_position.distance_to(enemy.global_position)
		if distance <= attack_range:
			enemies.append(enemy)
	
	return enemies

func process(delta: float):
	attack_timer -= delta
	fsm.combo_window_timer -= delta
	
	if not can_combo_or_cancel and attack_timer <= 0.3:
		can_combo_or_cancel = true
		EventBus.Combat.combo_window_opened.emit()
	
	if attack_timer <= 0:
		_finish_attack()

func _finish_attack():
	if can_combo_or_cancel:
		EventBus.Combat.combo_window_closed.emit()
	
	if player.has_method("set_movement_allowed"):
		player.set_movement_allowed(true)
	
	fsm.attack_combo_step = 0
	fsm.combo_window_timer = 0
	transition_requested.emit("Idle")

func handle_command(command: String, data: Dictionary = {}):
	if not can_combo_or_cancel:
		return
	
	match command:
		"attack":
			if combo_step < max_combo:
				fsm.attack_combo_step = combo_step + 1
				EventBus.Combat.combo_window_closed.emit()
				if player.has_method("set_movement_allowed"):
					player.set_movement_allowed(true)
				transition_requested.emit("Attack")
			else:
				fsm.attack_combo_step = 0
				fsm.combo_window_timer = 0
				EventBus.Combat.combo_window_closed.emit()
				if player.has_method("set_movement_allowed"):
					player.set_movement_allowed(true)
				transition_requested.emit("Idle")
		
		"dodge", "block_start", "aim_start":
			fsm.attack_combo_step = 0
			fsm.combo_window_timer = 0
			EventBus.Combat.combo_window_closed.emit()
			if player.has_method("set_movement_allowed"):
				player.set_movement_allowed(true)
			
			match command:
				"dodge": transition_requested.emit("Dodge")
				"block_start": transition_requested.emit("Block")
				"aim_start": transition_requested.emit("Aiming")

func can_exit() -> bool:
	return can_combo_or_cancel or attack_timer <= 0

func exit():
	if can_combo_or_cancel:
		EventBus.Combat.combo_window_closed.emit()
	
	if player.has_method("set_movement_allowed"):
		player.set_movement_allowed(true)
	
	fsm.attack_combo_step = 0
	fsm.combo_window_timer = 0

func get_allowed_transitions() -> Array[StringName]:
	if can_combo_or_cancel:
		return ["Idle", "Dodge", "Block", "Aiming", "Attack"]
	return ["Attack"]
