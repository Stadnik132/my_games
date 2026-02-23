# enemy_combat_state.gd
class_name EnemyCombatState extends Node
## Базовый класс для всех состояний врага в бою.
## Содержит общие методы и ссылки на FSM, актора и мозг.

# Сигнал для запроса смены состояния
signal transition_requested(state_name: String)

# Ссылки на основные компоненты
var fsm: EnemyCombatFSM      # Конечный автомат, которому принадлежит это состояние
var actor: Actor             # Актор, которым управляем
var brain: AIBrain           # Мозг, принимающий решения

func setup(p_fsm: EnemyCombatFSM, p_actor: Actor, p_brain: AIBrain) -> void:
	fsm = p_fsm
	actor = p_actor
	brain = p_brain

func enter() -> void:
	pass

func exit() -> void:
	pass

func process(delta: float) -> void:
	pass

func physics_process(delta: float) -> void:
	pass
