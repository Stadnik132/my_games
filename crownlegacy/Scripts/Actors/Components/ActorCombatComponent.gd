extends CombatComponent
class_name ActorCombatComponent

# ==================== ПЕРЕМЕННЫЕ ====================
var actor_data: ActorData
var _combat_start_time: float = 0.0
var _used_decision_triggers: Dictionary = {}
var _combat_manager: Node = null

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func setup(owner_entity: Entity, data: ActorData) -> void:
	"""Явная настройка компонента (вызывается из Actor)"""
	self.owner_entity = owner_entity
	self.actor_data = data
	
	_find_components()
	_setup_connections()
	
	# Если есть FSM, настраиваем её (опционально)
	if fsm and combat_config:
		fsm.setup(owner_entity, stats_provider, self, combat_config)
		fsm.set_process(false)
		fsm.set_physics_process(false)
	
	print_debug("ActorCombatComponent настроен для: ", owner_entity.name if owner_entity else "unknown")

func _find_components() -> void:
	"""Переопределяем поиск компонентов (все опциональны)"""
	hitbox_component = owner_entity.get_node_or_null("HitboxComponent") as HitboxComponent
	
	# Опциональные компоненты
	stats_provider = owner_entity.get_node_or_null("ProgressionComponent") as ProgressionComponent
	stamina_component = owner_entity.get_node_or_null("StaminaComponent") as ResourceComponent
	ability_component = owner_entity.get_node_or_null("AbilityComponent") as AbilityComponent
	
	# FSM опциональна
	fsm = owner_entity.get_node_or_null("EntityCombatFSM") as EntityCombatFSM

func _setup_connections() -> void:
	"""Подключаем только нужные сигналы"""
	EventBus.Game.state_changed.connect(_on_game_state_changed)
	
	var hurtbox = owner_entity.get_node_or_null("Hurtbox")
	if hurtbox:
		hurtbox.damage_taken.connect(_on_hurtbox_damage)

# ==================== АКТИВАЦИЯ ====================
func setup_combat(combat_manager: Node) -> void:
	"""Вызывается при вступлении в бой"""
	_combat_manager = combat_manager
	_combat_start_time = Time.get_ticks_msec() / 1000.0
	_used_decision_triggers.clear()
	
	# Активируем FSM если есть
	if fsm:
		fsm.set_process(true)
		fsm.set_physics_process(true)
		fsm.change_state("Idle")
	
	print_debug("ActorCombatComponent: вступил в бой для ", owner_entity.name if owner_entity else "unknown")

func set_active(value: bool) -> void:
	"""Включение/выключение компонента (вызывается из Actor.change_mode)"""
	if fsm:
		fsm.set_process(value)
		fsm.set_physics_process(value)
		if not value:
			fsm.change_state("Idle")

# ==================== ПОЛУЧЕНИЕ УРОНА ====================
func _on_hurtbox_damage(damage_data: DamageData, source: Node) -> void:
	var health = owner_entity.health_component
	if not health:
		return
	
	# Рассчитываем урон с учётом защиты актёра
	var final_damage = _calculate_damage(damage_data)
	
	# Сохраняем старое HP для проверки триггеров
	var old_hp = health.get_current_health()
	
	# Применяем урон
	health.take_damage(
		final_damage,
		damage_data.damage_type,
		source,
		damage_data.is_critical
	)
	
	# Проверяем триггеры HP после получения урона
	if _combat_manager and health.get_current_health() != old_hp:
		var trigger = _check_hp_threshold_after_damage(old_hp, health.get_current_health())
		if trigger:
			EventBus.Combat.decision.point_requested.emit(owner_entity, trigger)

func _calculate_damage(damage_data: DamageData) -> int:
	"""Расчёт урона с учётом защиты актёра"""
	var base = damage_data.amount
	
	# Критический удар
	if damage_data.can_crit and randf() < 0.1:  # 10% базовый шанс
		base = int(base * damage_data.crit_multiplier)
		damage_data.damage_crit.emit(base)
		print_debug("КРИТИЧЕСКИЙ УДАР по ", owner_entity.name)
	
	# Игнорирование защиты для истинного урона
	if damage_data.is_true_damage() or not actor_data:
		return base
	
	# Применяем защиту из actor_data
	var defense = 0
	match damage_data.damage_type:
		DamageData.DamageType.PHYSICAL:
			defense = actor_data.physical_defense
		DamageData.DamageType.MAGICAL:
			defense = actor_data.magical_defense
	
	var effective_defense = defense * (1.0 - damage_data.penetration)
	return max(1, base - effective_defense)

