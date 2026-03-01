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
	collision_layer = 0
	
	if caster and caster.is_in_group("player"):
		collision_mask = 4
		print("Projectile: стреляет игрок, ищем врагов (слой 4)")
	elif caster and caster.is_in_group("enemies"):
		collision_mask = 2
		print("Projectile: стреляет враг, ищем игрока (слой 2)")
	else:
		collision_mask = 0
		print("Projectile: неизвестный стрелок, никого не ищем")
	
	# Подключаем сигналы
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	var motion = direction * speed * delta
	position += motion
	distance_traveled += motion.length()
	
	# Удаляем, если пролетел максимальную дистанцию
	if distance_traveled >= max_distance:
		queue_free()

# При столкновении с телом (например, стена)
func _on_body_entered(body: Node) -> void:
	# Не наносим урон тому, кто стрелял
	if body == caster:
		return
	
	# Применяем урон, если это враг
	_apply_damage(body)
	
	# Удаляем снаряд при столкновении с ЛЮБЫМ телом
	queue_free()

# При столкновении с областью (Hurtbox)
func _on_area_entered(area: Area2D) -> void:
	# Проверяем, что это Hurtbox и принадлежит не стрелку
	if area is Hurtbox and area.owner != caster:
		_apply_damage(area.owner)
		
		# Удаляем снаряд при попадании
		queue_free()

func _apply_damage(target: Node) -> void:
	if target and target.has_method("apply_combat_damage_data"):
		target.apply_combat_damage_data(damage_data, caster)
