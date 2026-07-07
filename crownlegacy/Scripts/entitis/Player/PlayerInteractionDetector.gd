class_name PlayerInteractionDetector extends Area2D

signal interactable_changed(interactable: Node)

var current_interactable: Node = null
var _nearby: Array[Node] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _on_body_entered(body: Node) -> void:
	if body == get_parent():
		return
	if body.is_in_group("interactable"):
		_nearby.append(body)
		_update_nearest()

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("interactable"):
		_nearby.erase(body)
		_update_nearest()

func _on_area_entered(area: Area2D) -> void:
	if area == get_parent():
		return
	if area.is_in_group("interactable"):
		_nearby.append(area)
		_update_nearest()

func _on_area_exited(area: Area2D) -> void:
	if area.is_in_group("interactable"):
		_nearby.erase(area)
		_update_nearest()

func _update_nearest() -> void:
	var best: Node = null
	var best_dist: float = INF
	for node in _nearby:
		if not is_instance_valid(node):
			continue
		var dist = global_position.distance_squared_to(node.global_position)
		if dist < best_dist:
			best_dist = dist
			best = node
	if best != current_interactable:
		current_interactable = best
		interactable_changed.emit(best)

func interact() -> bool:
	if not is_instance_valid(current_interactable):
		return false
	if current_interactable.has_method("interact"):
		current_interactable.interact()
		return true
	return false

func has_interactable() -> bool:
	return is_instance_valid(current_interactable)
