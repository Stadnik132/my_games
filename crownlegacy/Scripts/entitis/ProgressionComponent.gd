extends Node
class_name ProgressionComponent

# ==================== СИГНАЛЫ ====================
signal level_up(new_level: int, stat_increases: Dictionary)
signal experience_gained(amount: int, new_total: int, next_level: int)
signal stat_changed(stat_name: String, new_value: int)

# ==================== ЭКСПОРТ ====================
@export var entity_data: EntityData  # PlayerData или EntityData

# Кэш финальных характеристик (с учётом модификаторов)
var _cached_stats: Dictionary = {}
var _stat_modifiers: Dictionary = {}  # stat_name: array of modifiers

# ==================== ВСТРОЕННЫЕ МЕТОДЫ ====================
func _ready() -> void:
	if not entity_data:
		push_error("ProgressionComponent: entity_data не назначен!")
		return
	
	# Подключаемся к сигналам данных
	entity_data.level_changed.connect(_on_level_changed)
	entity_data.experience_changed.connect(_on_experience_changed)
	entity_data.stat_changed.connect(_on_stat_changed)
	
	# Инициализируем кэш
	_rebuild_stat_cache()

# ==================== УРОВНИ И ОПЫТ ====================
func add_experience(amount: int, source: String = "unknown") -> void:
	"""Добавить опыт"""
	if not entity_data:
		return
	
	var old_exp = entity_data.experience
	entity_data.set_experience(entity_data.experience + amount)
	
	# Проверяем, было ли реальное изменение
	if entity_data.experience == old_exp:
		return
	
	# Эмитим сигнал о получении опыта
	experience_gained.emit(
		entity_data.experience - old_exp,
		entity_data.experience,
		entity_data.experience_to_next_level
	)
	
	# Проверяем повышения уровня
	var levels_gained = 0
	while entity_data.experience >= entity_data.experience_to_next_level:
		_level_up()
		levels_gained += 1
	
	if levels_gained > 0:
		print_debug("Progression: получено %d уровней от %s" % [levels_gained, source])

func _level_up() -> void:
	"""Внутренняя логика повышения уровня"""
	if not entity_data:
		return
	
	# Вычитаем потраченный опыт
	entity_data.experience -= entity_data.experience_to_next_level
	
	# Повышаем уровень
	var old_level = entity_data.level
	entity_data.set_level(entity_data.level + 1)
	
	# Рассчитываем новый порог опыта
	_calculate_next_level_exp()
	
	# Увеличение характеристик
	var stat_increases = _apply_level_up_stats()
	
	# Эмитим сигнал
	level_up.emit(entity_data.level, stat_increases)
	
	print_debug("Уровень повышен до %d!" % entity_data.level)

func _calculate_next_level_exp() -> void:
	"""Рассчитать опыт до следующего уровня (прогрессия)"""
	var level = entity_data.level
	# Прогрессия: каждые 5 уровней +25% к порогу
	var multiplier = 1.0 + (floor(level / 5) * 0.25)
	entity_data.experience_to_next_level = int(100 * multiplier)

func _apply_level_up_stats() -> Dictionary:
	"""Применить увеличение статов при повышении уровня"""
	var increases = {}
	
	# Базовое увеличение (зависит от класса, пока хардкод)
	increases["attack"] = 2
	increases["magic_attack"] = 2
	increases["defense"] = 1
	increases["magic_defense"] = 1
	increases["speed"] = 1
	increases["agility"] = 1
	
	# Применяем к данным
	for stat_name in increases:
		var current = entity_data.get_stat(stat_name)
		entity_data.set_stat(stat_name, current + increases[stat_name])
	
	# Увеличение здоровья и маны
	entity_data.max_hp += 10
	entity_data.max_mp += 5
	
	# Восстанавливаем ресурсы при повышении уровня
	entity_data.set_current_hp(entity_data.max_hp)
	entity_data.set_current_mp(entity_data.max_mp)
	
	return increases

