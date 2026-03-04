extends CombatComponent
class_name ActorCombatComponent

# ==================== ПЕРЕМЕННЫЕ ====================
var actor_data: ActorData
var _in_combat: bool = false
var _combat_start_time: float = 0.0

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func setup(actor: Entity, data: ActorData) -> void:
	self.owner_entity = actor
	self.actor_data = data
	
	_find_components()
	_setup_connections()
	
	if fsm and combat_config:
		fsm.setup(owner_entity, stats_provider, self, combat_config)
		fsm.set_process(false)
		fsm.set_physics_process(false)
	
	print_debug("ActorCombatComponent настроен для: ", owner_entity.name)

func _setup_connections() -> void:
	# Подключаемся к хертбоксу для получения урона
	var hurtbox = owner_entity.get_node_or_null("Hurtbox")
	if hurtbox:
		if not hurtbox.damage_taken.is_connected(_on_hurtbox_damage):
			hurtbox.damage_taken.connect(_on_hurtbox_damage)

# ==================== АКТИВАЦИЯ ====================
func enter_combat() -> void:
	_in_combat = true
	_combat_start_time = Time.get_ticks_msec() / 1000.0
	set_active(true)
	print_debug("ActorCombatComponent: вступил в бой")

func exit_combat() -> void:
	_in_combat = false
	set_active(false)

func set_active(value: bool) -> void:
	if fsm:
		fsm.set_process(value)
		fsm.set_physics_process(value)
		if value:
			fsm.change_state("Idle")

func is_in_combat() -> bool:
	return _in_combat

# ==================== ПОЛУЧЕНИЕ УРОНА ====================
func _on_hurtbox_damage(damage_data: DamageData, source: Node) -> void:
	if not _in_combat or not owner_entity.health_component:
		return
	
	var final_damage = _calculate_damage(damage_data)
	
	owner_entity.health_component.take_damage(
		final_damage,
		damage_data.damage_type,
		source,
		damage_data.is_critical
	)

func _calculate_damage(damage_data: DamageData) -> int:
	var base = damage_data.amount
	
	if damage_data.can_crit and randf() < 0.1:
		base = int(base * damage_data.crit_multiplier)
	
	if damage_data.is_true_damage() or not actor_data:
		return base
	
	var defense = 0
	match damage_data.damage_type:
		DamageData.DamageType.PHYSICAL:
			defense = actor_data.physical_defense
		DamageData.DamageType.MAGICAL:
			defense = actor_data.magical_defense
	
	var effective_defense = defense * (1.0 - damage_data.penetration)
	return max(1, base - effective_defense)

# ==================== МЕТОДЫ ДЛЯ AI ====================
func use_ability(slot_index: int, target_position: Vector2 = Vector2.ZERO) -> bool:
	if not ability_component or not _in_combat:
		return false
	
	if not ability_component.can_cast_ability(slot_index):
		return false
	
	var ability = ability_component.get_ability_in_slot(slot_index)
	if not ability:
		return false
	
	return ability_component.cast_ability(slot_index, target_position)

# ==================== ПЕРЕОПРЕДЕЛЕНИЕ МЕТОДОВ ВВОДА ====================
func _on_attack_requested() -> void: pass
func _on_dodge_requested(direction: Vector2) -> void: pass
func _on_block_started() -> void: pass
func _on_block_ended() -> void: pass
func _on_ability_slot_pressed(slot_index: int) -> void: pass
