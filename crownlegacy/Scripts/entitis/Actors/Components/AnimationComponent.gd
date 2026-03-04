# AnimationComponent.gd
class_name AnimationComponent extends Node

var actor: Node
var sprite: Sprite2D
var animation_player: AnimationPlayer

var current_animation: String = ""
var last_facing_direction: String = "down"

func setup(_actor: Node):
	actor = _actor
	
	# Находим компоненты
	if not sprite:
		sprite = actor.get_node_or_null("Sprite2D")
	if not animation_player:
		animation_player = actor.get_node_or_null("AnimationPlayer")
	
	# Проверяем наличие обязательных узлов
	if not animation_player:
		push_error("AnimationComponent: AnimationPlayer не найден у ", actor.name)
	if not sprite:
		push_error("AnimationComponent: Sprite2D не найден у ", actor.name)

func play_animation(anim_name: String, force: bool = false) -> bool:
	if not animation_player or not animation_player.has_animation(anim_name):
		return false
	
	if force or current_animation != anim_name:
		animation_player.play(anim_name)
		current_animation = anim_name
		return true
	return false

func update_facing_direction(velocity: Vector2) -> String:
	if velocity.length() > 10:
		var angle = rad_to_deg(velocity.angle())
		if angle < 0:
			angle += 360
		
		if angle >= 337.5 or angle < 22.5:
			last_facing_direction = "right"
		elif angle >= 22.5 and angle < 67.5:
			last_facing_direction = "down_right"
		elif angle >= 67.5 and angle < 112.5:
			last_facing_direction = "down"
		elif angle >= 112.5 and angle < 157.5:
			last_facing_direction = "down_left"
		elif angle >= 157.5 and angle < 202.5:
			last_facing_direction = "left"
		elif angle >= 202.5 and angle < 247.5:
			last_facing_direction = "up_left"
		elif angle >= 247.5 and angle < 292.5:
			last_facing_direction = "up"
		elif angle >= 292.5 and angle < 337.5:
			last_facing_direction = "up_right"
	
	return last_facing_direction

func get_cardinal_direction() -> String:
	match last_facing_direction:
		"up", "up_left", "up_right":
			return "up"
		"down", "down_left", "down_right":
			return "down"
		"left":
			return "left"
		"right":
			return "right"
		_:
			return "down"

func play_movement_animation(velocity: Vector2) -> void:
	if velocity.length() > 5:
		var dir = get_cardinal_direction()
		play_animation("walk_" + dir)
	else:
		var dir = get_cardinal_direction()
		play_animation("idle_" + dir)
