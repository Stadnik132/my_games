class_name BlockState extends CombatState

# Блок: вход по block_start, выход по block_end или при нехватке стамины.
# Стамина тратится за каждый полученный удар, урон снижается.

var is_blocking: bool = false

func enter() -> void:
	super.enter()
	is_blocking = true
	set_battle_velocity(Vector2.ZERO)
	
	# Анимация блока
	EventBus.Animations.requested.emit(entity, "block", 0)  # 0 = loop
	
	# Сигнал о начале блока
	EventBus.Combat.block.started.emit()
	
	print_debug("BlockState: блок активирован")

func physics_process(_delta: float) -> void:
	# Во время блока не двигаемся
	set_battle_velocity(Vector2.ZERO)
	apply_movement()

func process(_delta: float) -> void:
	# Проверяем, хватает ли выносливости для продолжения блока
	if not _has_stamina_for_block():
		_break_block()
		return
	
	# Сигнал "блок активен" каждый кадр (для UI или звука)
	EventBus.Combat.block.active.emit()

func handle_command(command: String, data: Dictionary = {}) -> void:
	match command:
		"block_end":
			_end_block()
		"damage_blocked":  # Команда от CombatComponent при получении урона в блоке
			_handle_blocked_damage(data)

func _handle_blocked_damage(data: Dictionary) -> void:
	"""Обработка заблокированного урона"""
	if not is_blocking:
		return
	
	var damage_after_block = data.get("damage_after_block", 0)
	var stamina_cost = data.get("stamina_cost", 0)
	
	# Тратим выносливость
	if stamina_cost > 0:
		var stamina_comp = entity.get_node_or_null("StaminaComponent") as ResourceComponent
		if stamina_comp:
			stamina_comp.use(stamina_cost)
	
	# Сообщаем о заблокированном уроне
	EventBus.Combat.block.reduced_damage.emit(damage_after_block)
	
	# Проверяем, не сломался ли блок
	if not _has_stamina_for_block():
		_break_block()

func _has_stamina_for_block() -> bool:
	"""Проверяет, достаточно ли выносливости для продолжения блока"""
	var stamina_comp = entity.get_node_or_null("StaminaComponent") as ResourceComponent
	if not stamina_comp:
		return true  # если нет стамины, считаем что блок всегда возможен
	
	# Минимальный порог для удержания блока
	return stamina_comp.get_current() >= 5

func _break_block() -> void:
	"""Блок сломан (не хватило выносливости)"""
	is_blocking = false
	EventBus.Combat.block.broken.emit()
	transition_requested.emit("Stun")  # Оглушение при сломанном блоке

func _end_block() -> void:
	"""Нормальное завершение блока"""
	is_blocking = false
	EventBus.Combat.block.ended.emit()
	transition_requested.emit("Idle")

func exit() -> void:
	super.exit()
	is_blocking = false
	set_battle_velocity(Vector2.ZERO)

func can_exit() -> bool:
	return true

func get_allowed_transitions() -> Array[String]:
	return ["Idle", "Stun"]
