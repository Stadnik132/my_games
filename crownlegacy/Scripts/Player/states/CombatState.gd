# CombatState.gd
class_name CombatState extends Node

signal transition_requested(state_name: StringName)

# Контекст (устанавливается FSM)
var player: CharacterBody2D
var player_data: PlayerData
var combat_component: Node
var fsm: Node

# Параметры (устанавливаются из компонента)
var attack_params: Dictionary
var dodge_params: Dictionary

func setup_params():
	if combat_component:
		attack_params = combat_component.get_attack_params()
		dodge_params = combat_component.get_dodge_params()

# Виртуальные методы
func enter(): pass
func exit(): pass
func process(delta: float): pass
func physics_process(delta: float): pass
func can_exit() -> bool: return true
func get_allowed_transitions() -> Array[StringName]: return []

# Команды от компонента (вместо обработки сырого ввода)
func handle_command(command: String, data: Dictionary = {}): pass

func lock_movement():
	if player and player.has_method("lock_movement"):
		player.lock_movement()

func unlock_movement():
	if player and player.has_method("unlock_movement"):
		player.unlock_movement()
