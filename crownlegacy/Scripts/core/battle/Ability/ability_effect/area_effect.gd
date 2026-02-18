class_name AreaEffect extends Area2D

var caster: Node
var damage_data: DamageData
var duration: float = 0.5
var applied: bool = false

@onready var collision_shape: CollisionShape2D = $CircleShape2D

func setup(params: Dictionary) -> void:
	caster = params.get("caster")
	damage_data = params.get("damage_data")
	duration = params.get("duration", 0.5)
	
	# === ДИНАМИЧЕСКАЯ НАСТРОЙКА СЛОЁВ КОЛЛИЗИЙ ===
	collision_layer = 0  # Область сама не обнаруживается
	monitoring = true
	monitorable = false
	
	# Определяем, кому принадлежит область
	if caster and caster.is_in_group("player"):
		# Игрок кастует - ищем врагов (слой 4)
		collision_mask = 4
		print("AreaEffect: кастует игрок, ищем врагов (слой 4)")
	elif caster and caster.is_in_group("enemies"):
		# Враг кастует - ищем игрока (слой 2)
		collision_mask = 2
		print("AreaEffect: кастует враг, ищем игрока (слой 2)")
	else:
		# По умолчанию - ищем всё, но с проверкой владельца
		collision_mask = 2 | 4
		print("AreaEffect: кастует неизвестный, ищем все слои")
	# =============================================
	
	# Настраиваем радиус
	if params.has("radius") and collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = params["radius"]
	
	# Сохраняем ссылку на дерево
	var tree = get_tree()
	if not tree:
		queue_free()
		return
	
	# Ждём физический кадр для обновления коллизий
	await tree.physics_frame
	await tree.physics_frame  # Два кадра для гарантии обновления физики
	
	if not is_inside_tree():
		return
	
	_apply_damage()
	
	# Ждём и удаляем
	await tree.create_timer(duration).timeout
	
	if is_inside_tree():
		queue_free()

func _apply_damage() -> void:
	if applied:
		return
	
	print("=== AREA EFFECT APPLY DAMAGE ===")
	print("caster: ", caster)
	print("damage_data: ", damage_data.amount if damage_data else "null")
	print("collision_mask = ", collision_mask)
	print("collision_layer = ", collision_layer)
	
	var bodies = get_overlapping_bodies()
	var areas = get_overlapping_areas()
	
	print("bodies found: ", bodies.size())
	print("areas found: ", areas.size())
	
	# Проверяем тела
	for body in bodies:
		print("  body: ", body.name, " (", body, ")")
		if body == caster:
			print("    -> пропускаем, это кастер")
			continue
		if body.has_method("apply_combat_damage_data"):
			print("    -> ЕСТЬ метод apply_combat_damage_data, применяем урон")
			body.apply_combat_damage_data(damage_data, caster)
		else:
			print("    -> НЕТ метода apply_combat_damage_data")
	
	# Проверяем хёртбоксы
	for area in areas:
		print("  area: ", area.name, " (", area, ")")
		print("    area.layer = ", area.collision_layer)
		if area is Hurtbox:
			print("    -> это Hurtbox, owner: ", area.owner)
			print("    area.collision_layer = ", area.collision_layer)
			if area.owner != caster:
				if area.owner and area.owner.has_method("apply_combat_damage_data"):
					print("    -> применяем урон к owner")
					area.owner.apply_combat_damage_data(damage_data, caster)
				else:
					print("    -> owner не имеет метода apply_combat_damage_data")
			else:
				print("    -> owner - кастер, пропускаем")
	
	applied = true
