class_name AttackState extends CombatState

# Общий для Player и остальных NPC типа Actor/Enemy и т.д

var combo_step: int = 0
var attack_timer: float = 0.0
var can_combo_or_cancel: bool = false
var hitbox_spawned: bool = false
var attack_direction: String = "right"
var _combo_used: bool = false
var is_npc: bool = false

var hitbox_component: HitboxComponent
var combo_window_timer: Timer

# Параметры выпада (lunge)
var lunge_direction: Vector2
var lunge_timer: float = 0.0
var lunge_duration: float = 0.0
var lunge_distance: float = 0.0
var lunge_phase: int = 0  # 0=разгон, 1=удар, 2=торможение

func enter() -> void:
	super.enter()

	if not hitbox_component:
		hitbox_component = entity.get_node_or_null("HitboxComponent") as HitboxComponent

	is_npc = not entity.is_in_group("player")

	attack_direction = _get_attack_direction()

	combo_step = fsm.attack_combo_step
	
	if combo_step == 0:
		combo_step = 1
		fsm.attack_combo_step = 1

	attack_timer = attack_params.get("attack_duration", 0.8)
	can_combo_or_cancel = false
	hitbox_spawned = false
	_combo_used = false

	lunge_direction = Vector2.RIGHT if attack_direction == "right" else Vector2.LEFT
	lunge_duration = combat_config.attack_lunge_duration if combat_config else 0.3
	lunge_distance = combat_config.attack_lunge_distance if combat_config else 60.0
	lunge_timer = 0.0
	lunge_phase = 0

	var anim_name = "attack_%s_%d" % [attack_direction, combo_step]
	EventBus.Animations.requested.emit(entity, anim_name, attack_timer)

	_open_combo_window()

func _get_attack_direction() -> String:
	# Для NPC — бьём в сторону игрока
	if entity.has_method("get_target_position") or entity.has_node("AIPerception"):
		var perception_node = entity.get_node_or_null("AIPerception")
		if perception_node and perception_node.has_method("get_player_position"):
			var player_pos = perception_node.get_player_position()
			if player_pos != Vector2.ZERO:
				return "left" if player_pos.x < entity.global_position.x else "right"
	
	# Fallback для игрока и случаев без восприятия
	var dir = fsm.last_movement_direction
	if dir.x < 0:
		return "left"
	return "right"

func _open_combo_window() -> void:
	var delay = attack_params.get("cancel_window_start", 0.1)
	combo_window_timer = Timer.new()
	combo_window_timer.wait_time = delay
	combo_window_timer.one_shot = true
	combo_window_timer.timeout.connect(_on_combo_window_ready)
	add_child(combo_window_timer)
	combo_window_timer.start()

func _on_combo_window_ready() -> void:
	if attack_timer > 0:
		can_combo_or_cancel = true
		_combo_used = false
		EventBus.Combat.attack.combo_window_opened.emit()
	
	if combo_window_timer:
		combo_window_timer.queue_free()
		combo_window_timer = null

func process(delta: float) -> void:
	super.process(delta)
	
	attack_timer -= delta
	
	if not hitbox_spawned and attack_timer <= attack_params.get("attack_duration", 0.8) * 0.7:
		_spawn_attack_hitbox()
		hitbox_spawned = true
	
	if attack_timer <= 0.0:
		_finish_attack()

func physics_process(delta: float) -> void:
	# Рассчитываем движение выпада (lunge)
	lunge_timer += delta
	
	var current_velocity: Vector2 = Vector2.ZERO
	
	# Три фазы выпада:
	# Фаза 0 (0-30%): Разгон - плавное увеличение скорости
	# Фаза 1 (30-70%): Удар - пиковая скорость
	# Фаза 2 (70-100%): Торможение - плавное снижение до нуля
	
	var lunge_progress: float = clampf(lunge_timer / lunge_duration, 0.0, 1.0)
	
	if lunge_progress < 0.3:
		# Фаза разгона - линейное увеличение скорости
		lunge_phase = 0
		var accel_progress = lunge_progress / 0.3
		var peak_speed = lunge_distance / lunge_duration
		current_velocity = lunge_direction * peak_speed * accel_progress
	elif lunge_progress < 0.7:
		# Фаза удара - пиковая скорость
		lunge_phase = 1
		var peak_speed = lunge_distance / lunge_duration
		current_velocity = lunge_direction * peak_speed
	elif lunge_progress < 1.0:
		# Фаза торможения - линейное снижение
		lunge_phase = 2
		var decel_progress = (lunge_progress - 0.7) / 0.3
		var peak_speed = lunge_distance / lunge_duration
		current_velocity = lunge_direction * peak_speed * (1.0 - decel_progress)
	else:
		# Выпад завершён
		current_velocity = Vector2.ZERO
	
	set_battle_velocity(current_velocity)
	apply_movement()

