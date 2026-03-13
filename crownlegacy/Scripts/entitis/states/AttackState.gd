class_name AttackState extends CombatState

var combo_step: int = 0
var attack_timer: float = 0.0
var can_combo_or_cancel: bool = false
var hitbox_spawned: bool = false

var hitbox_component: HitboxComponent

func enter() -> void:
	super.enter()
	
	if not hitbox_component:
		hitbox_component = entity.get_node_or_null("HitboxComponent") as HitboxComponent
	
	combo_step = fsm.attack_combo_step
	if combo_step == 0:
		combo_step = 1
		fsm.attack_combo_step = 1
	
	attack_timer = attack_params.get("attack_duration", 0.8)
	can_combo_or_cancel = false
	hitbox_spawned = false
	
	var anim_name = "attack_" + str(combo_step)
	EventBus.Animations.requested.emit(entity, anim_name, attack_timer)
	
	await_open_combo_window()

func process(delta: float) -> void:
	super.process(delta)
	
	attack_timer -= delta
	
	if not hitbox_spawned and attack_timer <= attack_params.get("attack_duration", 0.8) * 0.7:
		_spawn_attack_hitbox()
		hitbox_spawned = true
	
	if attack_timer <= 0.0:
		_finish_attack()

func physics_process(_delta: float) -> void:
	set_battle_velocity(Vector2.ZERO)
	apply_movement()

func _spawn_attack_hitbox() -> void:
	if not hitbox_component:
		return
	
	# Базовый урон из характеристик атакующего
	var base_damage = attack_params.get("base_damage", 1)
	var combo_multipliers = attack_params.get("combo_damage", [1.0, 1.2, 1.5, 2.0])
	var idx = mini(combo_step - 1, combo_multipliers.size() - 1)
	var multiplier = combo_multipliers[idx] if idx >= 0 else 1.0
	var final_damage = int(base_damage * multiplier)
	
	# Параметры крита (берутся из stats_provider или combat_config)
	var can_crit = attack_params.get("can_crit", false)
	var crit_chance = attack_params.get("crit_chance", 0.05)  # 5% базовый шанс
	var crit_multiplier = attack_params.get("crit_multiplier", 2.0)
	var penetration = attack_params.get("penetration", 0.0)  # пробивание защиты
	
	# Определяем крит
	var is_critical = false
	if can_crit and randf() < crit_chance:
		is_critical = true
		final_damage = int(final_damage * crit_multiplier)
	
	# Направление и позиция спавна
	var direction = get_attack_direction()
	var offset = combat_config.attack_hitbox_offset if combat_config else 15.0
	var spawn_pos = entity.global_position + direction * offset
	
	# Создаем DamageData с полной информацией
	var damage_data = DamageData.new()
	damage_data.amount = final_damage
	damage_data.damage_type = 0  # PHYSICAL (можно позже сделать настраиваемым)
	damage_data.is_critical = is_critical
	damage_data.penetration = penetration
	damage_data.source = entity
	
	# Опционально: сохраняем множитель крита для эффектов
	if is_critical:
		damage_data.crit_multiplier = crit_multiplier
	
	# Спавним хитбокс с готовыми данными
	hitbox_component.spawn_hitbox_with_damage(spawn_pos, direction, damage_data)
	
	EventBus.Combat.attack.basic_hit.emit(combo_step, 1)
func await_open_combo_window() -> void:
	await get_tree().create_timer(attack_params.get("cancel_window_start", 0.1)).timeout
	if attack_timer > 0:
		can_combo_or_cancel = true
		EventBus.Combat.attack.combo_window_opened.emit()

func _finish_attack() -> void:
	if can_combo_or_cancel:
		EventBus.Combat.attack.combo_window_closed.emit()
	transition_requested.emit("Idle")

func handle_command(command: String, data: Dictionary = {}) -> void:
	if not can_combo_or_cancel:
		return
	
	match command:
		"attack":
			var max_combo = attack_params.get("max_combo_steps", 4)
			if combo_step < max_combo:
				fsm.attack_combo_step = combo_step + 1
				EventBus.Combat.attack.combo_window_closed.emit()
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
		
		"ability_selected":
			_reset_combo()
			if data.has("ability"):
				fsm.current_ability = data["ability"]
				fsm.current_slot_index = data.get("slot_index", -1)
			transition_requested.emit("Aim")

func _reset_combo() -> void:
	fsm.attack_combo_step = 0
	fsm.combo_window_timer = 0.0
	EventBus.Combat.attack.combo_window_closed.emit()

func can_exit() -> bool:
	return can_combo_or_cancel or attack_timer <= 0.0

func exit() -> void:
	if can_combo_or_cancel:
		EventBus.Combat.attack.combo_window_closed.emit()
	
	if hitbox_component:
		hitbox_component.clear_hitboxes()

func get_allowed_transitions() -> Array[String]:
	if can_combo_or_cancel:
		return ["Idle", "Attack", "Dodge", "Block", "Aim", "Stun"]
	return ["Attack"]
