extends Node
class_name AIPerception

@export var sight_range: float = 200.0
@export var update_interval: float = 0.2
@export var memory_time: float = 2.0  # сколько секунд помнит позицию игрока

var actor: Actor
var player: Node2D
var distance_to_player: float = 0.0
var player_position: Vector2 = Vector2.ZERO
var can_see_player: bool = false
var last_seen_position: Vector2 = Vector2.ZERO
var time_since_last_seen: float = 0.0

var _timer: Timer

func _ready():
	_timer = Timer.new()
	_timer.wait_time = update_interval
	_timer.timeout.connect(_update_perception)
	add_child(_timer)

func setup(actor_node: Actor) -> void:
	actor = actor_node
	# Находим игрока по группе
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0] as Node2D
	_timer.start()

func _update_perception() -> void:
	if not player or not actor:
		return
	
	var current_pos = actor.global_position
	var player_global_pos = player.global_position
	distance_to_player = current_pos.distance_to(player_global_pos)
	
	# Простая проверка видимости (без учёта препятствий)
	# TODO: добавить RayCast для проверки прямой видимости
	can_see_player = distance_to_player <= sight_range
	
	if can_see_player:
		last_seen_position = player_global_pos
		time_since_last_seen = 0.0
	else:
		time_since_last_seen += update_interval
	
	player_position = player_global_pos

func is_player_detected() -> bool:
	"""Игрок обнаружен (видим или в памяти)"""
	return can_see_player or time_since_last_seen < memory_time

func get_player_position() -> Vector2:
	"""Возвращает позицию игрока (текущую или последнюю известную)"""
	if can_see_player:
		return player.global_position
	else:
		return last_seen_position

func get_distance_to_player() -> float:
	return distance_to_player
