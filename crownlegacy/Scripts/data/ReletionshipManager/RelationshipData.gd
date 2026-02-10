# RelationshipData.gd
@tool
extends Resource
class_name RelationshipData

# Сигналы ресурса
signal trust_changed(new_value, delta)
signal will_changed(new_value, delta)

# Система флагов
@export_category("Флаги персонажа")
@export var character_flags: Array[String] = []

# Экспортируемые параметры
@export_range(-100, 100, 1) var trust_level: int = 50:
	set(value):
		var clamped_value = clampi(value, -100, 100)
		var delta = clamped_value - trust_level  # Разница ДО изменения
		if delta != 0:  # Если значение реально изменилось
			trust_level = clamped_value
			trust_changed.emit(trust_level, delta)  # Передаём delta

@export_range(0, 10, 1) var will_power: int = 3:
	set(value):
		var clamped_value = clampi(value, 0, 10)
		var delta = clamped_value - will_power
		if delta != 0:
			will_power = clamped_value
			will_changed.emit(will_power, delta)

# Статические данные
@export var character_name: String = "Клоус"
@export var relationship_description: String = ""

func _init() -> void:
	if Engine.is_editor_hint():
		print("Ресурс RelationshipData создан в редакторе: ", character_name)

# Утилиты
func get_trust_percentage() -> float:
	"""Доверие в процентах от -100% до 100%"""
	return float(trust_level) / 100.0

func is_trust_positive() -> bool:
	return trust_level > 0

func is_trust_negative() -> bool:
	return trust_level < 0

func has_flag(flag_name: String) -> bool:
	return flag_name in character_flags

func add_flag(flag_name: String) -> void:
	if not has_flag(flag_name):
		character_flags.append(flag_name)

func remove_flag(flag_name: String) -> void:
	if has_flag(flag_name):
		character_flags.erase(flag_name)