# ==================== ТОЧКИ РЕШЕНИЙ ====================
func check_decision_triggers() -> Dictionary:
	"""Проверяет триггеры для точек решений"""
	if not _combat_manager or not actor_data:  # Не в бою или нет данных
		return {}
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var combat_time = current_time - _combat_start_time
	var health = owner_entity.health_component
	var hp_percent = health.get_health_percentage() if health else 1.0
	
	for trigger in actor_data.decision_triggers:
		var trigger_type = trigger.get("type", "")
		var trigger_value = trigger.get("seconds", trigger.get("threshold", 0))
		
		if is_decision_trigger_used(trigger_type, trigger_value):
			continue
		
		match trigger_type:
			"time":
				if combat_time >= trigger.get("seconds", 0.0):
					print_debug("Триггер времени сработал для ", owner_entity.name)
					return trigger
			"hp":
				if hp_percent <= trigger.get("threshold", 1.0):
					print_debug("Триггер HP сработал для ", owner_entity.name)
					return trigger
	return {}

func _check_hp_threshold_after_damage(old_hp: int, new_hp: int) -> Dictionary:
	"""Проверяет, не пересекли ли мы порог HP для триггера"""
	if not actor_data or not owner_entity.health_component:
		return {}
	
	var max_hp = owner_entity.health_component.get_max_health()
	var old_percent = float(old_hp) / max_hp
	var new_percent = float(new_hp) / max_hp
	
	for trigger in actor_data.decision_triggers:
		if trigger.get("type") != "hp":
			continue
		var threshold = trigger.get("threshold", 1.0)
		var trigger_value = threshold
		if is_decision_trigger_used("hp", trigger_value):
			continue
		if old_percent > threshold and new_percent <= threshold:
			print_debug("HP-триггер сработал при переходе через ", threshold)
			return trigger
	return {}

func mark_trigger_used(trigger_type: String, trigger_value: Variant) -> void:
	var key = _get_trigger_key(trigger_type, trigger_value)
	_used_decision_triggers[key] = true

func is_decision_trigger_used(trigger_type: String, trigger_value: Variant) -> bool:
	var key = _get_trigger_key(trigger_type, trigger_value)
	return _used_decision_triggers.has(key)

func _get_trigger_key(trigger_type: String, trigger_value: Variant) -> String:
	return trigger_type + "_" + str(trigger_value)

# ==================== АТАКИ (ДЛЯ AI) ====================
func perform_attack(target_position: Vector2, damage_multiplier: float = 1.0) -> void:
	"""Выполнить атаку (вызывается из AI)"""
	if not hitbox_component or not actor_data:
		return
	
	# Получаем направление из Actor
	var actor = owner_entity as Actor
	if not actor:
		return
	
	var direction = actor.get_facing_direction()
	var spawn_pos = actor.global_position + _direction_to_vector(direction) * 50.0
	
	var base_damage = actor_data.base_damage
	if stats_provider:
		base_damage = stats_provider.get_stat("attack")
	
	hitbox_component.spawn_attack_hitbox(
		spawn_pos,
		_direction_to_vector(direction),
		base_damage,
		damage_multiplier,
		false
	)

func _direction_to_vector(dir: String) -> Vector2:
	match dir:
		"up": return Vector2.UP
		"down": return Vector2.DOWN
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
		"up_left": return Vector2(-1, -1).normalized()
		"up_right": return Vector2(1, -1).normalized()
		"down_left": return Vector2(-1, 1).normalized()
		"down_right": return Vector2(1, 1).normalized()
		_: return Vector2.DOWN

# ==================== УПРАВЛЕНИЕ FSM (ОТ COMBATCOMPONENT) ====================
# Переопределяем методы ввода как пустые (актёр не использует ввод)
func _on_attack_requested() -> void:
	pass

func _on_dodge_requested(direction: Vector2) -> void:
	pass

func _on_block_started() -> void:
	pass

func _on_block_ended() -> void:
	pass

func _on_ability_slot_pressed(slot_index: int) -> void:
	pass

# ==================== УТИЛИТЫ ====================
func get_combat_time() -> float:
	if not _combat_manager:
		return 0.0
	return (Time.get_ticks_msec() / 1000.0) - _combat_start_time

func _on_game_state_changed(new_state: int, old_state: int) -> void:
	var is_battle = (new_state == 2)  # STATE_BATTLE
	
	if fsm:
		fsm.set_process(is_battle)
		fsm.set_physics_process(is_battle)
		if not is_battle:
			fsm.change_state("Idle")
