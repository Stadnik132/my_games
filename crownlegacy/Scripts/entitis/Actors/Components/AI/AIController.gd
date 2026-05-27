extends Node
class_name AIController

var actor: Node2D
var brain: AIBrain
var combat_component: ActorCombatComponent

var _tick_timer: float = 0.0
const TICK_INTERVAL: float = 0.2
var _attack_cooldown: float = 0.0
const ATTACK_COOLDOWN: float = 0.8

var _player: Node2D = null
var is_active: bool = false

const RAYCAST_DISTANCE: float = 45.0
const RAYCAST_ANGLES: Array[float] = [0.0, 45.0, -45.0, 90.0, -90.0]


func setup(actor_node: Node2D) -> void:
	actor = actor_node
	brain = actor.get_node_or_null("AIBrain")
	combat_component = actor.get_node_or_null("ActorCombatComponent")


func _ready() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]


func set_active(active: bool) -> void:
	is_active = active
	set_process(active)
	if not active:
		if combat_component:
			combat_component.set_desired_move(Vector2.ZERO)
		_attack_cooldown = 0.0


func _process(delta: float) -> void:
	if not is_active or not brain or not combat_component or not _player:
		return

	var fsm = combat_component.get_fsm()
	if not fsm:
		return

	_tick_timer -= delta
	if _tick_timer > 0:
		return
	_tick_timer = TICK_INTERVAL

	var state = fsm.get_current_state_name()
	if state in ["Attack", "Cast", "Stun"]:
		combat_component.set_desired_move(Vector2.ZERO)
		return

	if _attack_cooldown > 0.0:
		_attack_cooldown -= TICK_INTERVAL

	var dist = actor.global_position.distance_to(_player.global_position)

	var health_ratio = 1.0
	var health_comp = actor.get_node_or_null("HealthComponent") as HealthComponent
	if health_comp:
		health_ratio = float(health_comp.get_current_health()) / health_comp.get_max_health()

	var has_ranged = false
	var has_melee = false
	var abilities_ready = []
	if combat_component.ability_component:
		for i in range(combat_component.ability_component.slots.size()):
			if combat_component.ability_component.can_cast_ability(i):
				var ability = combat_component.ability_component.get_ability_in_slot(i)
				if ability:
					abilities_ready.append({ "slot_index": i, "ability": ability })
					if ability.ability_type == AbilityResource.AbilityType.PROJECTILE or ability.ability_type == AbilityResource.AbilityType.AREA:
						has_ranged = true
					elif ability.ability_type == AbilityResource.AbilityType.INSTANT or ability.ability_type == AbilityResource.AbilityType.SELF_TARGET:
						has_melee = true

	var ctx = AIBrain.AIContext.new(
		dist,
		_player.global_position,
		actor.global_position,
		health_ratio,
		_attack_cooldown,
		state == "Attack",
		not abilities_ready.is_empty(),
		abilities_ready,
		has_ranged,
		has_melee
	)

	var decision = brain.decide(ctx)
	_execute(decision, fsm, ctx)


func _find_clear_direction(desired: Vector2) -> Vector2:
	var space_state = actor.get_world_2d().direct_space_state
	var exclude = [actor]
	for p in get_tree().get_nodes_in_group("player"):
		exclude.append(p)

	for angle in RAYCAST_ANGLES:
		var dir = desired.rotated(deg_to_rad(angle))
		var query = PhysicsRayQueryParameters2D.new()
		query.from = actor.global_position + dir * 1.0
		query.to = actor.global_position + dir * RAYCAST_DISTANCE
		query.collision_mask = 7
		query.exclude = exclude
		if space_state.intersect_ray(query).is_empty():
			return dir
	return desired


func _apply_separation(desired: Vector2) -> Vector2:
	var group = "enemies"
	if actor.is_in_group("player"):
		group = "player"
	var others = get_tree().get_nodes_in_group(group)
	var repel = Vector2.ZERO
	for other in others:
		if other == actor:
			continue
		var dist = actor.global_position.distance_to(other.global_position)
		if dist < 30.0 and dist > 0.01:
			var force = (1.0 - dist / 30.0) * 0.8
			repel += (actor.global_position - other.global_position).normalized() * force
	return (desired + repel).normalized()


func _execute(decision: int, fsm: EntityCombatFSM, ctx: AIBrain.AIContext) -> void:
	match decision:
		AIBrain.Decision.IDLE:
			combat_component.set_desired_move(Vector2.ZERO)

		AIBrain.Decision.CHASE:
			var dir = (_player.global_position - actor.global_position).normalized()
			if dir == Vector2.ZERO:
				return
			dir = _find_clear_direction(dir)
			dir = _apply_separation(dir)
			combat_component.set_desired_move(dir)
			fsm.send_command("walk", {"direction": dir})

		AIBrain.Decision.ATTACK:
			combat_component.set_desired_move(Vector2.ZERO)
			fsm.send_command("attack")
			_attack_cooldown = ATTACK_COOLDOWN

		AIBrain.Decision.CAST:
			combat_component.set_desired_move(Vector2.ZERO)
			if not combat_component.ability_component:
				return
			var best = brain.pick_best_ability(ctx)
			if best.is_empty():
				return
			var ability = best.ability as AbilityResource
			fsm.send_command("cast", {
				"slot_index": best.slot_index,
				"target_position": _player.global_position,
				"ability": ability
			})

		AIBrain.Decision.FLEE:
			var dir = (actor.global_position - _player.global_position).normalized()
			if dir == Vector2.ZERO:
				return
			dir = _find_clear_direction(dir)
			dir = _apply_separation(dir)
			combat_component.set_desired_move(dir)
			fsm.send_command("walk", {"direction": dir})

		AIBrain.Decision.STRAFE:
			var to_player = (_player.global_position - actor.global_position).normalized()
			var dist = actor.global_position.distance_to(_player.global_position)
			var dir: Vector2
			if dist < brain.attack_range * 0.6:
				dir = -to_player
			else:
				dir = Vector2(-to_player.y, to_player.x)
			if dir == Vector2.ZERO:
				return
			dir = _find_clear_direction(dir)
			dir = _apply_separation(dir)
			combat_component.set_desired_move(dir)
			fsm.send_command("walk", {"direction": dir})
