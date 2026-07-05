extends CombatComponent
class_name ActorCombatComponent

var entity_data: EntityData
var _in_combat: bool = false
var _desired_move: Vector2 = Vector2.ZERO
var ai_speed_multiplier: float = 1.0


func setup(entity: Entity, data: EntityData) -> void:
	self.owner_entity = entity
	self.entity_data = data
	
	_find_components()
	_setup_connections()
	
	if fsm and combat_config:
		fsm.setup(owner_entity, stats_provider, self, combat_config)
		fsm.set_process(false)
		fsm.set_physics_process(false)


func _find_components() -> void:
	fsm = owner_entity.get_node_or_null("EntityCombatFSM") as EntityCombatFSM
	hitbox_component = owner_entity.get_node_or_null("HitboxComponent") as HitboxComponent
	stats_provider = owner_entity.get_node_or_null("ProgressionComponent")
	stamina_component = owner_entity.get_node_or_null("StaminaComponent")
	ability_component = owner_entity.get_node_or_null("AbilityComponent")


func _setup_connections() -> void:
	var hurtbox = owner_entity.get_node_or_null("Hurtbox")
	if hurtbox and not hurtbox.damage_taken.is_connected(_on_hurtbox_damage):
		hurtbox.damage_taken.connect(_on_hurtbox_damage)


func set_desired_move(dir: Vector2) -> void:
	_desired_move = dir


func get_move_vector() -> Vector2:
	return _desired_move


func enter_combat() -> void:
	_in_combat = true
	set_active(true)


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


func get_fsm() -> EntityCombatFSM:
	return fsm


func _on_hurtbox_damage(damage_data: DamageData, source: Node) -> void:
	super._on_hurtbox_damage(damage_data, source)


func _apply_defense(damage: int, damage_data: DamageData) -> int:
	if damage_data.is_true_damage() or not entity_data:
		return damage
	
	var defense = 0
	match damage_data.damage_type:
		DamageData.DamageType.PHYSICAL:
			defense = entity_data.get_physical_defense()
		DamageData.DamageType.MAGICAL:
			defense = entity_data.get_magical_defense()
		_:
			return damage
	
	var effective_defense = defense * (1.0 - damage_data.penetration)
	return max(1, damage - int(effective_defense))
