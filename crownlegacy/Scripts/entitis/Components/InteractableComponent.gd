extends Area2D
class_name InteractableComponent

signal player_entered_range
signal player_exited_range
signal interacted

@export var interaction_radius: float = 26.0

var _player_in_range: bool = false

func _ready() -> void:
	_setup_collision()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	EventBus.Interaction.requested.connect(_on_interaction_requested)

func _setup_collision() -> void:
	var shape: CollisionShape2D
	if has_node("CollisionShape2D"):
		shape = $CollisionShape2D
	else:
		shape = CollisionShape2D.new()
		add_child(shape)
	var circle = CircleShape2D.new()
	circle.radius = interaction_radius
	shape.shape = circle
	collision_layer = 0
	collision_mask = 2

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not _player_in_range:
		_player_in_range = true
		player_entered_range.emit()

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		player_exited_range.emit()

func _on_interaction_requested() -> void:
	if _player_in_range:
		interacted.emit()

func is_player_in_range() -> bool:
	return _player_in_range
