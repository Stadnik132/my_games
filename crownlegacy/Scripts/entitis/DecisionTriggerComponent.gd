# DecisionTriggerComponent.gd
extends Node
class_name DecisionTriggerComponent

# Сигнал для локального использования (если нужно)
signal trigger_activated(trigger_data: Dictionary)
var _is_trigger_processing: bool = false

# ==================== ЭКСПОРТ ====================
@export var debug_mode: bool = true
@export var check_interval: float = 0.2  # для time-based триггеров

# ==================== ССЫЛКИ ====================
var owner_entity: Entity
var active_triggers: Array[DecisionTrigger] = []
var combat_start_time: float = 0.0
var is_in_combat: bool = false

# Таймер для периодической проверки
var _timer: Timer

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func _ready():
	_timer = Timer.new()
	_timer.wait_time = check_interval
	_timer.one_shot = false
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)
	
	# Подключаемся к EventBus
	_setup_event_bus_connections()

func _setup_event_bus_connections() -> void:
	# Слушаем начало и конец боя
	EventBus.Combat.started.connect(_on_combat_started)
	EventBus.Combat.ended.connect(_on_combat_ended)

func setup(entity: Entity, triggers: Array[DecisionTrigger]) -> void:
	owner_entity = entity
	
	# Копируем триггеры (чтобы не изменять оригинальный ресурс)
	active_triggers.clear()
	for trigger in triggers:
		active_triggers.append(trigger)
	
	if debug_mode:
		print_debug("DecisionTriggerComponent: настроен для ", entity.name, 
				   " с ", active_triggers.size(), " триггерами")
	
	# Подписываемся на локальные события компонентов
	_setup_component_connections()

func _setup_component_connections() -> void:
	if not owner_entity:
		return
	
	# Подписываемся на изменение здоровья
	if owner_entity.health_component:
		if not owner_entity.health_component.health_changed.is_connected(_on_health_changed):
			owner_entity.health_component.health_changed.connect(_on_health_changed)

# ==================== ОБРАБОТЧИКИ EVENTBUS ====================
func _on_combat_started(enemies: Array) -> void:
	"""Вызывается при начале любого боя"""
	# Проверяем, участвует ли наш владелец в этом бою
	if not owner_entity or owner_entity not in enemies:
		return
	
	if debug_mode:
		print_debug("DecisionTriggerComponent: бой начался для ", owner_entity.name)
	
	start_combat_tracking()

func _on_combat_ended(victory: bool) -> void:
	"""Вызывается при окончании любого боя"""
	# Если мы не в бою - игнорируем
	if not is_in_combat:
		return
	
	if debug_mode:
		print_debug("DecisionTriggerComponent: бой закончился для ", owner_entity.name)
	
	stop_combat_tracking()

# ==================== УПРАВЛЕНИЕ ====================
func start_combat_tracking() -> void:
	"""Начинает отслеживание боя для этого актора"""
	if is_in_combat:
		return
	
	is_in_combat = true
	combat_start_time = Time.get_ticks_msec() / 1000.0
	_timer.start()
	
	if debug_mode:
		print_debug("DecisionTriggerComponent: начато отслеживание боя для ", owner_entity.name)

func stop_combat_tracking() -> void:
	"""Останавливает отслеживание боя"""
	if not is_in_combat:
		return
	
	is_in_combat = false
	_timer.stop()
	
	if debug_mode:
		print_debug("DecisionTriggerComponent: остановлено отслеживание боя для ", owner_entity.name)

# ==================== ПРОВЕРКА ТРИГГЕРОВ ====================
func _on_timer_timeout() -> void:
	"""Периодическая проверка (для time-based триггеров)"""
	if not is_in_combat or active_triggers.is_empty():
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var battle_duration = current_time - combat_start_time
	
	for trigger in active_triggers:
		if trigger.trigger_type == DecisionTrigger.TriggerType.TIME:
			if battle_duration >= trigger.value:
				_activate_trigger(trigger)
				return  # только один триггер за раз

func _on_health_changed(new_value: int, old_value: int, max_value: int) -> void:
	"""Проверка HP-триггеров"""
	if not is_in_combat or active_triggers.is_empty():
		return
	
	var hp_percent = float(new_value) / max_value
	
	for trigger in active_triggers:
		if trigger.trigger_type == DecisionTrigger.TriggerType.HP:
			if hp_percent <= trigger.value:
				_activate_trigger(trigger)
				return  # только один триггер за раз

func _activate_trigger(trigger: DecisionTrigger) -> void:
	if _is_trigger_processing:
		print_debug("  Предотвращена повторная активация")
		return
	
	_is_trigger_processing = true
	if debug_mode:
		print_debug("=== ТОЧКА РЕШЕНИЯ АКТИВИРОВАНА ===")
		print_debug("  Владелец: ", owner_entity.name)
		print_debug("  Тип: ", "TIME" if trigger.trigger_type == DecisionTrigger.TriggerType.TIME else "HP")
		print_debug("  Значение: ", trigger.value)
		print_debug("  Диалог: ", trigger.dialogue_timeline)
	
	var trigger_data = {
		"type": "time" if trigger.trigger_type == DecisionTrigger.TriggerType.TIME else "hp",
		"value": trigger.value,
		"dialogue_timeline": trigger.dialogue_timeline,
		"one_shot": trigger.one_shot
	}
	
	# Удаляем одноразовый триггер
	if trigger.one_shot:
		active_triggers.erase(trigger)
		if debug_mode:
			print_debug("  Триггер удалён (одноразовый)")
	
	# Отправляем событие в DecisionManager
	EventBus.Combat.decision.point_requested.emit(owner_entity, trigger_data)
	
	# Локальный сигнал
	trigger_activated.emit(trigger_data)
	
	if debug_mode:
		print_debug("  Сигнал point_requested отправлен")
	
	_is_trigger_processing = false
# ==================== ПУБЛИЧНЫЕ МЕТОДЫ ====================
func get_active_triggers_count() -> int:
	return active_triggers.size()

func has_active_triggers() -> bool:
	return not active_triggers.is_empty()

func clear_all_triggers() -> void:
	active_triggers.clear()
	if debug_mode:
		print_debug("DecisionTriggerComponent: все триггеры очищены")
