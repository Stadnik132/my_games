extends Node
class_name AIController

# ==================== ЭКСПОРТ ====================
# move_speed больше не нужен - скорость берется из combat_config

# ==================== ССЫЛКИ ====================
var actor: Actor
var brain: AIBrain
var perception: AIPerception
var combat_component: ActorCombatComponent
var is_active: bool = false

# Тикрейт для оптимизации
var _tick_timer: float = 0.0
const TICK_INTERVAL: float = 0.2  # принимаем решение 5 раз в секунду

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func setup(actor_node: Actor) -> void:
	actor = actor_node
	perception = actor.get_node_or_null("AIPerception")
	brain = actor.get_node_or_null("AIBrain")
	combat_component = actor.get_node_or_null("ActorCombatComponent")
	
	if perception and brain and combat_component:
		brain.setup(actor, perception, combat_component)
		print_debug("AIController: настроен для ", actor.name)

func set_active(active: bool) -> void:
	"""Включает/выключает AI (вызывается из CombatComponent)"""
	is_active = active
	set_process(active)
	# НЕ включаем physics_process - физикой управляет FSM
	
	if not active:
		# Сбрасываем желание двигаться при выходе из боя
		combat_component.set_desired_move(Vector2.ZERO)

func _process(delta: float) -> void:
	if not is_active or not brain or not combat_component:
		return
	
	var fsm = combat_component.get_fsm()
	if not fsm:
		return
	
	# Тикрейт - не спамим решения каждый кадр
	_tick_timer -= delta
	if _tick_timer > 0:
		return
	_tick_timer = TICK_INTERVAL
	
	# Проверяем текущее состояние FSM
	var current_state = fsm.get_current_state_name()
	
	# Не принимаем новые решения, если мы в середине действия
	if current_state in ["Attack", "Cast", "Stun"]:
		# В этих состояниях новые команды не нужны
		# Но движение всё равно сбрасываем
		combat_component.set_desired_move(Vector2.ZERO)
		return
	
	var decision = brain.decide()
	_execute_decision(decision, fsm)

func _execute_decision(decision: Dictionary, fsm: EntityCombatFSM) -> void:
	var type = decision.get("type", AIBrain.CombatDecision.IDLE)
	
	match type:
		AIBrain.CombatDecision.IDLE:
			# Убираем желание двигаться
			combat_component.set_desired_move(Vector2.ZERO)
		
		AIBrain.CombatDecision.WALK:
			var target = decision.get("target", Vector2.ZERO)
			var dir = (target - actor.global_position).normalized()
			
			# Устанавливаем желаемое направление для движения
			combat_component.set_desired_move(dir)
			
			# Сообщаем FSM о движении (для переключения в Walk)
			fsm.send_command("walk", {"direction": dir})
		
		AIBrain.CombatDecision.ATTACK:
			# Останавливаем движение перед атакой
			combat_component.set_desired_move(Vector2.ZERO)
			
			# Отправляем команду атаки (обработается в состоянии)
			fsm.send_command("attack")
		
		AIBrain.CombatDecision.CAST:
			print_debug("AIController: ПОЛУЧЕНА КОМАНДА CAST, слот ", decision.get("slot", 0))
			# Останавливаем движение перед кастом
			combat_component.set_desired_move(Vector2.ZERO)
			
			var slot = decision.get("slot", 0)
			var target = decision.get("target", Vector2.ZERO)
			
			# Проверяем наличие способности
			if not combat_component.ability_component:
				return
			
			var ability = combat_component.ability_component.get_ability_in_slot(slot)
			if not ability:
				return
			
			# Отправляем команду каста с полными данными
			fsm.send_command("cast", {
				"slot_index": slot,
				"target_position": target,
				"ability": ability
			})
