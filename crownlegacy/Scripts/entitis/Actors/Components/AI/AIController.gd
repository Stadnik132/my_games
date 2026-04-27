extends Node
class_name AIController

var actor: Node2D
var brain: AIBrain
var perception: AIPerception
var combat_component: ActorCombatComponent
var is_active: bool = false

var _tick_timer: float = 0.0
const TICK_INTERVAL: float = 0.2
var current_speed_multiplier: float = 1.0

# Новые переменные для отслеживания комбо
var _was_attacking: bool = false
var _attack_cooldown: float = 0.0
const ATTACK_COOLDOWN_TIME: float = 0.3  # Задержка после атаки перед новым решением


func setup(actor_node: Node2D) -> void:
	actor = actor_node
	perception = actor.get_node_or_null("AIPerception")
	brain = actor.get_node_or_null("AIBrain")
	combat_component = actor.get_node_or_null("ActorCombatComponent")
	
	if perception and brain and combat_component:
		brain.setup(actor, perception, combat_component)


func set_active(active: bool) -> void:
	is_active = active
	set_process(active)
	
	if not active:
		combat_component.set_desired_move(Vector2.ZERO)
		_was_attacking = false
		_attack_cooldown = 0.0


func _process(delta: float) -> void:
	if not is_active or not brain or not combat_component:
		return
	
	var fsm = combat_component.get_fsm()
	if not fsm:
		return
	
	_tick_timer -= delta
	if _tick_timer > 0:
		return
	_tick_timer = TICK_INTERVAL
	
	var current_state = fsm.get_current_state_name()
	
	# Обновляем кулдаун после атаки
	if _attack_cooldown > 0:
		_attack_cooldown -= TICK_INTERVAL
	
	# Отслеживаем, был ли NPC в атаке
	if current_state == "Attack":
		_was_attacking = true
		combat_component.set_desired_move(Vector2.ZERO)
		return
	
	# Если только что вышли из атаки — даём кулдаун
	if _was_attacking:
		_was_attacking = false
		_attack_cooldown = ATTACK_COOLDOWN_TIME
		combat_component.set_desired_move(Vector2.ZERO)
		# Продолжаем комбо через FSM, не даём AI вмешиваться
		return
	
	# В кулдауне после атаки — не принимаем новых решений
	if _attack_cooldown > 0:
		combat_component.set_desired_move(Vector2.ZERO)
		return
	
	# Стандартная блокировка для Cast и Stun
	if current_state in ["Cast", "Stun"]:
		combat_component.set_desired_move(Vector2.ZERO)
		return
	
	var decision = brain.decide()
	_execute_decision(decision, fsm)


func _execute_decision(decision: Dictionary, fsm: EntityCombatFSM) -> void:
	var type = decision.get("type", AIBrain.CombatDecision.IDLE)
	
	match type:
		AIBrain.CombatDecision.IDLE:
			combat_component.set_desired_move(Vector2.ZERO)
			combat_component.ai_speed_multiplier = 1.0
		
		AIBrain.CombatDecision.WALK:
			var target = decision.get("target", Vector2.ZERO)
			var dir = (target - actor.global_position).normalized()
			combat_component.set_desired_move(dir)
			combat_component.ai_speed_multiplier = brain.walk_state_speed_multiplier
			fsm.send_command("walk", {"direction": dir})
		
		AIBrain.CombatDecision.ATTACK:
			combat_component.set_desired_move(Vector2.ZERO)
			combat_component.ai_speed_multiplier = 1.0
			fsm.send_command("attack")
		
		AIBrain.CombatDecision.CAST:
			combat_component.set_desired_move(Vector2.ZERO)
			combat_component.ai_speed_multiplier = 1.0
			
			var slot = decision.get("slot", 0)
			var target = decision.get("target", Vector2.ZERO)
			
			if not combat_component.ability_component:
				return
			
			var ability = combat_component.ability_component.get_ability_in_slot(slot)
			if not ability:
				return
			
			fsm.send_command("cast", {
				"slot_index": slot,
				"target_position": target,
				"ability": ability
			})
