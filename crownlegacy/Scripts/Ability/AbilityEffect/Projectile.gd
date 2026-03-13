class_name Projectile extends Area2D

var caster: Node
var damage_data: DamageData
var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var max_distance: float = 500.0
var distance_traveled: float = 0.0
var start_position: Vector2

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func setup(params: Dictionary) -> void:
	caster = params.get("caster")
	damage_data = params.get("damage_data")
	speed = params.get("speed", 300.0)
	max_distance = params.get("max_distance", 500.0)
	
	# Получаем стартовую позицию
	start_position = params.get("start_position", global_position)
	
	# Получаем целевую позицию
	var target_pos = params.get("target_position", start_position + direction * max_distance)
	
	# Вычисляем направление ОТ стартовой позиции К цели
	direction = (target_pos - start_position).normalized()
	if direction == Vector2.ZERO:
		direction = params.get("direction", Vector2.RIGHT)
	
	# Устанавливаем позицию
	global_position = start_position
	
	# Настройка слоёв коллизий
	if caster and caster.is_in_group("player"):
		collision_layer = 4
		collision_mask = 4
		print("Projectile: игрок, на слое 4, ищу слой 4")
	elif caster and caster.is_in_group("enemies"):
		collision_layer = 2
		collision_mask = 2
		print("Projectile: враг, на слое 2, ищу слой 2")
	else:
		collision_layer = 0
		collision_mask = 0
		print("Projectile: неизвестный стрелок")
	
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
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox:
		# Проверяем владельца хертбокса
		if area.entity_owner == caster:
			return
		_apply_damage_to_hurtbox(area)
		queue_free()

func _apply_damage(target: Node) -> void:
	if not target or not damage_data:
		return
	
	var hurtbox = target.get_node_or_null("Hurtbox") as Hurtbox
	if hurtbox:
		_apply_damage_to_hurtbox(hurtbox)

func _apply_damage_to_hurtbox(hurtbox: Hurtbox) -> void:
	hurtbox.damage_taken.emit(damage_data, caster)
	print("Projectile: урон нанесён через hurtbox")
