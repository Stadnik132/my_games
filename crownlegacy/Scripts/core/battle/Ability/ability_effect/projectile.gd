class_name Projectile extends Area2D

var caster: Node
var damage_data: DamageData
var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var max_distance: float = 500.0
var distance_traveled: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D  # если понадобится

func setup(params: Dictionary) -> void:
	caster = params.get("caster")
	damage_data = params.get("damage_data")
	direction = params.get("direction", Vector2.RIGHT)
	speed = params.get("speed", 300.0)
	max_distance = params.get("max_distance", 500.0)
	
	# Подключаем сигналы
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	var motion = direction * speed * delta
	position += motion
	distance_traveled += motion.length()
	
	if distance_traveled >= max_distance:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body == caster:
		return
	_apply_damage(body)

func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox and area.owner != caster:
		_apply_damage(area.owner)

func _apply_damage(target: Node) -> void:
	if target and target.has_method("apply_combat_damage_data"):
		target.apply_combat_damage_data(damage_data, caster)
	
	queue_free()
