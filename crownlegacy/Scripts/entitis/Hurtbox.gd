extends Area2D
class_name Hurtbox

signal damage_taken(damage_data: DamageData, source: Node)
var entity_owner: Node

func set_entity_owner(owner_node: Node) -> void:
	entity_owner = owner_node

func _ready():
	area_entered.connect(_on_hitbox_entered)
	disable_mode = DISABLE_MODE_REMOVE

func update_layer_from_owner() -> void:
	if not owner:
		collision_layer = 0
		collision_mask = 0
		return	
	if owner.is_in_group("player"):
		collision_mask = 2 # Слой 2
	elif owner.is_in_group("enemies"):
		collision_mask = 4 # Слой 3
	elif owner.is_in_group("friendlies"):
		collision_mask = 2 # Слой 2
	else:
		collision_layer = 0
		collision_mask = 0


func _on_hitbox_entered(area: Area2D):	# Проверяем, что это Hitbox (у него есть get_damage_data)
	if area.has_method("get_damage_data"):
		var damage_data = area.get_damage_data()
		if damage_data:
			damage_taken.emit(damage_data, damage_data.source)
