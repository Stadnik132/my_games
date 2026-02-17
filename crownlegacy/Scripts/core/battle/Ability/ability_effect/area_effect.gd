class_name AreaEffect extends Area2D

var caster: Node
var damage_data: DamageData
var duration: float = 0.5
var applied: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D  # NEW!

func setup(params: Dictionary) -> void:
	caster = params.get("caster")
	damage_data = params.get("damage_data")
	position = params.get("position", Vector2.ZERO)
	duration = params.get("duration", 0.5)
	
	# Настраиваем радиус
	if params.has("radius") and collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = params["radius"]
	
	# Сразу проверяем попадания (даём физике кадр на обновление)
	await get_tree().process_frame
	_apply_damage()
	
	# Удаляем через duration
	await get_tree().create_timer(duration).timeout
	queue_free()

func _apply_damage() -> void:
	if applied:
		return
	
	var bodies = get_overlapping_bodies()
	var areas = get_overlapping_areas()
	
	# Проверяем тела
	for body in bodies:
		if body == caster:
			continue
		if body.has_method("apply_combat_damage_data"):
			body.apply_combat_damage_data(damage_data, caster)
	
	# Проверяем хёртбоксы
	for area in areas:
		if area is Hurtbox and area.owner != caster:
			if area.owner and area.owner.has_method("apply_combat_damage_data"):
				area.owner.apply_combat_damage_data(damage_data, caster)
	
	applied = true
