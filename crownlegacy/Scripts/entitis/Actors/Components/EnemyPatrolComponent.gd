extends Node
class_name EnemyPatrolComponent

@export var patrol_speed: float = 60.0
@export var wait_time: float = 1.5
@export var show_debug: bool = false

var patrol_points: Array[Marker2D] = []
var current_index: int = 0
var wait_timer: float = 0.0
var is_waiting: bool = false
var owner_node: Node2D


func setup(p_owner: Node2D) -> void:
	owner_node = p_owner
	
	_find_markers_in_children()
	
	if patrol_points.is_empty():
		return
	
	_find_nearest_point()
	

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
		if not point or not is_instance_valid(point):
			continue
		
		var dist = owner_node.global_position.distance_to(point.global_position)
		
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
	
	var target_global = target_point.global_position
	var direction = (target_global - owner_node.global_position).normalized()
	
	if direction == Vector2.ZERO:
		is_waiting = true
		wait_timer = wait_time
		return
	
	owner_node.velocity = direction * patrol_speed
	
	var distance = owner_node.global_position.distance_to(target_global)
	if distance < 8.0:
		owner_node.velocity = Vector2.ZERO
		is_waiting = true
		wait_timer = wait_time


func _advance_to_next_point() -> void:
	if patrol_points.is_empty():
		return
	current_index = (current_index + 1) % patrol_points.size()