func _spawn_attack_hitbox() -> void:
	if not hitbox_component:
		return
	
	var base_damage = attack_params.get("base_damage", 1)
	var combo_multipliers = attack_params.get("combo_damage", [1.0, 1.2, 1.5, 2.0])
	var idx = mini(combo_step - 1, combo_multipliers.size() - 1)
	var multiplier = combo_multipliers[idx] if idx >= 0 else 1.0
	var final_damage = int(base_damage * multiplier)
	
	var can_crit = attack_params.get("can_crit", false)
	var crit_chance = attack_params.get("crit_chance", 0.05)
	var crit_multiplier = attack_params.get("crit_multiplier", 2.0)
	var penetration = attack_params.get("penetration", 0.0)
	
	var is_critical = false
	if can_crit and randf() < crit_chance:
		is_critical = true
		final_damage = int(final_damage * crit_multiplier)
	
	var direction = Vector2.RIGHT if attack_direction == "right" else Vector2.LEFT
	var offset = combat_config.attack_hitbox_offset if combat_config else 15.0
	var spawn_pos = entity.global_position + direction * offset

	# Рассчитываем отбрасывание
	var is_finisher = (combo_step >= attack_params.get("max_combo_steps", 4))
	var knockback_dist = 0.0
	if combat_config:
		if is_finisher:
			knockback_dist = combat_config.combo_finisher_knockback_distance
		else:
			knockback_dist = combat_config.base_knockback_distance
	else:
		knockback_dist = 90.0  # fallback

	var damage_data = DamageData.new()
	damage_data.amount = final_damage
	damage_data.damage_type = 0
	damage_data.is_critical = is_critical
	damage_data.penetration = penetration
	damage_data.source = entity
	damage_data.knockback_distance = knockback_dist

	if is_critical:
		damage_data.crit_multiplier = crit_multiplier

	hitbox_component.spawn_hitbox_with_damage(spawn_pos, direction, damage_data)
	EventBus.Combat.attack.basic_hit.emit(combo_step, 1)

func _finish_attack() -> void:
	if can_combo_or_cancel:
		EventBus.Combat.attack.combo_window_closed.emit()
	
	# Для NPC: продолжаем комбо, если игрок рядом
	if is_npc and combo_step < attack_params.get("max_combo_steps", 4):
		var brain_node = entity.get_node_or_null("AIBrain")
		if brain_node and brain_node.has_method("notify_combo_step"):
			brain_node.notify_combo_step(combo_step + 1)
		
		# Используем большую дистанцию для комбо окна - позволяем игроку немного отойти
		if _is_player_in_combo_range():
			fsm.attack_combo_step = combo_step + 1
			transition_requested.emit("Attack")
			return
	
	# Сбрасываем комбо в Brain
	var brain_node = entity.get_node_or_null("AIBrain")
	if brain_node and brain_node.has_method("notify_combo_ended"):
		brain_node.notify_combo_ended()
	
	_reset_combo()
	transition_requested.emit("Idle")

func _is_player_in_attack_range() -> bool:
	var perception_node = entity.get_node_or_null("AIPerception")
	if perception_node and perception_node.has_method("get_distance_to_player"):
		var dist = perception_node.get_distance_to_player()
		var effective_range = attack_params.get("attack_range", 40.0)
		return dist <= effective_range
	return false

func _is_player_in_combo_range() -> bool:
	var perception_node = entity.get_node_or_null("AIPerception")
	if perception_node and perception_node.has_method("get_distance_to_player"):
		var dist = perception_node.get_distance_to_player()
		var effective_range = attack_params.get("attack_range", 40.0)
		# Расширяем диапазон для комбо - позволяем игроку отойти дальше перед сбросом комбо
		var combo_range = effective_range * 1.5
		return dist <= combo_range
	return false

func _reset_combo() -> void:
	fsm.attack_combo_step = 0
	EventBus.Combat.attack.combo_reset.emit()

func handle_command(command: String, data: Dictionary = {}) -> void:
	if not can_combo_or_cancel:
		return

	match command:
		"attack":
			# Запрещаем повторное использование в том же окне комбо
			if _combo_used:
				return
			_combo_used = true

			var max_combo = attack_params.get("max_combo_steps", 4)
			if combo_step < max_combo:
				# Увеличиваем шаг комбо
				fsm.attack_combo_step = combo_step + 1
				# Переходим к следующей атаке
				transition_requested.emit("Attack")
			else:
				# Комбо завершено - сбрасываем и возвращаемся в Idle
				_reset_combo()
				transition_requested.emit("Idle")

		"dodge":
			_reset_combo()
			transition_requested.emit("Dodge")

		"block_start":
			_reset_combo()
			transition_requested.emit("Block")

		"ability_selected":
			_reset_combo()
			if data.has("ability"):
				fsm.current_ability = data["ability"]
				fsm.current_slot_index = data.get("slot_index", -1)
			transition_requested.emit("Aim")

func can_exit() -> bool:
	return can_combo_or_cancel or attack_timer <= 0.0

func exit() -> void:
	# Очистка таймера комбо
	if combo_window_timer:
		combo_window_timer.queue_free()
		combo_window_timer = null

	# Очистка хитбоксов
	if hitbox_component:
		hitbox_component.clear_hitboxes()

func get_allowed_transitions() -> Array[String]:
	if can_combo_or_cancel:
		return ["Idle", "Attack", "Dodge", "Block", "Aim", "Stun"]
	return ["Attack"]
