class_name EntityCombatFSM extends Node

signal state_changed(old_state: String, new_state: String)

var states: Dictionary = {}
var current_state: CombatState = null

var attack_combo_step: int = 0
var last_dodge_direction: Vector2 = Vector2.DOWN
var last_movement_direction: Vector2 = Vector2.DOWN

var entity: Entity
var stats_provider: ProgressionComponent
var combat_component: CombatComponent
var combat_config: CombatConfig

var current_slot_index: int = -1
var current_ability: AbilityResource = null
var cast_target_position: Vector2 = Vector2.ZERO
var cast_target_data: Dictionary = {}

func setup(p_entity: Entity, p_stats: ProgressionComponent, p_component: CombatComponent, p_config: CombatConfig) -> void:
	entity = p_entity
	stats_provider = p_stats
	combat_component = p_component
	combat_config = p_config

	for child in get_children():
		if child is CombatState:
			var state_name = child.name.replace("State", "")
			states[state_name] = child
			child.entity = entity
			child.stats_provider = p_stats
			child.combat_component = p_component
			child.combat_config = p_config
			child.fsm = self
			child.setup_params()

			if child.transition_requested.is_connected(_on_transition_requested):
				child.transition_requested.disconnect(_on_transition_requested)
			child.transition_requested.connect(_on_transition_requested)

	change_state("Idle")

func change_state(state_name: String) -> void:
	if not states.has(state_name):
		return

	var old_name = get_current_state_name()

	if current_state and not current_state.can_exit():
		return

	if current_state and not state_name in current_state.get_allowed_transitions():
		return

	if current_state:
		current_state.exit()

	current_state = states[state_name]
	current_state.enter()

	state_changed.emit(old_name, state_name)

func send_command(command: String, data: Dictionary = {}) -> void:
	match command:
		"walk":
			if data.has("direction"):
				last_movement_direction = data["direction"]
				if get_current_state_name() == "Idle":
					change_state("Walk")

		"attack":
			pass

		"cast":
			if data.has("slot_index"):
				current_slot_index = data["slot_index"]
			if data.has("ability"):
				current_ability = data["ability"]
			if data.has("target_position"):
				cast_target_position = data["target_position"]
			if data.has("target_data"):
				cast_target_data = data["target_data"]

			if not current_ability and current_slot_index >= 0:
				if combat_component and combat_component.ability_component:
					current_ability = combat_component.ability_component.get_ability_in_slot(current_slot_index)

			if get_current_state_name() in ["Idle", "Walk"]:
				change_state("Cast")

		"ability_selected":
			if data.has("slot_index"):
				current_slot_index = data.slot_index
			if data.has("ability"):
				current_ability = data.ability

		"aim_cancel":
			cast_target_position = Vector2.ZERO
			cast_target_data = {}
			current_slot_index = -1
			current_ability = null

	if current_state:
		current_state.handle_command(command, data)

func request_stun(knockback_direction: Vector2 = Vector2.ZERO, knockback_distance: float = 0.0) -> void:

	if get_current_state_name() == "Stun":
		return

	if get_current_state_name() == "Cast":
		return

	if not states.has("Stun"):
		return

	var old_name = get_current_state_name()
	if current_state:
		current_state.exit()

	current_state = states["Stun"]
	current_state.enter()

	if current_state.has_method("set_knockback") and knockback_distance > 0.0:
		current_state.set_knockback(knockback_direction, knockback_distance)

	state_changed.emit(old_name, "Stun")

func _on_transition_requested(state_name: String) -> void:
	change_state(state_name)

func _process(delta: float) -> void:
	if current_state:
		current_state.process(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_process(delta)

func get_current_state_name() -> String:
	if current_state:
		return current_state.name.replace("State", "")
	return "None"

func is_in_state(state_name: String) -> bool:
	return get_current_state_name() == state_name

func get_state_object(state_name: String) -> CombatState:
	return states.get(state_name)

func update_facing_direction(direction: Vector2) -> void:
	if abs(direction.x) > 0:
		last_movement_direction = direction
		if entity and entity.has_method("set_last_horizontal_direction"):
			entity.set_last_horizontal_direction(Vector2(sign(direction.x), 0))
