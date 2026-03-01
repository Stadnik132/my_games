# ai_component.gd
class_name AIComponent extends Node
## Корневой компонент AI. Собирает всё вместе и управляет активацией.

# Ссылки на дочерние компоненты (их нужно будет назначить в инспекторе)
@export var perception: AIPerception
@export var brain: AIBrain
@export var fsm: ActorCombatFSM

# Ссылка на владельца
var actor: Actor

# Флаг активности (AI работает только когда актор в режиме HOSTILE)
var is_active: bool = false # рабочий флаг: включён ли AI прямо сейчас
var _is_setup: bool = false # технический флаг: был ли компонент уже инициализирован

func setup(p_actor: Actor) -> void:
	if _is_setup:
		return
	_is_setup = true
	actor = p_actor
	
	# Инициализируем все компоненты
	if perception:
		perception.setup(actor)
	
	if brain:
		brain.setup(actor, perception)
	
	if fsm:
		fsm.setup(actor, brain)
	
	# Подписываемся на смену режима актора
	actor.mode_changed.connect(_on_actor_mode_changed)
	
	# Подписываемся на получение урона (для стана)
	if actor.combat_component:
		# Предполагаем, что у ActorCombatComponent есть сигнал damage_taken
		# Если нет - добавим позже
		if actor.combat_component.has_signal("damage_taken"):
			actor.combat_component.damage_taken.connect(_on_damage_taken)

func _on_actor_mode_changed(new_mode: String, old_mode: String) -> void:
	is_active = (new_mode == Actor.MODE_BATTLE)
	
	if is_active and fsm:
		# При активации начинаем с состояния IDLE
		fsm.change_state(ActorCombatFSM.State.IDLE)

func _on_damage_taken(damage_data: DamageData, source: Node) -> void:
	if is_active and fsm:
		apply_stun(0.5)

func apply_stun(duration: float = 0.5) -> void:
	if not is_active or not fsm:
		return
	
	# Переключаемся в стан
	fsm.change_state(ActorCombatFSM.State.STUN)
	
	# Здесь можно передать длительность стана
	# Для этого нужно добавить параметр в StunState

func _process(delta: float) -> void:
	if not is_active or not actor or not actor.is_alive():
		return
	
	# Обновляем восприятие
	if perception:
		perception.update(delta)
	
	# Обновляем FSM
	if fsm:
		fsm.process(delta)

func _physics_process(delta: float) -> void:
	if not is_active or not actor or not actor.is_alive():
		return
	
	if fsm:
		fsm.physics_process(delta)

func set_active(active: bool) -> void:
	is_active = active
	print_debug("AIComponent set_active: ", active, " fsm=", fsm != null)
	if is_active and fsm:
		# Добавь проверку, что FSM уже инициализирован
		if fsm.actor != null:
			fsm.change_state(ActorCombatFSM.State.IDLE)
		else:
			print_debug("AIComponent: FSM ещё не инициализирован, откладываю переход")
