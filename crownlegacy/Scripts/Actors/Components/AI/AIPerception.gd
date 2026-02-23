# ai_perception.gd
class_name AIPerception extends Node
## Компонент восприятия. Отвечает за обнаружение игрока и сбор информации о нём.

# Настраиваемые параметры
@export var sight_range: float = 500.0  # Дальность зрения
@export var update_interval: float = 0.2  # Как часто обновлять (для оптимизации)

# Ссылки
var actor: Actor
var player: Node2D

# Текущее состояние
var distance_to_player: float = 0.0
var player_position: Vector2 = Vector2.ZERO
var can_see_player: bool = false
var last_seen_position: Vector2 = Vector2.ZERO
var time_since_last_seen: float = 0.0

# Для оптимизации
var update_timer: float = 0.0

func setup(p_actor: Actor) -> void:

	actor = p_actor
	player = _find_player()

func _find_player() -> Node2D:

	return get_tree().get_first_node_in_group("player")

func update(delta: float) -> void:
	# Ленивый поиск игрока
	if not is_instance_valid(player):
		player = _find_player()
		if not player:
			return
	
	update_timer += delta
	if update_timer >= update_interval:
		update_timer = 0.0
		_perform_scan()

func _perform_scan() -> void:

	if not player:
		return
	
	# Обновляем базовую информацию
	var old_player_pos = player_position
	player_position = player.global_position
	distance_to_player = actor.global_position.distance_to(player_position)
	
	# Проверяем видимость (пока просто по дистанции)
	var was_seeing = can_see_player
	can_see_player = distance_to_player <= sight_range
	
	# Если видим игрока - запоминаем позицию
	if can_see_player:
		last_seen_position = player_position
		time_since_last_seen = 0.0
	else:
		time_since_last_seen += update_interval

func is_player_detected() -> bool:
	var result = can_see_player and player != null
	# Для отладки можно оставить, но закомментировать позже
	# print_debug("Perception: is_player_detected? ", result, " can_see=", can_see_player)
	return result

func get_player_distance() -> float:

	return distance_to_player

func get_player_position() -> Vector2:

	if can_see_player:
		return player_position
	return last_seen_position

func has_memory() -> bool:

	return last_seen_position != Vector2.ZERO and time_since_last_seen < 5.0
