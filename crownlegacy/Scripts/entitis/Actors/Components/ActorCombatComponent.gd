extends CombatComponent
class_name ActorCombatComponent

var entity_data: EntityData
var _in_combat: bool = false
var _desired_move: Vector2 = Vector2.ZERO
var ai_speed_multiplier: float = 1.0


func setup(entity: Entity, data: EntityData) -> void:
	self.owner_entity = entity
	self.entity_data = data


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



