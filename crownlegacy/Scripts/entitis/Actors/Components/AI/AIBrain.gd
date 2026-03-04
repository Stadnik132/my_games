# ai_brain.gd
class_name AIBrain extends Node
## Мозг врага. Принимает решения на основе данных от Perception.

# Настраиваемые параметры
@export var attack_range: float = 50.0  # Дистанция, с которой начинает атаку
@export var memory_time: float = 3.0     # Сколько секунд помнит игрока после потери

# Ссылки
var actor: Actor
var perception: AIPerception

func setup(p_actor: Actor, p_perception: AIPerception) -> void:
	actor = p_actor
	perception = p_perception

func should_move_to_player() -> bool:
	if not perception:
		print_debug("AIBrain: perception is null")
		return false
	
	if not perception.is_player_detected():
		print_debug("AIBrain: player not detected")
		return false
	
	var dist = perception.get_player_distance()
	var result = dist > attack_range
	print_debug("AIBrain: should_move_to_player? ", result, " (dist=", dist, " attack_range=", attack_range, ")")
	return result

func should_attack() -> bool:
	if not perception:
		return false
	
	# Атакуем, если видим игрока и он достаточно близко
	return perception.is_player_detected() and perception.get_player_distance() <= attack_range

func get_target_position() -> Vector2:
	if perception:
		return perception.get_player_position()
	return actor.global_position  # Если ничего нет - остаёмся на месте

func get_attack_range() -> float:
	return attack_range
