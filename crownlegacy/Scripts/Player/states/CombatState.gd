class_name CombatState extends Node

signal transition_requested(state_name: String)

# Контекст (устанавливается FSM при setup)
var player: CharacterBody2D
var player_data: PlayerData
var combat_component: Node
var fsm: PlayerCombatFSM
var command_data: Dictionary = {}

# Параметры (из компонента)
var attack_params: Dictionary
var dodge_params: Dictionary

func setup_params() -> void:
	if combat_component and combat_component.has_method("get_attack_params"):
		attack_params = combat_component.get_attack_params()
	if combat_component and combat_component.has_method("get_dodge_params"):
		dodge_params = combat_component.get_dodge_params()

# --- Виртуальные методы ---
func enter() -> void: pass
func exit() -> void: pass
func process(_delta: float) -> void: pass
func physics_process(_delta: float) -> void: pass

func can_exit() -> bool:
	return true

func get_allowed_transitions() -> Array[String]:
	return []

func handle_command(command: String, data: Dictionary = {}) -> void:
	command_data = data

# --- Движение (для состояний боя) ---
func set_battle_velocity(v: Vector2) -> void:
	if player:
		player.velocity = v

func apply_movement() -> void:
	if player:
		player.move_and_slide()
