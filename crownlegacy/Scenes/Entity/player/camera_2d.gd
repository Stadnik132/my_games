extends Camera2D
class_name AdvancedSmoothCamera2D

@export_category("Follow Settings")
@export var follow_speed: float = 4.0
@export var deadzone_size: Vector2 = Vector2(100, 60)  # Размер мёртвой зоны

@export_category("Look Ahead")
@export var look_ahead_amount: float = 80.0
@export var look_ahead_speed: float = 2.0

var target: Node2D
var current_look_ahead: Vector2 = Vector2.ZERO
var camera_offset: Vector2 = Vector2.ZERO


func _ready():
	# Открепляем камеру от игрока, чтобы управлять ей вручную
	if get_parent():
		target = get_parent()
		# Важно: делаем камеру top-level, чтобы она не двигалась с родителем
		top_level = true
		global_position = target.global_position


func _process(delta):
	if not target:
		return
	
	# 1. Получаем позицию игрока относительно текущей позиции камеры
	var target_pos = target.global_position
	var camera_to_target = target_pos - global_position
	
	# 2. Проверяем, вышел ли игрок за пределы deadzone
	var move_camera = false
	var move_vector = Vector2.ZERO
	
	if abs(camera_to_target.x) > deadzone_size.x / 2:
		move_vector.x = camera_to_target.x - (sign(camera_to_target.x) * deadzone_size.x / 2)
		move_camera = true
	
	if abs(camera_to_target.y) > deadzone_size.y / 2:
		move_vector.y = camera_to_target.y - (sign(camera_to_target.y) * deadzone_size.y / 2)
		move_camera = true
	
	# 3. Обновляем look-ahead на основе движения игрока
	_update_look_ahead(delta)
	
	# 4. Двигаем камеру только если игрок вне deadzone
	if move_camera:
		var desired_position = global_position + move_vector
		global_position = global_position.lerp(desired_position, follow_speed * delta)
	
	# Применяем look-ahead оффсет
	offset = current_look_ahead + camera_offset


func _update_look_ahead(delta):
	if not target is Player:
		return
	
	# Получаем направление движения игрока
	var player_velocity = target.velocity if target.has_method("get_velocity") else Vector2.ZERO
	
	if player_velocity.length() > 10:
		var target_look_ahead = player_velocity.normalized() * look_ahead_amount
		current_look_ahead = current_look_ahead.lerp(target_look_ahead, look_ahead_speed * delta)
	else:
		# Возвращаем look-ahead к нулю, когда игрок стоит
		current_look_ahead = current_look_ahead.lerp(Vector2.ZERO, look_ahead_speed * delta)


func set_temporary_offset(new_offset: Vector2, return_speed: float = 2.0):
	"""Для эффектов тряски или фокусировки на объекте"""
	camera_offset = new_offset
	
	# Создаём твин для плавного возврата
	var tween = create_tween()
	tween.tween_property(self, "camera_offset", Vector2.ZERO, return_speed)
