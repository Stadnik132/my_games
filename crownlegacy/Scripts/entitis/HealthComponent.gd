extends Node
class_name HealthComponent

# ==================== СИГНАЛЫ ====================
signal health_changed(new_value: int, old_value: int, max_value: int)
signal died()
signal damage_taken(amount: int, damage_type: int, source: Node, is_critical: bool)
signal healed(amount: int)

# ==================== ЭКСПОРТ ====================
@export var entity_data: EntityData  # ссылка на данные (PlayerData или EntityData)

# ==================== ВСТРОЕННЫЕ МЕТОДЫ ====================
func _ready() -> void:
	if not entity_data:
		push_error("HealthComponent: entity_data не назначен!")
		return
	
	# Подключаемся к сигналам данных для локальной обработки
	# но НЕ эмитим их в EventBus отсюда — это будет делать владелец (Player или Actor)
	entity_data.died.connect(_on_data_died)
	# Не подключаем health_changed, потому что будем вызывать его вручную в take_damage/heal

func _on_data_died() -> void:
	died.emit()

# ==================== ПУБЛИЧНЫЕ МЕТОДЫ ====================
func take_damage(amount: int, damage_type: int, source: Node = null, is_critical: bool = false) -> void:
	"""Нанести урон сущности"""
	if not entity_data or not entity_data.is_alive():
		return
	
	var old_hp = entity_data.current_hp
	
	# Применяем урон через безопасный сеттер
	entity_data.set_current_hp(entity_data.current_hp - amount)
	
	# Эмитим сигналы ТОЛЬКО если здоровье реально изменилось
	if entity_data.current_hp != old_hp:
		health_changed.emit(entity_data.current_hp, old_hp, entity_data.max_hp)
		damage_taken.emit(amount, damage_type, source, is_critical)
		
		# Визуальный эффект получения урона
		_apply_damage_flash(damage_type)
		
		if entity_data.current_hp <= 0:
			died.emit()

func _apply_damage_flash(damage_type: int) -> void:
	var owner = get_parent()
	
	if owner and owner.has_method("apply_damage_flash"):
		owner.apply_damage_flash(damage_type)

func heal(amount: int) -> void:
	"""Лечение сущности"""
	if not entity_data or not entity_data.is_alive():
		return
	
	var old_hp = entity_data.current_hp
	entity_data.set_current_hp(entity_data.current_hp + amount)
	
	if entity_data.current_hp != old_hp:
		health_changed.emit(entity_data.current_hp, old_hp, entity_data.max_hp)
		healed.emit(entity_data.current_hp - old_hp)

func set_max_health(new_max: int) -> void:
	"""Установить максимальное здоровье"""
	if not entity_data:
		return
	
	entity_data.max_hp = max(1, new_max)
	# Если текущее здоровье превышает новый максимум — корректируем
	if entity_data.current_hp > entity_data.max_hp:
		entity_data.set_current_hp(entity_data.max_hp)

func is_alive() -> bool:
	return entity_data and entity_data.is_alive()

func get_health_percentage() -> float:
	return entity_data.get_hp_percentage() if entity_data else 0.0

func get_current_health() -> int:
	return entity_data.current_hp if entity_data else 0

func get_max_health() -> int:
	return entity_data.max_hp if entity_data else 0
