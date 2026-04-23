extends Node
class_name EnemyPatrolComponent

@export var patrol_speed: float = 60.0
@export var wait_time: float = 1.5

var patrol_points: Array[Marker2D] = []
var current_index: int = 0
var wait_timer: float = 0.0
var is_waiting: bool = false
var owner_node: Node2D


func setup(p_owner: Node2D) -> void:
	owner_node = p_owner
	
	# Автоматически ищем Marker2D среди детей этого компонента
	_find_markers_in_children()
	
	if patrol_points.is_empty():
		print_debug("EnemyPatrolComponent: маркеры не найдены!")
		return
	
	# Начинаем с ближайшей точки
	_find_nearest_point()
	
	print_debug("EnemyPatrolComponent: настроен с ", patrol_points.size(), " точками")


func _find_markers_in_children() -> void:
	patrol_points.clear()
	
	for child in get_children():
		if child is Marker2D:
			patrol_points.append(child as Marker2D)


func _find_nearest_point() -> void:
	if patrol_points.is_empty():
		return
	
	var nearest_dist = INF
	var nearest_idx = 0
	
	for i in range(patrol_points.size()):
		var point = patrol_points[i]
		# Маркеры внутри компонента, позиция относительно врага
		var point_global = owner_node.global_position + point.position
		var dist = owner_node.global_position.distance_to(point_global)
		
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_idx = i
	
	current_index = nearest_idx


func update(delta: float) -> void:
	if patrol_points.is_empty():
		owner_node.velocity = Vector2.ZERO
		return
	
	if current_index >= patrol_points.size():
		current_index = 0
	
	var target_point = patrol_points[current_index]
	if not target_point or not is_instance_valid(target_point):
		_advance_to_next_point()
		return
	
	if is_waiting:
		wait_timer -= delta
		owner_node.velocity = Vector2.ZERO
		if wait_timer <= 0:
			is_waiting = false
			_advance_to_next_point()
		return
	
	# Позиция маркера относительно врага
	var target_global = owner_node.global_position + target_point.position
	var direction = (target_global - owner_node.global_position).normalized()
	owner_node.velocity = direction * patrol_speed
	
	var distance = owner_node.global_position.distance_to(target_global)
	if distance < 5.0:
		is_waiting = true
		wait_timer = wait_time


func _advance_to_next_point() -> void:
	if patrol_points.is_empty():
		return
	
	current_index = (current_index + 1) % patrol_points.size()
