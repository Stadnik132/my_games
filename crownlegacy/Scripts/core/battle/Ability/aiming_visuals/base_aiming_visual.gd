# aiming_visuals/base_aiming_visual.gd
class_name BaseAimingVisual extends Node2D
## Базовый класс для всех визуалов прицеливания
## 
## Сигналы:
## - confirmed(target_data: Dictionary) - когда игрок подтвердил цель (ЛКМ)
## - cancelled() - когда игрок отменил прицеливание (ПКМ)

signal confirmed(target_data: Dictionary)
signal cancelled()

var ability: AbilityResource
var caster: Node2D
var is_active: bool = true

func setup(p_ability: AbilityResource, p_caster: Node2D) -> void:
	"""Инициализация визуала перед использованием"""
	ability = p_ability
	caster = p_caster
	_ready_setup()

func _ready_setup() -> void:
	"""Виртуальный метод для инициализации в наследниках"""
	pass

func _input(event: InputEvent) -> void:
	if not is_active:
		return
	
	if event.is_action_pressed("basic_attack"):
		_confirm()
		get_viewport().set_input_as_handled()  # Важно!
	elif event.is_action_pressed("block"):
		cancel()
		get_viewport().set_input_as_handled()  # Важно!

func _confirm() -> void:
	"""Подтверждение цели (ЛКМ)"""
	is_active = false
	confirmed.emit(_get_target_data())

func cancel() -> void:
	if not is_active:
		return
	is_active = false
	cancelled.emit()
	queue_free()

func _get_target_data() -> Dictionary:
	"""Возвращает данные для каста. Должен быть переопределён в наследниках.
	Стандартный формат:
	{
		"position": Vector2,      # позиция цели
		"direction": Vector2,     # направление (для снарядов)
		"radius": float,          # радиус (для area)
		"targets": Array          # конкретные цели (если есть)
	}
	"""
	return {
		"position": global_position,
		"direction": Vector2.RIGHT
	}
