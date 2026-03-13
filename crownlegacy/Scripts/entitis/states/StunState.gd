class_name StunState extends CombatState

# Стан: при получении урона (из любого состояния кроме Cast). Сущность не может ничего делать.
# Выход в Idle по истечении длительности.

@export var stun_duration: float = 0.5
var stun_timer: float = 0.0
var _stun_tween: Tween

func enter() -> void:
	super.enter()
	
	# Отключаем движение
	set_battle_velocity(Vector2.ZERO)
	
	# Эффект стана (белый цвет)
	_apply_stun_effect()
	
	# Запускаем таймер стана
	stun_timer = combat_config.stun_duration
	
	# Анимация стана (если есть)
	EventBus.Animations.requested.emit(entity, "stun", stun_timer)
	
	# Сигнал о начале стана
	EventBus.Combat.entity_stunned.emit(entity, true)

func process(delta: float) -> void:
	super.process(delta)
	stun_timer -= delta
	if stun_timer <= 0.0:
		transition_requested.emit("Idle")

func physics_process(_delta: float) -> void:
	# В стане не двигаемся
	set_battle_velocity(Vector2.ZERO)
	apply_movement()

func handle_command(_command: String, _data: Dictionary = {}) -> void:
	# В стане игнорируем все команды
	pass

func exit() -> void:
	# Возвращаем нормальный цвет
	_clear_stun_effect()
	EventBus.Combat.entity_stunned.emit(entity, false)
	super.exit()

func can_exit() -> bool:
	return stun_timer <= 0.0

func get_allowed_transitions() -> Array[String]:
	return ["Idle"]

# ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ====================
func _apply_stun_effect() -> void:
	var sprite = entity.get_sprite()
	
	if not sprite:
		return
	
	if _stun_tween and _stun_tween.is_running():
		_stun_tween.kill()
	
	_stun_tween = create_tween()
	_stun_tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func _clear_stun_effect() -> void:
	var sprite = entity.get_sprite()
	if not sprite:
		return
	
	if _stun_tween:
		_stun_tween.kill()
	sprite.modulate = Color.WHITE
