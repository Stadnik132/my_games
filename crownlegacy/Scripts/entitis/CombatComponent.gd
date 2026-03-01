class_name CombatComponent extends Node

# ==================== ЭКСПОРТ ====================
@export var combat_config: CombatConfig
@export var owner_entity: Entity
@export var stats_provider: ProgressionComponent  # для получения статов
@export var ability_component: AbilityComponent
@export var stamina_component: ResourceComponent  # для траты выносливости

# ==================== ССЫЛКИ ====================
var fsm: EntityCombatFSM
var hitbox_component: HitboxComponent

func _ready() -> void:
	if not owner_entity:
		owner_entity = get_parent() as Entity
	
	_find_components()
	_setup_fsm()
	_setup_connections()

func _find_components() -> void:
	fsm = get_node_or_null("EntityCombatFSM") as EntityCombatFSM
	hitbox_component = get_node_or_null("HitboxComponent") as HitboxComponent
	
	if not stats_provider:
		stats_provider = owner_entity.get_node_or_null("ProgressionComponent")
	
	if not stamina_component:
		stamina_component = owner_entity.get_node_or_null("StaminaComponent")
	
	if not ability_component:
		ability_component = owner_entity.get_node_or_null("AbilityComponent")

func _setup_fsm() -> void:
	if not fsm:
		return
	fsm.setup(owner_entity, stats_provider, self, combat_config)
	fsm.set_process(false)
	fsm.set_physics_process(false)

func _setup_connections() -> void:
	EventBus.Game.state_changed.connect(_on_game_state_changed)
	
	# Hurtbox
	var hurtbox = owner_entity.get_node_or_null("Hurtbox")
	if hurtbox:
		hurtbox.damage_taken.connect(_on_hurtbox_damage)

# ==================== ПАРАМЕТРЫ ====================
func get_attack_params() -> Dictionary:
	return {
		"combo_damage": combat_config.attack_combo_damage,
		"combo_window": combat_config.attack_combo_window,
		"attack_duration": combat_config.attack_duration,
		"cancel_window_start": combat_config.cancel_window_start,
		"base_damage": stats_provider.get_stat("attack") if stats_provider else 10,
		"max_combo_steps": combat_config.attack_combo_damage.size()
	}

func get_dodge_params() -> Dictionary:
	return {
		"distance": combat_config.dodge_distance,
		"duration": combat_config.dodge_duration,
		"collider_radius": combat_config.dodge_collider_radius,
		"stamina_cost": combat_config.dodge_stamina_cost
	}

func get_fsm() -> EntityCombatFSM:
	return fsm

# ==================== ОБРАБОТЧИКИ ВВОДА ====================
func _on_attack_requested() -> void:
	if fsm:
		fsm.send_command("attack")

func _on_dodge_requested(direction: Vector2) -> void:
	if not fsm:
		return
	
	if direction == Vector2.ZERO:
		return
	
	# Проверка выносливости
	if stamina_component and not stamina_component.use(combat_config.dodge_stamina_cost):
		return
	
	fsm.send_command("dodge", {"direction": direction})

func _on_block_started() -> void:
	if fsm:
		fsm.send_command("block_start")

func _on_block_ended() -> void:
	if fsm:
		fsm.send_command("block_end")

func _on_ability_slot_pressed(slot_index: int) -> void:
	print("=== ABILITY SLOT PRESSED: ", slot_index)
	print("  fsm state: ", fsm.get_current_state_name() if fsm else "no fsm")
	print("  ability: ", ability_component.get_ability_in_slot(slot_index).ability_name if ability_component and ability_component.get_ability_in_slot(slot_index) else "none")
	print("  can cast: ", ability_component.can_cast_ability(slot_index) if ability_component else false)
	if not fsm or not ability_component:
		return
	
	var ability = ability_component.get_ability_in_slot(slot_index)
	if not ability or not ability_component.can_cast_ability(slot_index):
		return
	
	var current_state = fsm.get_current_state_name()
	if current_state in ["Idle", "Walk", "Attack"]:
		fsm.send_command("ability_selected", {
			"ability": ability,
			"slot_index": slot_index
		})
		fsm.send_command("aiming_start")

# ==================== ПОЛУЧЕНИЕ УРОНА ====================
func _on_hurtbox_damage(damage_data: DamageData, source: Node) -> void:
	var health = owner_entity.health_component
	if not health:
		return
	
	# Проверяем, в блоке ли мы
	if fsm and fsm.get_current_state_name() == "Block":
		_handle_blocked_damage(damage_data, source)
	else:
		# Обычное получение урона
		health.take_damage(
			damage_data.amount,
			damage_data.damage_type,
			source,
			damage_data.is_critical
		)

func _handle_blocked_damage(damage_data: DamageData, source: Node) -> void:
	"""Обработка урона во время блока"""
	if not stamina_component:
		# Если нет стамины, просто принимаем урон
		owner_entity.health_component.take_damage(
			damage_data.amount,
			damage_data.damage_type,
			source,
			damage_data.is_critical
		)
		return
	
	# Рассчитываем уменьшенный урон (из конфига)
	var reduction = combat_config.block_damage_reduction
	var damage_after_block = int(damage_data.amount * (1.0 - reduction))
	
	# Рассчитываем стоимость выносливости (зависит от силы удара)
	var stamina_cost = _calculate_block_stamina_cost(damage_data.amount)
	
	# Отправляем команду в состояние блока
	fsm.send_command("damage_blocked", {
		"damage_after_block": damage_after_block,
		"stamina_cost": stamina_cost
	})
	
	# Применяем уменьшенный урон
	owner_entity.health_component.take_damage(
		damage_after_block,
		damage_data.damage_type,
		source,
		damage_data.is_critical
	)

func _calculate_block_stamina_cost(incoming_damage: int) -> int:
	"""Рассчитывает стоимость выносливости за блокированный удар"""
	# Базовая стоимость + процент от полученного урона
	var base_cost = combat_config.block_base_stamina_cost  # нужно добавить в CombatConfig
	var damage_cost = int(incoming_damage * combat_config.block_stamina_damage_factor)  # тоже добавить
	return base_cost + damage_cost

# ==================== УПРАВЛЕНИЕ FSM ====================
func _on_game_state_changed(new_state: int, old_state: int) -> void:
	var is_battle = (new_state == 2)  # STATE_BATTLE
	
	if fsm:
		fsm.set_process(is_battle)
		fsm.set_physics_process(is_battle)
		if not is_battle:
			fsm.change_state("Idle")
