# AIController.gd
extends Node
class_name AIController

enum State { IDLE, CHASE }

@export var move_speed: float = 100.0

var _actor: Actor
var _state: State = State.IDLE
var _target: Node = null
var _is_active: bool = false

func setup(actor: Actor) -> void:
	_actor = actor

func set_active(active: bool) -> void:
	if _is_active == active:
		return
	
	_is_active = active
	set_process(active)
	set_physics_process(active)
	
	if not active:
		_state = State.IDLE
		_target = null
		_actor.velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if not _is_active or not _actor or _actor.current_mode != Actor.MODE_BATTLE:
		return
	
	# Ищем цель (игрока)
	if not _target or not is_instance_valid(_target):
		_find_target()
	
	match _state:
		State.IDLE:
			_process_idle(delta)
		State.CHASE:
			_process_chase(delta)

func _find_target() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_target = players[0]
		_state = State.CHASE
		print_debug("AIController: нашёл цель - ", _target.name)

func _process_idle(delta: float) -> void:
	_actor.velocity = _actor.velocity.move_toward(Vector2.ZERO, move_speed * delta)

func _process_chase(delta: float) -> void:
	if not _target:
		_state = State.IDLE
		return
	
	var direction = (_target.global_position - _actor.global_position).normalized()
	_actor.velocity = direction * move_speed
