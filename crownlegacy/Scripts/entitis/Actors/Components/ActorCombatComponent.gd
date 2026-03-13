extends CombatComponent
class_name ActorCombatComponent

# ==================== ПЕРЕМЕННЫЕ ====================
var actor_data: ActorData
var _in_combat: bool = false
var _combat_start_time: float = 0.0

# ==================== НОВЫЕ ПЕРЕМЕННЫЕ ДЛЯ AI ====================
var _desired_move: Vector2 = Vector2.ZERO  # желаемое направление движения от AI

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func setup(actor: Entity, data: ActorData) -> void:
	self.owner_entity = actor
	self.actor_data = data
	
	_find_components()  # переопределённый метод
	_setup_connections()
	
	if fsm and combat_config:
		fsm.setup(owner_entity, stats_provider, self, combat_config)
		fsm.set_process(false)
		fsm.set_physics_process(false)
	
	print_debug("ActorCombatComponent настроен для: ", owner_entity.name)

# ==================== ПЕРЕОПРЕДЕЛЯЕМ ПОИСК КОМПОНЕНТОВ ====================
func _find_components() -> void:
	# Ищем FSM у родителя (Actor), а не внутри себя
	fsm = owner_entity.get_node_or_null("EntityCombatFSM") as EntityCombatFSM
	hitbox_component = get_node_or_null("HitboxComponent") as HitboxComponent
	
	if not stats_provider:
		stats_provider = owner_entity.get_node_or_null("ProgressionComponent")
	
	if not stamina_component:
		stamina_component = owner_entity.get_node_or_null("StaminaComponent")
	
	if not ability_component:
		ability_component = owner_entity.get_node_or_null("AbilityComponent")

func _setup_connections() -> void:
	# Подключаемся к хертбоксу для получения урона
	var hurtbox = owner_entity.get_node_or_null("Hurtbox")
	if hurtbox:
		if not hurtbox.damage_taken.is_connected(_on_hurtbox_damage):
			hurtbox.damage_taken.connect(_on_hurtbox_damage)

# ==================== МЕТОДЫ ДЛЯ AI (НОВЫЕ) ====================
func set_desired_move(dir: Vector2) -> void:
	"""Устанавливает желаемое направление движения от AI"""
	_desired_move = dir

func get_move_vector() -> Vector2:
	"""Возвращает вектор движения (для FSM)"""
	return _desired_move

# ==================== АКТИВАЦИЯ ====================
func enter_combat() -> void:
	_in_combat = true
	_combat_start_time = Time.get_ticks_msec() / 1000.0
	set_active(true)
	print_debug("ActorCombatComponent: вступил в бой")

func exit_combat() -> void:
	_in_combat = false
	set_active(false)
	print_debug("ActorCombatComponent: вышел из боя")

func set_active(value: bool) -> void:
	if fsm:
		fsm.set_process(value)
		fsm.set_physics_process(value)
		if value:
			fsm.change_state("Idle")

func is_in_combat() -> bool:
	return _in_combat

func get_fsm() -> EntityCombatFSM:
	return fsm

# ==================== ПОЛУЧЕНИЕ УРОНА ====================
func _on_hurtbox_damage(damage_data: DamageData, source: Node) -> void:
	super._on_hurtbox_damage(damage_data, source)

func _apply_defense(damage: int, damage_data: DamageData) -> int:

	if damage_data.is_true_damage() or not actor_data:
		return damage
	
	# Получаем защиту в зависимости от типа урона
	var defense = 0
	match damage_data.damage_type:
		DamageData.DamageType.PHYSICAL:
			defense = actor_data.physical_defense
		DamageData.DamageType.MAGICAL:
			defense = actor_data.magical_defense
		_:
			return damage  # неизвестный тип урона
	
	# Учитываем пробивание
	var effective_defense = defense * (1.0 - damage_data.penetration)
	var final_damage = max(1, damage - int(effective_defense))
	
	print_debug("ActorCombatComponent: защита применилась")
	print_debug("  входящий урон: ", damage)
	print_debug("  защита: ", defense, " (эффективная: ", effective_defense, ")")
	print_debug("  итоговый урон: ", final_damage)
	
	return final_damage

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
