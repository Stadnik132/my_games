extends Area2D
class_name Hitbox

var damage_data: DamageData
var direction: Vector2 = Vector2.ZERO
var lifetime: float = 0.1

func _ready():
	
	# Проверяем damage_data
	if damage_data:
		print("    🔴УРОН! : ", damage_data.amount)
	
	await get_tree().process_frame
	_update_layers_from_source()
	area_entered.connect(_on_area_entered)
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _update_layers_from_source():
	var source = damage_data.source if damage_data else null

	if not source:
		collision_layer = 0
		collision_mask = 0
		return
	
	print("    source группы: ", source.get_groups())
	
	if source.is_in_group("player"):
		collision_layer = 4 # Слой 3

	elif source.is_in_group("enemies"):
		collision_layer = 2 # Слой 2
	else:
		collision_layer = 0
		collision_mask = 0

func _on_area_entered(area: Area2D):
	if area is Hurtbox:
		# Проверяем, что это не свой хертбокс
		if area.entity_owner == damage_data.source:
			return
		set_deferred("monitoring", false)

func get_damage_data() -> DamageData:
	return damage_data

func set_damage_data(data: DamageData) -> void:
	damage_data = data
