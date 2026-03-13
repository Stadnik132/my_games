class_name CastState extends CombatState

var ability: AbilityResource
var slot_index: int
var cast_timer: float = 0.0
var target_position: Vector2 = Vector2.ZERO
var is_channeling: bool = false

func enter() -> void:

	super.enter()

	# Получаем данные из FSM
	slot_index = fsm.current_slot_index
	ability = fsm.current_ability
	target_position = fsm.cast_target_position
	
	if not ability or slot_index < 0:
		print_debug("CastState: нет способности или индекса слота")
		transition_requested.emit("Idle")
		return
	
	# Проверяем возможность каста
	var ability_comp = combat_component.ability_component
	if not ability_comp or not ability_comp.can_cast_ability(slot_index):
		print_debug("CastState: нельзя использовать способность")
		transition_requested.emit("Idle")
		return
	
	# Тратим ресурсы и запускаем кулдаун (делается в cast_ability, но мы вызовем позже)
	cast_timer = ability.cast_time
	is_channeling = ability.channeled
	
	# Анимация каста
	if ability.cast_animation != "":
		EventBus.Animations.requested.emit(entity, ability.cast_animation, ability.cast_time)
	
	# Если каст мгновенный, сразу применяем эффект
	if ability.cast_time <= 0:
		_finish_cast()
	else:
		print_debug("CastState: начат каст ", ability.ability_name, " на ", ability.cast_time, " сек")

func process(delta: float) -> void:
	super.process(delta)
	
	if cast_timer <= 0:
		return
	
	cast_timer -= delta
	if cast_timer <= 0:
		_finish_cast()

func physics_process(_delta: float) -> void:
	# Во время каста не двигаемся
	set_battle_velocity(Vector2.ZERO)
	apply_movement()

func _finish_cast() -> void:
	# Применяем способность
	var ability_comp = combat_component.ability_component
	if ability_comp:
		# Используем существующий метод cast_ability
		ability_comp.cast_ability(slot_index, target_position)
	
	print_debug("CastState: каст завершён")
	transition_requested.emit("Idle")

func handle_command(command: String, data: Dictionary = {}) -> void:
	match command:
		"stun":
			# Можно прервать каст станом
			if not is_channeling:  # Каналируемые способности нельзя прервать?
				transition_requested.emit("Stun")

func get_allowed_transitions() -> Array[String]:
	return ["Idle", "Stun"]

func can_exit() -> bool:
	return cast_timer <= 0 or not is_channeling
