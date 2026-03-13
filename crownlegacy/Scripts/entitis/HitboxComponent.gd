extends Node
class_name HitboxComponent

signal hit_enemy(enemy: Node, damage: int, is_critical: bool)

@export var hitbox_scene: PackedScene
@export var default_lifetime: float = 0.1

var owner_node: Node
var _active_hitboxes: Array[Hitbox] = []

func _ready() -> void:
	owner_node = get_parent()
	
	if not hitbox_scene:
		push_error("HitboxComponent: hitbox_scene не назначен!")

func spawn_hitbox(
	position: Vector2,
	damage_amount: int,
	damage_type: int = 0,
	is_critical: bool = false,
	direction: Vector2 = Vector2.ZERO,
	lifetime: float = -1.0
) -> Hitbox:
	if not hitbox_scene:
		return null
	
	var hitbox = hitbox_scene.instantiate() as Hitbox
	if not hitbox:
		push_error("HitboxComponent: сцена не содержит Hitbox!")
		return null
	
	var damage = DamageData.new()
	damage.amount = damage_amount
	damage.damage_type = damage_type
	damage.is_critical = is_critical
	damage.source = owner_node
	
	hitbox.set_damage_data(damage)
	hitbox.direction = direction
	hitbox.lifetime = lifetime if lifetime > 0 else default_lifetime
	hitbox.global_position = position
	
	# ВАЖНО: Добавляем в корень сцены
	get_tree().current_scene.add_child(hitbox)
	
	_active_hitboxes.append(hitbox)
	hitbox.tree_exited.connect(_on_hitbox_removed.bind(hitbox))
	
	return hitbox

func spawn_area_hitbox(
	center: Vector2,
	radius: float,
	damage_amount: int,
	damage_type: int = 0,
	duration: float = 0.2
) -> Hitbox:
	var hitbox = spawn_hitbox(center, damage_amount, damage_type, false, Vector2.ZERO, duration)
	
	if hitbox and hitbox.has_node("CollisionShape2D"):
		var shape_node = hitbox.get_node("CollisionShape2D")
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = radius
		shape_node.shape = circle_shape
	
	return hitbox

func clear_hitboxes() -> void:
	for hitbox in _active_hitboxes:
		if is_instance_valid(hitbox):
			hitbox.queue_free()
	_active_hitboxes.clear()

func _on_hitbox_removed(hitbox: Hitbox) -> void:
	_active_hitboxes.erase(hitbox)

func spawn_hitbox_with_damage(position: Vector2, direction: Vector2, damage_data: DamageData) -> Hitbox:
	if not hitbox_scene:
		return null
	
	var hitbox = hitbox_scene.instantiate() as Hitbox
	if not hitbox:
		push_error("HitboxComponent: сцена не содержит Hitbox!")
		return null
	
	hitbox.set_damage_data(damage_data)
	hitbox.direction = direction
	hitbox.lifetime = default_lifetime
	hitbox.global_position = position
	
	get_tree().current_scene.add_child(hitbox)
	
	_active_hitboxes.append(hitbox)
	hitbox.tree_exited.connect(_on_hitbox_removed.bind(hitbox))
	
	return hitbox
