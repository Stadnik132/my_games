# DamageData.gd
extends Resource
class_name DamageData

# Типы урона
enum DamageType {
	PHYSICAL,    # Физический (мечи, стрелы)
	MAGICAL,     # Магический (огненные шары, лед)
	TRUE         # Чистый (игнорирует защиту)
}

# === ЭКСПОРТИРУЕМЫЕ ПАРАМЕТРЫ ===
@export_category("Основные параметры")
@export var damage_type: DamageType = DamageType.PHYSICAL
@export_range(1, 999) var amount: int = 10

@export_category("Проникающая способность")
@export_range(0.0, 1.0, 0.01) var penetration: float = 0.0  # 0.0-1.0

@export_category("Критический удар")
@export var can_crit: bool = false
@export_range(1.0, 3.0, 0.1) var crit_multiplier: float = 1.5

@export_category("Дополнительные эффекты")
@export var status_effects: Array[Dictionary] = []  # Для будущего

# === СИГНАЛЫ ===
signal damage_calculated(final_damage: int)
signal damage_crit(crit_damage: int)

# === МЕТОДЫ ===
func duplicate_data() -> DamageData:
	"""Создаёт копию данных урона"""
	var dup = duplicate()
	dup.resource_name = resource_name + "_dup"
	return dup

func get_damage_type_name() -> String:
	"""Возвращает название типа урона"""
	return DamageType.keys()[damage_type] if damage_type < DamageType.size() else "UNKNOWN"

func is_physical() -> bool:
	return damage_type == DamageType.PHYSICAL

func is_magical() -> bool:
	return damage_type == DamageType.MAGICAL

func is_true_damage() -> bool:
	return damage_type == DamageType.TRUE

# === УТИЛИТЫ ДЛЯ ОТЛАДКИ ===
func _to_string() -> String:
	"""Строковое представление для отладки"""
	var crit_str = " (CRIT x%.1f)" % crit_multiplier if can_crit else ""
	return "%s damage: %d %s%s" % [get_damage_type_name(), amount, "pen: %.0f%%" % (penetration * 100), crit_str]

# === СТАТИЧЕСКИЕ МЕТОДЫ ДЛЯ БЫСТРОГО СОЗДАНИЯ ===
static func create_physical(amount: int, penetration: float = 0.0) -> DamageData:
	var data = DamageData.new()
	data.damage_type = DamageType.PHYSICAL
	data.amount = amount
	data.penetration = penetration
	return data

static func create_magical(amount: int, penetration: float = 0.0) -> DamageData:
	var data = DamageData.new()
	data.damage_type = DamageType.MAGICAL
	data.amount = amount
	data.penetration = penetration
	return data

static func create_true(amount: int) -> DamageData:
	var data = DamageData.new()
	data.damage_type = DamageType.TRUE
	data.amount = amount
	return data
