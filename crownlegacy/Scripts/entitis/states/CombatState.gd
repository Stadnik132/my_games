class_name CombatState extends Node

signal transition_requested(state_name: String)

# Контекст (теперь общий)
var entity: Entity
var stats_provider: ProgressionComponent
var combat_component: CombatComponent
var combat_config: CombatConfig
var fsm: EntityCombatFSM

# Данные команды (заполняются при enter через FSM)
var command_data: Dictionary = {}

# Параметры (заполняются в setup_params)
var attack_params: Dictionary = {}
var dodge_params: Dictionary = {}

func setup_params() -> void:
	"""Виртуальный метод для инициализации параметров"""
	if combat_component:
		attack_params = combat_component.get_attack_params()
		dodge_params = combat_component.get_dodge_params()

# Виртуальные методы
func enter() -> void:
	pass

func exit() -> void:
	pass

func process(delta: float) -> void:
	pass

func physics_process(delta: float) -> void:
	pass

func can_exit() -> bool:
	return true

func get_allowed_transitions() -> Array[String]:
	return []

func handle_command(command: String, data: Dictionary = {}) -> void:
	pass

# Вспомогательные методы для состояний
func set_battle_velocity(v: Vector2) -> void:
	if entity is CharacterBody2D:
		entity.velocity = v

func apply_movement() -> void:
	if entity is CharacterBody2D:
		entity.move_and_slide()
