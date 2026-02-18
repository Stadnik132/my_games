class_name PlayerCombatComponent extends Node

@export_category("Параметры боя")
@export var attack_combo_damage: Array[float] = [1.0, 1.2, 1.5, 2.0]
@export var attack_combo_window: float = 1.2
@export var attack_duration: float = 0.8
@export var cancel_window_start: float = 0.1
@export var dodge_distance: float = 200.0
@export var dodge_duration: float = 0.3
@export var dodge_collider_radius: float = 15.0
@export var attack_idle_inside_duration: float = 3.0

@onready var player_body: CharacterBody2D = get_parent()
@onready var player_data: PlayerData = PlayerManager.player_data
@onready var fsm: PlayerCombatFSM = $PlayerCombatFSM
@onready var ability_component: AbilityComponent = $AbilityComponent

func _ready() -> void:
	fsm.setup(player_body, player_data, self)
	# Отключаем FSM, что бы не двоилась физика при старте игры.
	fsm.set_process(false)
	fsm.set_physics_process(false)
	
	_setup_event_bus_connections()
	_setup_hurtbox()

func get_attack_params() -> Dictionary:
	return {
		"combo_damage": attack_combo_damage,
		"combo_window": attack_combo_window,
		"attack_duration": attack_duration,
		"cancel_window_start": cancel_window_start,
		"base_damage": player_data.base_attack_damage,
		"max_combo_steps": attack_combo_damage.size()
	}

func get_dodge_params() -> Dictionary:
	return {
		"distance": dodge_distance,
		"duration": dodge_duration,
		"collider_radius": dodge_collider_radius,
		"stamina_cost": player_data.dodge_stamina_cost
	}

func _setup_hurtbox() -> void:
	var h = player_body.get_node_or_null("Hurtbox")
	if h and h.has_signal("damage_taken"):
		h.damage_taken.connect(_on_hurtbox_damage)

func _on_hurtbox_damage(damage_data: DamageData, source: Node) -> void:
	var was_blocked = fsm.get_current_state_name() == "Block"
	if was_blocked and player_data:
		var reduced = player_data.calculate_blocked_damage(damage_data.amount)
		var stamina_cost = damage_data.amount - reduced
		if stamina_cost > 0:
			player_data.use_stamina(stamina_cost)
	PlayerManager.apply_damage_data(damage_data, source, was_blocked)
	fsm.request_stun()

func _setup_event_bus_connections() -> void:
	EventBus.Combat.basic_attack_requested.connect(_on_attack)
	EventBus.Combat.dodge_requested.connect(_on_dodge)
	EventBus.Combat.block_started.connect(_on_block_start)
	EventBus.Combat.block_ended.connect(_on_block_end)
	EventBus.Combat.ability_slot_pressed.connect(_on_ability_slot_pressed)
	EventBus.Combat.aiming_cancelled.connect(_on_ability_target_cancelled)
	EventBus.Game.state_changed.connect(_on_game_state_changed)

func _on_game_state_changed(new_state: int, old_state: int) -> void:
	var is_battle = (new_state == 2)
	
	if is_battle:
		fsm.set_process(true)
		fsm.set_physics_process(true)
	else:
		fsm.change_state("Idle")
		fsm.set_process(false)
		fsm.set_physics_process(false)

func _on_attack() -> void:
	fsm.send_command("attack")

func _on_dodge(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		EventBus.Combat.dodge_failed.emit("no_direction")
		return
	
	if not player_data.use_stamina(player_data.dodge_stamina_cost):
		EventBus.Combat.dodge_failed.emit("insufficient_stamina")
		return
	
	fsm.send_command("dodge", {"direction": direction})

func _on_block_start() -> void:
	fsm.send_command("block_start")

func _on_block_end() -> void:
	fsm.send_command("block_end")

func _on_ability_slot_pressed(slot_index: int) -> void:
	var ability = ability_component.get_ability_in_slot(slot_index)
	if not ability:
		return
	
	if not ability_component.can_cast_ability(slot_index):
		return
	
	var current_state = fsm.get_current_state_name()
	if current_state in ["Idle", "Walk", "Attack"]:
		fsm.send_command("ability_selected", {
			"ability": ability,
			"slot_index": slot_index
		})
		fsm.send_command("aiming_start")

func _on_ability_target_cancelled() -> void:
	fsm.send_command("aim_cancel")
