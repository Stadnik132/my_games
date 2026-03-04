# ActorInteractionComponent.gd
extends Area2D
class_name ActorInteractionComponent

# Сигнал для оповещения актёра
signal player_entered_range
signal player_exited_range

@export var interaction_radius: float = 40.0

var _actor: Actor
var _player_in_range: bool = false

func setup(actor: Actor) -> void:
	_actor = actor
	_setup_collision()
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _setup_collision() -> void:
	# Настраиваем форму коллизии
	var shape: CollisionShape2D
	if has_node("CollisionShape2D"):
		shape = $CollisionShape2D
	else:
		shape = CollisionShape2D.new()
		add_child(shape)
	
	var circle = CircleShape2D.new()
	circle.radius = interaction_radius
	shape.shape = circle
	
	# Настройка слоёв: взаимодействуем только с игроком
	collision_layer = 0
	collision_mask = 2  # слой игрока

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not _player_in_range:
		_player_in_range = true
		player_entered_range.emit()

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		player_exited_range.emit()

func is_player_in_range() -> bool:
	return _player_in_range
