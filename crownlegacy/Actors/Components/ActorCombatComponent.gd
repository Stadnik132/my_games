# ActorCombatComponent.gd
extends Node
class_name CombatComponent

# ==================== НАСТРОЙКИ ====================
@export_category("Защита")
@export_range(0, 100, 1) var physical_defense: int = 5
@export_range(0, 100, 1) var magical_defense: int = 5

@export_category("Параметры боя")
@export var base_damage: int = 10
@export var max_health: int = 100
@export var decision_triggers: Array[Dictionary] = [
	{"type": "time", "seconds": 45.0, "dialogue_timeline": "enemy_surrender"},
	{"type": "hp", "threshold": 0.3, "dialogue_timeline": "enemy_surrender"}
]

# ==================== СИГНАЛЫ ====================
signal health_changed(current: int, max: int)
signal died
signal combat_activated

# ==================== ПЕРЕМЕННЫЕ ====================
var current_health: int = 100
var _actor: Actor = null
var _used_triggers: Array = []
var _combat_start_time: float = 0.0
var _is_active: bool = false
var _combat_manager: Node = null

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func setup(actor: Actor) -> void:
	"""Настройка компонента для работы с актёром"""
	_actor = actor
	current_health = max_health
	set_active(false)
	print_debug("CombatComponent настроен для: ", actor.display_name)

func setup_combat(combat_manager: Node) -> void:
	"""Настройка для участия в бою"""
	_combat_manager = combat_manager
	set_active(true)
	print_debug("CombatComponent: вступление в бой")

# ==================== АКТИВАЦИЯ ====================
func set_active(value: bool) -> void:
	"""Включение/выключение компонента"""
	if _is_active == value:
		return
	
	_is_active = value
	
	if value:
		# Активация боя
		_combat_start_time = Time.get_ticks_msec() / 1000.0
		_used_triggers.clear()
		print_debug("CombatComponent активирован")
		combat_activated.emit()
	else:
		# Деактивация
		print_debug("CombatComponent деактивирован")

func is_active() -> bool:
	return _is_active

# ==================== ТОЧКИ РЕШЕНИЙ ====================
func check_decision_triggers() -> Dictionary:
	"""Проверяет триггеры для точек решений"""
	if not _is_active:
		return {}
	
	# Вычисляем время боя
	var current_time = Time.get_ticks_msec() / 1000.0
	var combat_time = current_time - _combat_start_time
	
	# Процент здоровья
	var hp_percent = float(current_health) / max_health
	
	# Проверяем все триггеры
	for trigger in decision_triggers:
		var trigger_type = trigger.get("type", "")
		
		# Пропускаем использованные триггеры
		if trigger_type in _used_triggers:
			continue
		
		match trigger_type:
			"time":
				var seconds_needed = trigger.get("seconds", 0.0)
				if combat_time >= seconds_needed:
					print_debug("Триггер времени сработал после ", seconds_needed, "с")
					return trigger
			
			"hp":
				var threshold = trigger.get("threshold", 1.0)
				if hp_percent <= threshold:
					print_debug("Триггер HP сработал при ", hp_percent * 100, "%")
					return trigger
	
	return {}

func mark_trigger_used(trigger_type: String) -> void:
	"""Пометить триггер определённого типа как использованный"""
	for trigger in decision_triggers:
		if trigger.get("type") == trigger_type:
			trigger["used"] = true

# ==================== УРОН И СМЕРТЬ ====================
func take_damage(damage_data: DamageData, source: Node = null) -> void:
	if not _is_active or current_health <= 0:
		return
	
	# 1. Рассчитываем урон
	var final_damage = _calculate_damage(damage_data)
	
	# 2. Проверяем, пересекаем ли порог HP
	var hp_after = current_health - final_damage
	var hp_percent_after = float(hp_after) / max_health
	
	# 3. Проверяем HP-триггеры (только неиспользованные)
	for trigger in decision_triggers:
		if trigger.get("type") == "hp" and not trigger.get("used", false):
			var threshold = trigger.get("threshold", 1.0)
			var current_percent = get_health_percentage()
			
			# Пересекаем порог сверху вниз?
			if current_percent > threshold and hp_percent_after <= threshold:
				# НЕМЕДЛЕННО вызываем точку решения
				if _combat_manager:
					_combat_manager.request_decision_point(self, trigger)
				# ПРЕКРАЩАЕМ обработку урона - ждём решения игрока
				return
	
	# 4. Если триггеров нет или они уже использованы - применяем урон
	current_health = max(0, current_health - final_damage)
	health_changed.emit(current_health, max_health)
	damage_data.damage_calculated.emit(final_damage)
	
	print_debug("Получен урон: ", final_damage, " (тип: ", damage_data.get_damage_type_name(), 
			   ") HP: ", current_health, "/", max_health)
	
	# 4. Визуальная реакция
	if _actor:
		_play_hit_reaction(source, damage_data.damage_type)
	
	# 5. Проверка смерти
	if current_health <= 0:
		_die(source)

