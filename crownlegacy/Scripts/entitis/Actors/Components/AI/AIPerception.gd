extends Node
class_name AIPerception

# ==================== СИГНАЛЫ ====================
signal player_detected(player: Player)
signal player_lost(player: Player)
signal player_in_attack_range(player: Player)
signal player_out_of_attack_range(player: Player)

# ==================== ЭКСПОРТ ====================
@export var vision_range: float = 200.0
@export var vision_angle: float = 90.0
@export var hearing_range: float = 150.0
@export var attack_range: float = 40.0

# ==================== ПЕРЕМЕННЫЕ ====================
var owner_node: Node2D
var player: Player = null
var is_player_visible: bool = false
var is_player_in_attack_range: bool = false


func setup(p_owner: Node2D) -> void:
	owner_node = p_owner


func _ready() -> void:
	# Находим игрока по группе
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0] as Player


func _process(_delta: float) -> void:
	if not player or not owner_node:
		return
	
	var distance = owner_node.global_position.distance_to(player.global_position)
	var was_visible = is_player_visible
	var was_in_attack = is_player_in_attack_range
	
	# Проверка видимости
	is_player_visible = _can_see_player(distance)
	is_player_in_attack_range = distance <= attack_range and is_player_visible
	
	# Эмитим сигналы при изменении состояния
	if is_player_visible and not was_visible:
		player_detected.emit(player)
	elif not is_player_visible and was_visible:
		player_lost.emit(player)
	
	if is_player_in_attack_range and not was_in_attack:
		player_in_attack_range.emit(player)
	elif not is_player_in_attack_range and was_in_attack:
		player_out_of_attack_range.emit(player)


func _can_see_player(distance: float) -> bool:
	if distance > vision_range:
		return false
	
	# Проверка угла обзора
	var to_player = (player.global_position - owner_node.global_position).normalized()
	var forward = Vector2.RIGHT.rotated(owner_node.global_rotation)
	var angle = rad_to_deg(forward.angle_to(to_player))
	
	if abs(angle) > vision_angle / 2:
		return false
	
	# Raycast для проверки препятствий
	var space_state = owner_node.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		owner_node.global_position,
		player.global_position
	)
	query.exclude = [owner_node]
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.collider
		return collider == player or collider.is_in_group("player")
	
	return true


# ==================== ГЕТТЕРЫ ====================
func get_direction_to_player() -> Vector2:
	if not player or not owner_node:
		return Vector2.ZERO
	return (player.global_position - owner_node.global_position).normalized()


func get_distance_to_player() -> float:
	if not player or not owner_node:
		return INF
	return owner_node.global_position.distance_to(player.global_position)


func get_player_position() -> Vector2:
	if player:
		return player.global_position
	return Vector2.ZERO


func is_player_detected() -> bool:
	return is_player_visible
