extends Node
class_name AIBrain

enum Decision { IDLE, CHASE, ATTACK, CAST, FLEE, STRAFE }

@export var attack_range: float = 40.0
@export var flee_health_ratio: float = 0.15
@export var strafe_range: float = 60.0
@export var cast_prefer_distance: float = 120.0

class AIContext:
	var distance: float
	var player_position: Vector2
	var actor_position: Vector2
	var health_ratio: float
	var attack_cooldown: float
	var is_attacking: bool
	var can_cast: bool
	var abilities_ready: Array
	var has_ranged_ability: bool
	var has_melee_ability: bool

	func _init(
		p_distance: float,
		p_player_position: Vector2,
		p_actor_position: Vector2,
		p_health_ratio: float,
		p_attack_cooldown: float,
		p_is_attacking: bool,
		p_can_cast: bool,
		p_abilities_ready: Array,
		p_has_ranged: bool,
		p_has_melee: bool
	):
		distance = p_distance
		player_position = p_player_position
		actor_position = p_actor_position
		health_ratio = p_health_ratio
		attack_cooldown = p_attack_cooldown
		is_attacking = p_is_attacking
		can_cast = p_can_cast
		abilities_ready = p_abilities_ready
		has_ranged_ability = p_has_ranged
		has_melee_ability = p_has_melee


func _get_desired_range(ctx: AIContext) -> float:
	if ctx.has_ranged_ability:
		return cast_prefer_distance
	return attack_range


func decide(ctx: AIContext) -> int:
	var scores = {}
	scores[Decision.IDLE] = _score_idle(ctx)
	scores[Decision.CHASE] = _score_chase(ctx)
	scores[Decision.ATTACK] = _score_attack(ctx)
	scores[Decision.CAST] = _score_cast(ctx)
	scores[Decision.FLEE] = _score_flee(ctx)
	scores[Decision.STRAFE] = _score_strafe(ctx)

	var best = Decision.IDLE
	for action in scores:
		if scores[action] > scores[best]:
			best = action
	return best


func _score_idle(_ctx: AIContext) -> float:
	return 0.0


func _score_chase(ctx: AIContext) -> float:
	var desired = _get_desired_range(ctx)
	if ctx.distance > desired * 1.3:
		return 1.0
	return 0.0


func _score_attack(ctx: AIContext) -> float:
	if ctx.is_attacking:
		return 0.0
	if ctx.attack_cooldown > 0.0:
		return 0.0
	var dx = abs(ctx.player_position.x - ctx.actor_position.x)
	if dx > attack_range:
		return 0.0
	return 2.0


func _score_cast(ctx: AIContext) -> float:
	if not ctx.can_cast or ctx.abilities_ready.is_empty():
		return 0.0
	for entry in ctx.abilities_ready:
		var ab = entry.ability as AbilityResource
		if not ab:
			continue
		var is_ranged = ab.ability_type == AbilityResource.AbilityType.PROJECTILE or ab.ability_type == AbilityResource.AbilityType.AREA
		var is_melee = ab.ability_type == AbilityResource.AbilityType.INSTANT or ab.ability_type == AbilityResource.AbilityType.SELF_TARGET
		if is_ranged and ctx.distance >= attack_range:
			return 3.0
		if is_melee and ctx.distance <= attack_range:
			return 3.0
	return 0.0


func _score_flee(ctx: AIContext) -> float:
	if ctx.health_ratio <= flee_health_ratio:
		return 1.0 - ctx.health_ratio + 0.01
	return 0.0


func _score_strafe(ctx: AIContext) -> float:
	var desired = _get_desired_range(ctx)
	if ctx.distance < desired * 0.6:
		return 1.5
	if ctx.distance >= desired * 0.6 and ctx.distance <= desired * 1.4:
		return 0.7
	return 0.0


func pick_best_ability(ctx: AIContext) -> Dictionary:
	if ctx.abilities_ready.is_empty():
		return {}
	var is_close = ctx.distance <= attack_range
	var is_far = ctx.distance >= cast_prefer_distance
	var preferred = []
	for entry in ctx.abilities_ready:
		var ab = entry.ability as AbilityResource
		if ab == null:
			continue
		var matches = false
		if is_far and (ab.ability_type == AbilityResource.AbilityType.PROJECTILE or ab.ability_type == AbilityResource.AbilityType.AREA):
			matches = true
		elif is_close and (ab.ability_type == AbilityResource.AbilityType.INSTANT or ab.ability_type == AbilityResource.AbilityType.SELF_TARGET):
			matches = true
		elif not is_close and not is_far:
			matches = true
		if matches:
			preferred.append(entry)
	if not preferred.is_empty():
		return preferred[0]
	return ctx.abilities_ready[0]
