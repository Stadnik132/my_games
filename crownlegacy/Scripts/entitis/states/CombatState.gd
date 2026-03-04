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

# CombatState.gd
func get_attack_direction() -> Vector2:
	
	# 1. Пробуем получить от entity
	if entity and entity.has_method("get_horizontal_facing_direction"):
		var dir = entity.get_horizontal_facing_direction()
		if dir != Vector2.ZERO:
			return dir
	
	# 2. Пробуем из последнего движения FSM
	if fsm and fsm.last_movement_direction.length() > 0:
		if abs(fsm.last_movement_direction.x) > 0:
			var dir = Vector2(sign(fsm.last_movement_direction.x), 0)
			return dir
	
	# 3. Пробуем из последнего уворота
	if fsm and fsm.last_dodge_direction.length() > 0:
		if abs(fsm.last_dodge_direction.x) > 0:
			var dir = Vector2(sign(fsm.last_dodge_direction.x), 0)
			return dir
	
	return Vector2.RIGHT
