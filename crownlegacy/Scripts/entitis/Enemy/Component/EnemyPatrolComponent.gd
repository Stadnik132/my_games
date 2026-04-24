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
	
	print_debug("EnemyPatrolComponent.setup() вызван для: ", owner_node.name)
	print_debug("  Дочерние узлы owner_node:")
	for child in owner_node.get_children():
		print_debug("    - ", child.name, " (тип: ", child.get_class(), ")")
	
	_find_markers_in_children()
	
	if patrol_points.is_empty():
		print_debug("EnemyPatrolComponent: маркеры не найдены!")
		return
	
	_find_nearest_point()
	
	print_debug("EnemyPatrolComponent: настроен с ", patrol_points.size(), " точками, старт с точки ", current_index)


func _find_markers_in_children() -> void:
	patrol_points.clear()
	
	for child in owner_node.get_children():
		if child is Marker2D:
			patrol_points.append(child as Marker2D)
			print_debug("  найден маркер: ", child.name, " позиция (глобальная): ", child.global_position)


func _find_nearest_point() -> void:
	if patrol_points.is_empty():
		return
	
	var nearest_dist = INF
	var nearest_idx = 0
	
	for i in range(patrol_points.size()):
		var point = patrol_points[i]
		if not point or not is_instance_valid(point):
			continue
		
		var local_pos = point.position
		var dist = local_pos.length()
		
		if dist == 0 and patrol_points.size() > 1:
			continue
		
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_idx = i
	
	if nearest_dist == INF:
		nearest_idx = 0
	
	current_index = nearest_idx


func update(delta: float) -> void:
	if patrol_points.is_empty():
		owner_node.velocity = Vector2.ZERO
		return
	
	if current_index >= patrol_points.size():
		current_index = 0
	
	var target_point = patrol_points[current_index]
	if not target_point or not is_instance_valid(target_point):
		print_debug("  целевая точка недействительна!")
		_advance_to_next_point()
		return
	
	if is_waiting:
		wait_timer -= delta
		owner_node.velocity = Vector2.ZERO
		
		if wait_timer <= 0:
			is_waiting = false
			_advance_to_next_point()
		return
	
	var target_global = owner_node.global_position + target_point.position
	var current_global = owner_node.global_position
	var direction = (target_global - current_global).normalized()

	if target_point.position == Vector2.ZERO and patrol_points.size() > 1:
		print_debug("  текущий маркер совпадает с Enemy, сразу к следующему")
		_advance_to_next_point()
		return

	if direction == Vector2.ZERO:
		print_debug("  направление = Vector2.ZERO, ждём в точке")
		is_waiting = true
		wait_timer = wait_time
		return
	
	owner_node.velocity = direction * patrol_speed
	
	var distance = current_global.distance_to(target_global)
	if distance < 8.0:
		owner_node.velocity = Vector2.ZERO
		print_debug("EnemyPatrolComponent: достигли точки ", current_index, " (", target_point.name, ")")
		is_waiting = true
		wait_timer = wait_time


func _advance_to_next_point() -> void:
	if patrol_points.is_empty():
		return
	
	var old_index = current_index
	current_index = (current_index + 1) % patrol_points.size()
	print_debug("EnemyPatrolComponent: переход с точки ", old_index, " на точку ", current_index, " (", patrol_points[current_index].name, ")")
