class_name StunState extends CombatState

# Общий для Player и остальных NPC типа Actor/Enemy и т.д

# Стан: при получении урона (из любого состояния кроме Cast). Сущность не может ничего делать.
# Выход в Idle по истечении длительности.

var stun_timer: float = 0.0

# Параметры отбрасывания
var knockback_direction: Vector2 = Vector2.ZERO
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0
var knockback_duration: float = 0.0
var has_knockback: bool = false

func enter() -> void:
	super.enter()

	# Отключаем движение
	set_battle_velocity(Vector2.ZERO)

	# Инициализация отбрасывания (если есть)
	has_knockback = false
	knockback_timer = 0.0
	knockback_duration = combat_config.knockback_duration if combat_config else 0.25

	if entity.has_method("apply_stun_effect"):
		entity.apply_stun_effect()

	# Запускаем таймер стана
	stun_timer = combat_config.stun_duration

	# Анимация стана (если есть)
	EventBus.Animations.requested.emit(entity, "stun", stun_timer)

	# Сигнал о начале стана
	EventBus.Combat.entity_stunned.emit(entity, true)

# ==================== ПУБЛИЧНЫЕ МЕТОДЫ ====================
func set_knockback(direction: Vector2, distance: float) -> void:
	"""Устанавливает отбрасывание при входе в стан"""
	if distance <= 0.0:
		return
	
	has_knockback = true
	knockback_direction = direction.normalized()
	knockback_duration = combat_config.knockback_duration if combat_config else 0.25
	var knockback_speed = distance / knockback_duration
	knockback_velocity = knockback_direction * knockback_speed
	knockback_timer = 0.0

func process(delta: float) -> void:
	super.process(delta)
	stun_timer -= delta
	if stun_timer <= 0.0:
		transition_requested.emit("Idle")

func physics_process(delta: float) -> void:
	# Обрабатываем отбрасывание
	if has_knockback:
		knockback_timer += delta
		
		# Плавно замедляем отбрасывание
		var decel_progress = clampf(knockback_timer / knockback_duration, 0.0, 1.0)
		
		if decel_progress >= 1.0:
			# Отбрасывание завершено
			has_knockback = false
			set_battle_velocity(Vector2.ZERO)
		else:
			# Плавное замедление (квадратичное для естественности)
			var decel_factor = 1.0 - decel_progress * decel_progress
			var current_velocity = knockback_velocity * decel_factor
			set_battle_velocity(current_velocity)
	else:
		# В стане не двигаемся (после завершения отбрасывания)
		set_battle_velocity(Vector2.ZERO)
	
	apply_movement()

func handle_command(_command: String, _data: Dictionary = {}) -> void:
	# В стане игнорируем все команды
	pass

func exit() -> void:
	if entity.has_method("clear_stun_effect"):
		entity.clear_stun_effect()
	EventBus.Combat.entity_stunned.emit(entity, false)
	super.exit()

func can_exit() -> bool:
	return stun_timer <= 0.0

func get_allowed_transitions() -> Array[String]:
	return ["Idle"]
