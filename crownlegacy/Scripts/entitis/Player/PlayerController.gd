extends Node
class_name PlayerController

# ==================== ССЫЛКИ ====================
@onready var player: Player = get_parent()

var _was_blocking: bool = false

# ==================== ВВОД ====================
func _input(event: InputEvent) -> void:
	if _handle_global_input(event):
		return
	
	if player._in_combat_mode:
		_handle_combat_input(event)

func _handle_global_input(event: InputEvent) -> bool:
	# Взаимодействие
	if event.is_action_pressed("interact") and not player.interaction_locked:
		_handle_interaction()
		get_viewport().set_input_as_handled()
		return true
	
	# Меню
	if event.is_action_pressed("ui_cancel") and _can_open_menu():
		EventBus.Game.menu_requested.emit()
		get_viewport().set_input_as_handled()
		return true
	
	return false

func _handle_combat_input(event: InputEvent) -> void:
	if not player.combat_component:
		return
	
	if player.combat_component.get_fsm().get_current_state_name() == "Stun":
		return
	
	var is_aiming = player.combat_component.get_fsm().get_current_state_name() == "Aiming"
	
	# ЛКМ
	if event.is_action_pressed("basic_attack"):
		if is_aiming:
			_confirm_ability_cast()
		else:
			EventBus.Combat.attack.basic_requested.emit()
		get_viewport().set_input_as_handled()
		return
	
	# Блок
	if event.is_action_pressed("block"):
		EventBus.Combat.block.started.emit()
		get_viewport().set_input_as_handled()
		return
	
	if event.is_action_released("block"):
		EventBus.Combat.block.ended.emit()
		get_viewport().set_input_as_handled()
		return
	
	# Уворот
	if event.is_action_pressed("dodge"):
		var dodge_dir = _get_input_vector()
		if dodge_dir == Vector2.ZERO:
			dodge_dir = player.last_movement_direction
		EventBus.Combat.dodge.requested.emit(dodge_dir)
		get_viewport().set_input_as_handled()
		return
	
	# Способности 1-4
	for i in range(1, 5):
		if event.is_action_pressed("ability_" + str(i)):
			print("=== ABILITY KEY PRESSED: ", i)
			EventBus.Combat.ability.slot_pressed.emit(i-1)
			get_viewport().set_input_as_handled()
			return

func _handle_interaction() -> void:
	print_debug("PlayerController: запрос взаимодействия")
	EventBus.Actors.interaction_requested.emit()

func _confirm_ability_cast() -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	var camera = get_viewport().get_camera_2d()
	var global_mouse_pos = camera.global_position + (mouse_pos - get_viewport().size * 0.5) / camera.zoom
	EventBus.Combat.ability.target_confirmed.emit(global_mouse_pos)

func _get_input_vector() -> Vector2:
	var input = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	return input.normalized() if input.length() > 0 else Vector2.ZERO

func _can_open_menu() -> bool:
	"""Меню доступно в WORLD и в BATTLE"""
	return player._can_move_in_world or player._in_combat_mode
