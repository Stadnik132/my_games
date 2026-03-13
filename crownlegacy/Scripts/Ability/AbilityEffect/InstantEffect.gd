class_name InstantEffect extends Area2D

var caster: Node
var damage_data: DamageData
var direction: Vector2 = Vector2.RIGHT
var radius: float = 80.0
var duration: float = 0.2
var _affected_targets: Array = []

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func setup(params: Dictionary) -> void:
	caster = params.get("caster")
	damage_data = params.get("damage_data")
	direction = params.get("direction", Vector2.RIGHT)
	radius = params.get("radius", 80.0)
	duration = params.get("duration", 0.2)
	
	# Настройка слоёв коллизий
	if caster and caster.is_in_group("player"):
		collision_layer = 4
		collision_mask = 4
	elif caster and caster.is_in_group("enemies"):
		collision_layer = 2
		collision_mask = 2
	else:
		collision_layer = 0
		collision_mask = 0
	
	# Настраиваем радиус
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = radius
	
	# Подключаем сигналы
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	# Применяем урон сразу (если кто-то уже в области)
	_apply_initial_damage()
	
	call_deferred("_queue_after_duration")

func _apply_initial_damage() -> void:
	if not damage_data:
		return
	
	# Собираем цели из тел
	for body in get_overlapping_bodies():
		if body == caster:
			continue
		var hurtbox = body.get_node_or_null("Hurtbox") as Hurtbox
		if hurtbox and hurtbox.entity_owner != caster:
			_damage_target(hurtbox)
	
	# Собираем цели из областей
	for area in get_overlapping_areas():
		if area is Hurtbox and area.entity_owner != caster:
			_damage_target(area)

func _damage_target(target: Hurtbox) -> void:
	if target in _affected_targets:
		return
	
	_affected_targets.append(target)
	target.damage_taken.emit(damage_data, caster)

func _on_area_entered(area: Area2D) -> void:
	if not damage_data:
		return
	if area is Hurtbox and area.entity_owner != caster:
		_damage_target(area)

func _on_body_entered(body: Node) -> void:
	if not damage_data or body == caster:
		return
	var hurtbox = body.get_node_or_null("Hurtbox") as Hurtbox
	if hurtbox and hurtbox.entity_owner != caster:
		_damage_target(hurtbox)

func _queue_after_duration() -> void:
	await get_tree().create_timer(duration).timeout
	queue_free()
