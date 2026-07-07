class_name BlockState extends CombatState


# Блок: вход по block_start, выход по block_end или при нехватке стамины.
# Стамина тратится за каждый полученный удар, урон снижается.
# CombatComponent обрабатывает получение урона и трату стамины.

var is_blocking: bool = false
var _is_ending: bool = false

func enter() -> void:
	super.enter()
	is_blocking = true
	set_battle_velocity(Vector2.ZERO)

	# Анимация блока
	EventBus.Animations.requested.emit(entity, "block", 0)  # 0 = loop

	# Сигнал о начале блока
	EventBus.Combat.block.started.emit()



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

func _has_stamina_for_block() -> bool:
	if not combat_component or not combat_component.stamina_component:
		return true
	var min_stamina = combat_config.block_base_stamina_cost if combat_config else 5
	return combat_component.stamina_component.get_current() >= min_stamina

func _break_block() -> void:
	"""Блок сломан (не хватило выносливости)"""
	if not is_blocking:
		return
		
	is_blocking = false
	EventBus.Combat.block.broken.emit()
	transition_requested.emit("Stun")  # Оглушение при сломанном блоке

func _end_block() -> void:
	if _is_ending:
		return
	_is_ending = true
	is_blocking = false
	EventBus.Combat.block.ended.emit()
	transition_requested.emit("Idle")

func exit() -> void:
	super.exit()
	is_blocking = false
	_is_ending = false
	set_battle_velocity(Vector2.ZERO)

func can_exit() -> bool:
	return true

func get_allowed_transitions() -> Array[String]:
	return ["Idle", "Stun"]