func _play_hit_reaction(source: Node, damage_type: int = -1) -> void:
	"""Визуальная реакция на получение урона"""
	# Если damage_type не указан - используем PHYSICAL по умолчанию
	if damage_type == -1:
		damage_type = DamageData.DamageType.PHYSICAL
	
	var sprite = _actor.get_node_or_null("Sprite2D")
	if sprite:
		# Разный цвет для разных типов урона
		var damage_color = Color(1, 1, 1)
		match damage_type:
			DamageData.DamageType.PHYSICAL:
				damage_color = Color(1, 0.5, 0.5)  # Красноватый
			DamageData.DamageType.MAGICAL:
				damage_color = Color(0.5, 0.5, 1)  # Синеватый
			DamageData.DamageType.TRUE:
				damage_color = Color(1, 1, 0.5)    # Желтоватый
		
		# Анимация получения урона
		var tween = _actor.create_tween()
		tween.tween_property(sprite, "modulate", damage_color, 0.1)
		tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.1)
	

func take_damage_legacy(amount: int, source: Node = null) -> void:
	"""Совместимость со старым кодом (TestAttack)"""
	var legacy_data = DamageData.create_physical(amount)
	take_damage(legacy_data, source)

func _die(killer: Node = null) -> void:
	"""Смерть в бою"""
	print_debug("CombatComponent: смерть")
	
	set_active(false)
	died.emit()
	
	# Уведомляем актёра о смерти
	if _actor and _actor.has_method("_on_combat_death"):
		_actor._on_combat_death(killer)

# ==================== ГЕТТЕРЫ ====================
func get_health_percentage() -> float:
	"""Процент здоровья"""
	return float(current_health) / max_health if max_health > 0 else 0.0

func is_alive() -> bool:
	"""Проверка, жив ли"""
	return current_health > 0

func get_combat_time() -> float:
	"""Время в бою"""
	if not _is_active:
		return 0.0
	return (Time.get_ticks_msec() / 1000.0) - _combat_start_time

func get_actor() -> Actor:
	"""Получить ссылку на актёра"""
	return _actor

# ==================== УТИЛИТЫ ====================
func reset() -> void:
	"""Сброс компонента (для возрождения)"""
	current_health = max_health
	_used_triggers.clear()
	_is_active = false
	print_debug("CombatComponent сброшен")
	
# ==================== НОВЫЕ МЕТОДЫ ДЛЯ ABILITY системы ====================
func _calculate_damage(damage_data: DamageData) -> int:
	"""Расчёт финального урона с учётом защиты"""
	var base_damage = damage_data.amount
	
	# Критический удар
	if damage_data.can_crit and randf() < 0.1:  # 10% шанс крита для теста
		base_damage = int(base_damage * damage_data.crit_multiplier)
		damage_data.damage_crit.emit(base_damage)
		print_debug("КРИТИЧЕСКИЙ УДАР! x", damage_data.crit_multiplier)
	
	# TRUE урон - игнорирует защиту
	if damage_data.is_true_damage():
		return base_damage
	
	# PHYSICAL/MAGICAL урон - учитывает защиту
	var defense = 0
	match damage_data.damage_type:
		DamageData.DamageType.PHYSICAL:
			defense = physical_defense
		DamageData.DamageType.MAGICAL:
			defense = magical_defense
	
	# Применяем проникающую способность
	var effective_defense = defense * (1.0 - damage_data.penetration)
	
	# Минимум 1 урон
	return max(1, base_damage - effective_defense)
