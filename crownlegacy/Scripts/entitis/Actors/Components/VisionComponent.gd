extends Area2D
class_name VisionComponent

# ==================== СИГНАЛЫ ====================
signal target_entered(target: Node)
signal target_exited(target: Node)

# ==================== ЭКСПОРТ ====================
@export var vision_radius: float = 200.0
@export var target_groups: Array[String] = ["player", "enemies"]

# ==================== ПЕРЕМЕННЫЕ ====================
var _actor: Actor
var _targets_in_range: Array[Node] = []

func setup(actor: Actor) -> void:
	_actor = actor
	_setup_collision()
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _setup_collision() -> void:
	var shape_node: CollisionShape2D
	
	if has_node("CollisionShape2D"):
		shape_node = $CollisionShape2D
	else:
		shape_node = CollisionShape2D.new()
		add_child(shape_node)
	
	var circle = CircleShape2D.new()
	circle.radius = vision_radius
	shape_node.shape = circle
	
	# Настройка слоёв
	collision_layer = 0
	collision_mask = 1  # можно настроить через экспорт

func get_closest_target() -> Node:
	if _targets_in_range.is_empty():
		return null
	
	var closest = _targets_in_range[0]
	var closest_dist = _actor.global_position.distance_to(closest.global_position)
	
	for target in _targets_in_range:
		var dist = _actor.global_position.distance_to(target.global_position)
		if dist < closest_dist:
			closest = target
			closest_dist = dist
	
	return closest

func get_all_targets() -> Array[Node]:
	return _targets_in_range.duplicate()

func _on_body_entered(body: Node) -> void:
	_add_target(body)

func _on_body_exited(body: Node) -> void:
	_remove_target(body)

func _on_area_entered(area: Area2D) -> void:
	_add_target(area)

func _on_area_exited(area: Area2D) -> void:
	_remove_target(area)

func _add_target(node: Node) -> void:
	if node == _actor:
		return
	
	for group in target_groups:
		if node.is_in_group(group):
			if not _targets_in_range.has(node):
				_targets_in_range.append(node)
				target_entered.emit(node)
			return

func _remove_target(node: Node) -> void:
	var idx = _targets_in_range.find(node)
	if idx >= 0:
		_targets_in_range.remove_at(idx)
		target_exited.emit(node)