# ==================== ХАРАКТЕРИСТИКИ ====================
func get_stat(stat_name: String) -> int:
	"""Получить финальное значение характеристики (с кэшем)"""
	if _cached_stats.has(stat_name):
		return _cached_stats[stat_name]
	return _calculate_stat(stat_name)

func _calculate_stat(stat_name: String) -> int:
	"""Рассчитать характеристику с учётом модификаторов"""
	if not entity_data:
		return 0
	
	var base = entity_data.get_stat(stat_name)
	var modifiers = _stat_modifiers.get(stat_name, [])
	
	# Применяем все модификаторы (сумма)
	var total_modifier = 0.0
	for mod in modifiers:
		total_modifier += mod
	
	# Финальное значение (база * (1 + сумма модификаторов))
	var final_value = base * (1.0 + total_modifier)
	_cached_stats[stat_name] = int(final_value)
	
	return _cached_stats[stat_name]

func _rebuild_stat_cache() -> void:
	"""Перестроить весь кэш характеристик"""
	_cached_stats.clear()
	# Кэш перестроится при первом запросе каждого стата

# ==================== МОДИФИКАТОРЫ ====================
func add_modifier(stat_name: String, value: float, modifier_id: String = "") -> void:
	"""Добавить временный или постоянный модификатор"""
	if not _stat_modifiers.has(stat_name):
		_stat_modifiers[stat_name] = []
	
	# Если есть ID, можно позже удалить конкретный модификатор
	var modifier = {
		"value": value,
		"id": modifier_id if modifier_id else _generate_modifier_id()
	}
	_stat_modifiers[stat_name].append(modifier)
	
	# Инвалидируем кэш для этого стата
	_cached_stats.erase(stat_name)

func remove_modifier(stat_name: String, modifier_id: String) -> void:
	"""Удалить модификатор по ID"""
	if not _stat_modifiers.has(stat_name):
		return
	
	var modifiers = _stat_modifiers[stat_name]
	for i in range(modifiers.size() - 1, -1, -1):
		if modifiers[i].id == modifier_id:
			modifiers.remove_at(i)
	
	# Инвалидируем кэш
	_cached_stats.erase(stat_name)

func _generate_modifier_id() -> String:
	"""Сгенерировать уникальный ID для модификатора"""
	return "mod_" + str(Time.get_ticks_usec()) + "_" + str(randi())

func clear_modifiers(stat_name: String = "") -> void:
	"""Очистить модификаторы (для одного стата или всех)"""
	if stat_name:
		_stat_modifiers.erase(stat_name)
		_cached_stats.erase(stat_name)
	else:
		_stat_modifiers.clear()
		_cached_stats.clear()

# ==================== ОБРАБОТЧИКИ СОБЫТИЙ ДАННЫХ ====================
func _on_level_changed(new_level: int, old_level: int) -> void:
	# При изменении уровня пересчитываем кэш (статы могли измениться)
	_rebuild_stat_cache()

func _on_stat_changed(stat_name: String, new_value: int) -> void:
	# При прямом изменении стата инвалидируем кэш
	_cached_stats.erase(stat_name)
	stat_changed.emit(stat_name, get_stat(stat_name))

func _on_experience_changed(new_exp: int, old_exp: int) -> void:
	# Уже обрабатываем в add_experience, но на всякий случай
	pass

# ==================== УТИЛИТЫ ====================
func get_level() -> int:
	return entity_data.level if entity_data else 0

func get_experience() -> int:
	return entity_data.experience if entity_data else 0

func get_experience_to_next() -> int:
	return entity_data.experience_to_next_level if entity_data else 0

func get_experience_percentage() -> float:
	if not entity_data or entity_data.experience_to_next_level <= 0:
		return 0.0
	return float(entity_data.experience) / entity_data.experience_to_next_level
