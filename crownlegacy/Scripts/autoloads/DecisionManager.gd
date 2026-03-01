extends Node

# ==================== СИГНАЛЫ ====================
signal decision_point_triggered(enemy: Node, trigger_type: String, trigger_data: Dictionary)
signal decision_made(enemy: Node, choice: String)

# ==================== НАСТРОЙКИ ====================
@export var debug_mode: bool = true
@export var decision_cooldown: float = 15.0  # Минимум 15 секунд между точками

# ==================== ПЕРЕМЕННЫЕ СОСТОЯНИЯ ====================
var is_decision_active: bool = false
var current_decision: Dictionary = {}  # {enemy, trigger_data, time}
var last_decision_time: float = 0.0

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func _ready() -> void:
	_setup_connections()
	if debug_mode:
		print_debug("DecisionSystem загружен")

func _setup_connections() -> void:
	# Слушаем запросы на точки решения от CombatComponent
	EventBus.Combat.decision.point_requested.connect(_on_decision_point_requested)
	# Слушаем выбор из диалога
	EventBus.Combat.decision.dialogic_made.connect(_on_dialogic_decision_made)

# ==================== ПУБЛИЧНЫЕ МЕТОДЫ ====================
func force_end_decision_point() -> void:
	"""Принудительное завершение (например, при смерти врага)"""
	if is_decision_active:
		_exit_decision_point()

func is_decision_point_available() -> bool:
	"""Можно ли активировать новую точку решения?"""
	if is_decision_active:
		return false
	
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_decision_time < decision_cooldown:
		return false
	
	return true

# ==================== ВНУТРЕННИЕ МЕТОДЫ ====================
func _on_decision_point_requested(enemy: Node, trigger_data: Dictionary) -> void:
	"""Запрос точки решения от CombatComponent актора"""
	if not is_decision_point_available():
		if debug_mode:
			print_debug("DecisionSystem: точка решения отклонена (кулдаун или уже активна)")
		return
	
	if debug_mode:
		print_debug("DecisionSystem: получен запрос точки решения от ", enemy.name)
	
	_trigger_decision_point(enemy, trigger_data)

func _trigger_decision_point(enemy: Node, trigger_data: Dictionary) -> void:
	print_debug("=== ТОЧКА РЕШЕНИЯ АКТИВИРОВАНА ===")
	
	# Сохраняем данные
	current_decision = {
		"enemy": enemy,
		"trigger_data": trigger_data,
		"time_triggered": Time.get_ticks_msec()
	}
	
	# Временно удаляем врага из группы врагов (чтобы не атаковал)
	if enemy.is_in_group("enemies"):
		enemy.remove_from_group("enemies")
		print_debug("DecisionSystem: враг удалён из группы 'enemies'")
	
	# Запрашиваем диалог
	var timeline_name = trigger_data.get("dialogue_timeline", "")
	if timeline_name.is_empty():
		print_debug("DecisionSystem: у врага нет диалога для точки решения")
		_exit_decision_point()
		return
	
	# Обновляем время
	last_decision_time = Time.get_ticks_msec() / 1000.0
	is_decision_active = true
	
	# Замедляем время (GameStateManager сделает это)
	EventBus.Game.decision_point_activated.emit()
	
	# Запускаем диалог
	EventBus.Game.dialogue_requested.emit(timeline_name)
	
	# Эмитим сигнал
	decision_point_triggered.emit(enemy, trigger_data.get("type", ""), trigger_data)

func _on_dialogic_decision_made(choice: String) -> void:
	"""Обработчик выбора из диалога"""
	if not is_decision_active or current_decision.is_empty():
		push_warning("DecisionSystem: получен выбор, но нет активной точки решения")
		return
	
	var enemy = current_decision.get("enemy")
	if not enemy:
		push_warning("DecisionSystem: нет врага в текущем решении")
		_exit_decision_point()
		return
	
	_handle_choice(enemy, choice)

func _handle_choice(enemy: Node, choice: String) -> void:
	"""Применяет последствия выбора"""
	print_debug("DecisionSystem: игрок выбрал '", choice, "'")
	
	match choice:
		"attack_continue", "to_combat":
			_handle_attack_choice(enemy)
		
		"start_dialogue", "to_dialogue":
			_handle_dialogue_choice(enemy)
		
		"to_world", "spare":
			_handle_spare_choice(enemy)
		
		_:
			push_warning("DecisionSystem: неизвестный выбор: ", choice)
			_handle_attack_choice(enemy)
	
	# Эмитим сигнал о сделанном выборе
	decision_made.emit(enemy, choice)

func _handle_attack_choice(enemy: Node) -> void:
	"""Продолжить бой"""
	print_debug("DecisionSystem: выбор -> ПРОДОЛЖИТЬ БОЙ")
	
	# Возвращаем врага в группу врагов
	if not enemy.is_in_group("enemies"):
		enemy.add_to_group("enemies")
	
	# Переводим в боевой режим
	if enemy.has_method("change_mode"):
		enemy.change_mode("battle")
	
	_exit_decision_point()

func _handle_dialogue_choice(enemy: Node) -> void:
	"""Перейти в диалог (завершает бой)"""
	print_debug("DecisionSystem: выбор -> НАЧАТЬ ДИАЛОГ")
	
	var timeline = current_decision.trigger_data.get("dialogue_timeline", "")
	if timeline.is_empty():
		push_warning("DecisionSystem: нет timeline для диалога")
		_exit_decision_point()
		return
	
	# Сообщаем CombatManager, что нужно завершить бой с переходом в диалог
	EventBus.Combat.decision.transition_to_dialogue.emit(enemy, timeline)

func _handle_spare_choice(enemy: Node) -> void:
	"""Пощадить врага"""
	print_debug("DecisionSystem: выбор -> ПОЩАДИТЬ")
	
	# Переводим в мирный режим
	if enemy.has_method("change_mode"):
		enemy.change_mode("world")
	
	# Помечаем как пощажённого
	enemy.set_meta("spared", true)
	
	# Удаляем из группы врагов
	if enemy.is_in_group("enemies"):
		enemy.remove_from_group("enemies")
	
	# Сообщаем CombatManager, что враг пощажён
	EventBus.Combat.decision.enemy_spared.emit(enemy)
	
	_exit_decision_point()

func _exit_decision_point() -> void:
	"""Выход из точки решения"""
	print_debug("DecisionSystem: выход из точки решения")
	
	# Возвращаем нормальное время (GameStateManager сделает это)
	EventBus.Game.decision_point_deactivated.emit()
	
	# Сбрасываем флаги
	is_decision_active = false
	current_decision.clear()
	
	# Уведомляем UI
	EventBus.Combat.decision.ui_closed.emit()
