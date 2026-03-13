extends Area2D
class_name Hitbox

var damage_data: DamageData
var direction: Vector2 = Vector2.ZERO
var lifetime: float = 0.1
var _damage_applied: bool = false

func _ready():
	if damage_data:
		print("    🔴УРОН! : ", damage_data.amount)
	
	_update_layers_from_source()
	area_entered.connect(_on_area_entered)
	
	# ВАЖНО: ждём один кадр после добавления в дерево
	await get_tree().process_frame
	
	# Теперь можно проверять пересечения
	_apply_damage_to_overlapping()
	
	# Ждём оставшееся время жизни
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _apply_damage_to_overlapping() -> void:
	if _damage_applied:
		return
	_damage_applied = true  # Сразу ставим флаг ДО нанесения урона
	
	var overlapping_areas = get_overlapping_areas()
	for area in overlapping_areas:
		if area is Hurtbox and area.entity_owner != damage_data.source:
			area.damage_taken.emit(damage_data, damage_data.source)
			break  # Только один раз


func _update_layers_from_source():
	var source = damage_data.source if damage_data else null

	if not source:
		collision_layer = 0
		collision_mask = 0
		return
	
	print("    source группы: ", source.get_groups())
	
	if source.is_in_group("player"):
		# Хитбокс игрока
		collision_layer = 2
		collision_mask = 4
		
	elif source.is_in_group("enemies"):
		# Хитбокс врага
		collision_layer = 4
		collision_mask = 2
	else:
		collision_layer = 0
		collision_mask = 0

func _on_area_entered(area: Area2D):
	if _damage_applied:
		return
	_damage_applied = true  # Сразу ставим флаг
	
	if area is Hurtbox and area.entity_owner != damage_data.source:
		area.damage_taken.emit(damage_data, damage_data.source)
		set_deferred("monitoring", false)

func get_damage_data() -> DamageData:
	return damage_data

func set_damage_data(data: DamageData) -> void:
	damage_data = data
