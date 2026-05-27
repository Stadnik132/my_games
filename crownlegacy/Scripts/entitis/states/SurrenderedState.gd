class_name SurrenderedState extends CombatState

var _interact_range: float = 50.0
var _player_nearby: bool = false
var _input_processed: bool = false
var _prompt_label: Label = null

func enter() -> void:
	super.enter()
	set_battle_velocity(Vector2.ZERO)
	EventBus.Animations.requested.emit(entity, "stun", 0)
	EventBus.Combat.entity_stunned.emit(entity, true)

	entity.movement_locked = true
	if entity.has_method("lock_interaction"):
		entity.lock_interaction(false)
	
	_create_prompt()

func process(_delta: float) -> void:
	_check_player_proximity()
	if _player_nearby and not _input_processed:
		_process_spare_execute_input()

func physics_process(_delta: float) -> void:
	set_battle_velocity(Vector2.ZERO)
	apply_movement()

func _check_player_proximity() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var dist = entity.global_position.distance_to(player.global_position)
	_player_nearby = dist <= _interact_range
	_update_prompt_visibility()

func _create_prompt() -> void:
	if not is_instance_valid(entity):
		return
	_prompt_label = Label.new()
	_prompt_label.text = "[Q] Spare   [E] Execute"
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	_prompt_label.add_theme_constant_override("shadow_outline_size", 2)
	_prompt_label.add_theme_font_size_override("font_size", 14)
	_prompt_label.position = Vector2(-80, -60)
	_prompt_label.custom_minimum_size = Vector2(160, 20)
	_prompt_label.visible = false
	entity.add_child(_prompt_label)

func _update_prompt_visibility() -> void:
	if _prompt_label:
		_prompt_label.visible = _player_nearby
		_input_processed = false

func _process_spare_execute_input() -> void:
	if Input.is_action_just_pressed("spare"):
		_input_processed = true
		_remove_prompt()
		handle_command("spare")
	elif Input.is_action_just_pressed("execute"):
		_input_processed = true
		_remove_prompt()
		handle_command("execute")

func is_player_nearby() -> bool:
	return _player_nearby

func handle_command(command: String, data: Dictionary = {}) -> void:
	match command:
		"spare":
			EventBus.Combat.decision.enemy_spared.emit(entity)
			transition_requested.emit("Idle")
		"execute":
			if entity.health_component:
				entity.health_component.take_damage(9999, 2, null, false)
			transition_requested.emit("Idle")

func exit() -> void:
	super.exit()
	_remove_prompt()
	entity.movement_locked = false
	EventBus.Combat.entity_stunned.emit(entity, false)

func _remove_prompt() -> void:
	if _prompt_label and is_instance_valid(_prompt_label):
		_prompt_label.queue_free()
	_prompt_label = null

func get_allowed_transitions() -> Array[String]:
	return ["Idle"]
