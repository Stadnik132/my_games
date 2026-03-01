class_name PlayerAimState extends CombatState

var ability: AbilityResource
var slot_index: int
var aiming_visual: BaseAimingVisual

func enter() -> void:
	super.enter()
	
	ability = fsm.current_ability
	slot_index = fsm.current_slot_index
	
	if not ability:
		print("PlayerAimState: нет способности в fsm.current_ability!")
		fsm.change_state("Idle")
		return
	
	aiming_visual = _create_aiming_visual()
	if aiming_visual:
		# Добавляем в дерево
		get_tree().current_scene.add_child(aiming_visual)
		
		# Устанавливаем позицию на игрока
		aiming_visual.global_position = entity.global_position
		
		# Настраиваем
		aiming_visual.setup(ability, entity)
		aiming_visual.confirmed.connect(_on_target_confirmed)
		aiming_visual.cancelled.connect(_on_target_cancelled)
	else:
		_confirm_immediate()
	
	# Блокируем движение игрока
	entity.movement_locked = true
	
	EventBus.Combat.ability.aiming_started.emit(slot_index)
	print("PlayerAimState: начато прицеливание для ", ability.ability_name)

func _create_aiming_visual() -> BaseAimingVisual:
	# Мгновенные способности и self-target не требуют прицеливания
	if ability.ability_type == AbilityResource.AbilityType.SELF_TARGET or \
	   ability.ability_type == AbilityResource.AbilityType.INSTANT:
		return null
	
	var visual_scene = ability.get_aiming_visual_scene()
	if not visual_scene:
		print("PlayerAimState: нет сцены визуала для ", ability.ability_name)
		return null
	
	var visual = visual_scene.instantiate()
	if visual is BaseAimingVisual:
		return visual
	else:
		visual.queue_free()
		return null

func _on_target_confirmed(target_data: Dictionary) -> void:
	print("=== PLAYER AIM CONFIRMED ===")
	
	if aiming_visual:
		aiming_visual.is_active = false
		aiming_visual.confirmed.disconnect(_on_target_confirmed)
		aiming_visual.cancelled.disconnect(_on_target_cancelled)
	
	fsm.send_command("cast", {
		"ability": ability,
		"slot_index": slot_index,
		"target_data": target_data
	})
	
	fsm.change_state("Cast")

func _on_target_cancelled() -> void:
	print("PlayerAimState: прицеливание отменено")
	
	if aiming_visual:
		aiming_visual.confirmed.disconnect(_on_target_confirmed)
		aiming_visual.cancelled.disconnect(_on_target_cancelled)
	
	fsm.change_state("Idle")

func _confirm_immediate() -> void:
	fsm.send_command("cast", {
		"ability": ability,
		"slot_index": slot_index,
		"target_data": {"type": "self"}
	})
	fsm.change_state("Cast")

func exit() -> void:
	print("PlayerAimState: exit")
	
	if aiming_visual:
		aiming_visual.queue_free()
		aiming_visual = null
	
	entity.movement_locked = false
	
	super.exit()

func handle_command(command: String, data: Dictionary = {}) -> void:
	match command:
		"cancel_aim":
			_on_target_cancelled()
		_:
			super.handle_command(command, data)

func get_allowed_transitions() -> Array[String]:
	return ["Cast", "Idle", "Stun"]
