extends Area2D
class_name Hurtbox

signal damage_taken(damage_data: DamageData, source: Node)

func _ready():
	area_entered.connect(_on_hitbox_entered)
	collision_layer = 0        # Ничего не обнаруживает
	collision_mask = 2         # Только слой Hitbox (2)

func _on_hitbox_entered(hitbox: Area2D):
	if not hitbox.has_method("get_damage_data"):
		return
	
	var damage_data = hitbox.get_damage_data()
	var source = hitbox.get_parent()

	damage_taken.emit(damage_data, source)
