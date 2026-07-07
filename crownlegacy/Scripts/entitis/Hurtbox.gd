extends Area2D
class_name Hurtbox

signal damage_taken(damage_data: DamageData, source: Node)
var entity_owner: Node

func set_entity_owner(owner_node: Node) -> void:
	entity_owner = owner_node

func _ready():
	disable_mode = DISABLE_MODE_REMOVE

func update_layer_from_owner() -> void:
	if not entity_owner:
		collision_layer = 0
		collision_mask = 0
		return
	
	if entity_owner.is_in_group("player"):
		collision_layer = 2
		collision_mask = 4
		
	elif entity_owner.is_in_group("enemies"):
		collision_layer = 4
		collision_mask = 2
		
	elif entity_owner.is_in_group("friendlies"):
		collision_layer = 2
		collision_mask = 2
	else:
		collision_layer = 0
		collision_mask = 0


