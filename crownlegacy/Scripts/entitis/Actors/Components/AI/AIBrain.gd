# AIBrain.gd
extends Node
class_name AIBrain

# ==================== ТИПЫ РЕШЕНИЙ ====================
enum CombatDecision { 
	IDLE,    # Ничего не делать
	WALK,    # Двигаться к цели
	ATTACK,  # Атаковать
	CAST     # Использовать способность
}

# ==================== ЭКСПОРТ ====================
@export var attack_range: float = 30.0                   # Дистанция для атаки в случае отсутствия данных из hitbox
@export var ability_usage_chance: float = 0.3            # Шанс выбрать способность, если игрок рядом
@export var ability_prefer_distance: float = 120.0       # Если игрок дальше этой дистанции, NPC предпочитает каст
@export var attack_distance_buffer: float = 8.0          # Отступ при подходе, чтобы не налететь в плотную
@export var obstacle_avoidance_distance: float = 40.0    # Смещение при обходе препятствия
@export var memory_search_radius: float = 16.0           # Радиус для завершения поиска последнего известного положения

# ==================== ССЫЛКИ ====================
var actor: Node2D
var perception: AIPerception
var combat_component: ActorCombatComponent

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func setup(actor_node: Node2D, perception_node: AIPerception, combat_node: ActorCombatComponent) -> void:
	actor = actor_node
	perception = perception_node
	combat_component = combat_node

# ==================== ОСНОВНАЯ ЛОГИКА ====================
func decide() -> Dictionary:
	# Если игрок не обнаружен и нет памяти - стоим
	if not perception.is_player_detected():
		return {"type": CombatDecision.IDLE}

	var player_visible = perception.is_player_visible
	var target_position = perception.get_player_position() if player_visible else perception.get_last_known_player_position()
	var distance_to_target = actor.global_position.distance_to(target_position)
	var effective_attack_range = _get_effective_attack_range()

	# Если игрок виден и достаточно далеко, предпочитаем каст способности
	if player_visible and distance_to_target > ability_prefer_distance:
		var slot = _get_ranged_ability_slot(distance_to_target)
		if slot >= 0:
			return {
				"type": CombatDecision.CAST,
				"slot": slot,
				"target": target_position
			}

	# Если игрок не в зоне атаки — идем к нему, стараясь встать на дистанцию hitbox
	if distance_to_target > effective_attack_range:
		var walk_target = _get_walk_target(target_position, effective_attack_range)
		walk_target = _adjust_target_for_obstacle(walk_target)
		return {
			"type": CombatDecision.WALK,
			"target": walk_target
		}

	# Если игрок помнен, но уже достигли последней точки — перестаем искать
	if not player_visible and distance_to_target <= memory_search_radius:
		return {"type": CombatDecision.IDLE}

	# Если игрок рядом и виден, атаковать или кастовать
	if player_visible:
		var ability_slot = _get_close_ability_slot()
		if ability_slot >= 0 and randf() < ability_usage_chance:
			return {
				"type": CombatDecision.CAST,
				"slot": ability_slot,
				"target": target_position
			}
		return {
			"type": CombatDecision.ATTACK,
			"target": target_position
		}

	# Если игрок скрыт, но мы всё ещё помним его позицию — идем к ней
	return {
		"type": CombatDecision.WALK,
		"target": _adjust_target_for_obstacle(target_position)
	}

# ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ====================
func _get_effective_attack_range() -> float:
	if combat_component and combat_component.hitbox_component:
		var hitbox_range = combat_component.hitbox_component.get_attack_range()
		if hitbox_range > 0.0:
			return hitbox_range + attack_distance_buffer
	return attack_range

func _get_walk_target(target_position: Vector2, desired_distance: float) -> Vector2:
	var direction = (target_position - actor.global_position).normalized()
	if direction == Vector2.ZERO:
		return actor.global_position
	return target_position - direction * desired_distance

func _get_ranged_ability_slot(distance_to_target: float) -> int:
	if not combat_component or not combat_component.ability_component:
		return -1

	var ability_comp = combat_component.ability_component
	var available = []
	for i in range(ability_comp.slots.size()):
		if not ability_comp.can_cast_ability(i):
			continue
		var ability = ability_comp.get_ability_in_slot(i)
		if ability and ability.max_cast_range >= distance_to_target:
			available.append(i)
	
	if available.is_empty():
		return -1
	return available[randi() % available.size()]

func _get_close_ability_slot() -> int:
	if not combat_component or not combat_component.ability_component:
		return -1

	var available = []
	var ability_comp = combat_component.ability_component
	for i in range(ability_comp.slots.size()):
		if ability_comp.can_cast_ability(i):
			available.append(i)
	
	if available.is_empty():
		return -1
	return available[randi() % available.size()]

func _adjust_target_for_obstacle(target_position: Vector2) -> Vector2:
	var origin = actor.global_position
	if not _is_path_blocked(origin, target_position):
		return target_position

	var hit = _get_first_obstacle_hit(origin, target_position)
	if not hit:
		return target_position

	var direction = (target_position - origin).normalized()
	var side = direction.tangent().normalized()
	var candidate_a = hit.position + side * obstacle_avoidance_distance
	var candidate_b = hit.position - side * obstacle_avoidance_distance

	var a_clear = not _is_path_blocked(origin, candidate_a)
	var b_clear = not _is_path_blocked(origin, candidate_b)

	if a_clear and b_clear:
		return candidate_a if origin.distance_to(candidate_a) < origin.distance_to(candidate_b) else candidate_b
	if a_clear:
		return candidate_a
	if b_clear:
		return candidate_b

	return origin + direction.rotated(PI * 0.5) * obstacle_avoidance_distance

func _is_path_blocked(from_position: Vector2, to_position: Vector2) -> bool:
	var query = PhysicsRayQueryParameters2D.create(from_position, to_position)
	query.exclude = [actor]
	var result = actor.get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false
	return not (result.collider == perception.player or result.collider.is_in_group("player"))

func _get_first_obstacle_hit(from_position: Vector2, to_position: Vector2) -> Dictionary:
	var query = PhysicsRayQueryParameters2D.create(from_position, to_position)
	query.exclude = [actor]
	return actor.get_world_2d().direct_space_state.intersect_ray(query)
