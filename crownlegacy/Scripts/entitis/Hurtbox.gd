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
		collision_layer = 2
		collision_mask = 4
		
	elif owner.is_in_group("enemies"):
		collision_layer = 4
		collision_mask = 2
		
	elif owner.is_in_group("friendlies"):
		collision_layer = 2
		collision_mask = 2
	else:
		collision_layer = 0
		collision_mask = 0
		print_debug("  unknown: layer=0 mask=0")

func _on_hitbox_entered(area: Area2D):

	
	# Проверяем, что это Hitbox, а не другой Hurtbox
	if not area is Hitbox:
		return
	
	if area.has_method("get_damage_data"):
		var damage_data = area.get_damage_data()
		print_debug("  damage_data получен: ", damage_data != null)
		if damage_data:
			damage_taken.emit(damage_data, damage_data.source)
