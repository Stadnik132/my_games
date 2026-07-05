# RelationshipManager
extends Node

# Данные отношений
var relationship_data: RelationshipData

@export var default_relationship_data: RelationshipData

func _ready() -> void:
	# Загружаем данные из ресурса или создаём по умолчанию
	if not default_relationship_data:
		default_relationship_data = RelationshipData.new()
		default_relationship_data.resource_name = "DefaultRelationshipData"
	
	# ВСЕГДА создаём копию для игрового процесса
	relationship_data = default_relationship_data.duplicate()
	
	# Инициализируем из BalanceConfig (если не было загрузки сохранения)
	relationship_data.trust_level = BalanceConfig.initial_trust
	relationship_data.will_power = BalanceConfig.initial_will
	
	# Подключаем сигналы данных к менеджеру
	relationship_data.trust_changed.connect(_on_data_trust_changed)
	relationship_data.will_changed.connect(_on_data_will_changed)
	
	# Отправляем начальные значения через EventBus
	EventBus.Relationship.trust_changed.emit(get_trust_level(), 0)
	EventBus.Relationship.will_changed.emit(get_will_power(), 0)
	
	print_debug("RelationshipManager загружен! Доверие: ", get_trust_level(), 
		  " Воля Героя: ", get_will_power())

# === ОСНОВНЫЕ МЕТОДЫ ===
func can_force_action() -> bool:
	"""Можно ли использовать Волю для принуждения"""
	return relationship_data.will_power > 0

func use_will(amount: int = 1) -> bool:
	"""Использовать Волю Героя"""
	if relationship_data.will_power >= amount:
		relationship_data.will_power -= amount
		return true
	return false

func force_action() -> bool:
	"""Принудить действие Волей"""
	if use_will():
		print_debug("Принуждение Волей!")
		return true
	return false

func add_will(amount: int) -> void:
	"""Добавить Волю Героя"""
	relationship_data.will_power += amount

func change_trust(amount: int, source: String = "unknown") -> void:
	"""Изменить уровень доверия"""
	relationship_data.trust_level += amount
	print_debug("Доверие изменено на ", amount, " (источник: ", source, ")")

# === ГЕТТЕРЫ ===
func get_trust_level() -> int:
	return relationship_data.trust_level

func get_will_power() -> int:
	return relationship_data.will_power

func get_trust_status() -> String:
	"""Возвращает текстовое описание уровня доверия"""
	var trust = get_trust_level()
	
	if trust <= -75: return "Ненависть"
	elif trust <= -25: return "Неприязнь"
	elif trust <= 0: return "Скептицизм"
	elif trust <= 25: return "Нейтрально"
	elif trust <= 75: return "Доверие"
	else: return "Подчинение"

func has_enough_trust(required_trust: int) -> bool:
	"""Проверка, достаточно ли доверия для действия"""
	return get_trust_level() >= required_trust

# === ОБРАБОТЧИКИ СИГНАЛОВ ДАННЫХ ===
func _on_data_trust_changed(new_value: int, delta: int) -> void:
	"""Когда данные доверия изменились"""
	# ❌ НЕ эмитим локальный сигнал - подписчики используют EventBus
	
	# ✅ Единый источник правды: EventBus
	EventBus.Relationship.trust_changed.emit(new_value, delta)
	
	# Дополнительные эффекты при сильном изменении
	if abs(delta) >= 20:
		EventBus.Relationship.trust_effect_applied.emit("major_change", delta / 100.0)

func _on_data_will_changed(new_value: int, delta: int) -> void:
	"""Когда данные воли изменились"""
	# ❌ НЕ эмитим локальный сигнал
	
	# ✅ Единый источник правды: EventBus
	EventBus.Relationship.will_changed.emit(new_value, delta)
	
	# Если использовали Волю
	if delta < 0:
		EventBus.Relationship.will_used.emit(-delta, new_value)

# === СОХРАНЕНИЕ И ЗАГРУЗКА ===
func save_data() -> Dictionary:
	"""Возвращает данные для сохранения"""
	return {
		"trust_level": relationship_data.trust_level,
		"will_power": relationship_data.will_power,
		"character_flags": relationship_data.character_flags.duplicate()
	}

func load_data(data: Dictionary) -> void:
	if data.has("trust_level"):
		relationship_data.trust_level = data.trust_level
	if data.has("will_power"):
		relationship_data.will_power = data.will_power
	if data.has("character_flags"):
		relationship_data.character_flags = data.character_flags.duplicate()

# === УТИЛИТЫ ===
func get_relationship_summary() -> Dictionary:
	"""Возвращает сводку отношений для UI"""
	return {
		"trust": get_trust_level(),
		"will": get_will_power(),
		"status": get_trust_status()
	}
