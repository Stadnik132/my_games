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
var last_decision_time: float = -9999.0  # Инициализируем отрицательным для первого срабатывания

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func _ready() -> void:
	_setup_connections()
	if debug_mode:
		print_debug("DecisionSystem загружен, last_decision_time = ", last_decision_time)

func _setup_connections() -> void:
	# Слушаем запросы на точки решения от DecisionTriggerComponent
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
		if debug_mode:
			print_debug("DecisionSystem: точка решения НЕ доступна - уже активна")
		return false
	
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if debug_mode:
		print_debug("DecisionSystem: проверка доступности")
		print_debug("  current_time: ", current_time)
		print_debug("  last_decision_time: ", last_decision_time)
		print_debug("  decision_cooldown: ", decision_cooldown)
		print_debug("  time_since_last: ", current_time - last_decision_time)
	
	if current_time - last_decision_time < decision_cooldown:
		if debug_mode:
			print_debug("DecisionSystem: точка решения НЕ доступна - кулдаун (", 
					   decision_cooldown - (current_time - last_decision_time), " сек осталось)")
		return false
	
	if debug_mode:
		print_debug("DecisionSystem: точка решения ДОСТУПНА")
	return true

# ==================== ВНУТРЕННИЕ МЕТОДЫ ====================
func _on_decision_point_requested(enemy: Node, trigger_data: Dictionary) -> void:
	"""Запрос точки решения от DecisionTriggerComponent актора"""
	if debug_mode:
		print_debug("DecisionSystem: получен запрос точки решения от ", enemy.name if enemy else "unknown")
	
	if not is_decision_point_available():
		if debug_mode:
			print_debug("DecisionSystem: точка решения отклонена (кулдаун или уже активна)")
		return
	
	_trigger_decision_point(enemy, trigger_data)

func _trigger_decision_point(enemy: Node, trigger_data: Dictionary) -> void:
	print_debug("=== ТОЧКА РЕШЕНИЯ АКТИВИРОВАНА (DecisionManager) ===")
	print_debug("  enemy: ", enemy.name if enemy else "unknown")
	print_debug("  trigger_data: ", trigger_data)
	
	# Сохраняем данные
	current_decision = {
		"enemy": enemy,
		"trigger_data": trigger_data,
		"time_triggered": Time.get_ticks_msec()
	}
	
	# Временно отключаем врага
	if enemy and enemy.is_in_group("enemies"):
		enemy.remove_from_group("enemies")
		print_debug("DecisionSystem: враг удалён из группы 'enemies'")
	
	# Переводим врага в режим WORLD (чтобы не атаковал)
	if enemy and enemy.has_method("change_mode"):
		enemy.change_mode("world")
		print_debug("DecisionSystem: враг переведён в режим WORLD")
	
	# Останавливаем движение и AI
	if enemy and enemy.has_method("stop_ai"):
		enemy.stop_ai()
		print_debug("DecisionSystem: AI врага остановлен")
	
	# Обновляем время
	last_decision_time = Time.get_ticks_msec() / 1000.0
	is_decision_active = true
	
	print_debug("DecisionSystem: last_decision_time обновлён до ", last_decision_time)
	print_debug("DecisionSystem: is_decision_active = true")
	
	# Запрашиваем диалог
	var timeline_name = trigger_data.get("dialogue_timeline", "")
	if timeline_name.is_empty():
		print_debug("DecisionSystem: у врага нет диалога для точки решения")
		_exit_decision_point()
		return
	
	print_debug("DecisionSystem: запускаю диалог '", timeline_name, "'")
	
	# Замедляем время
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
	if enemy and not enemy.is_in_group("enemies"):
		enemy.add_to_group("enemies")
		print_debug("DecisionSystem: враг возвращён в группу 'enemies'")
	
	# Переводим в боевой режим
	if enemy and enemy.has_method("change_mode"):
		enemy.change_mode("battle")
		print_debug("DecisionSystem: враг переведён в режим BATTLE")
	
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
	if enemy and enemy.has_method("change_mode"):
		enemy.change_mode("world")
		print_debug("DecisionSystem: враг переведён в режим WORLD")
	
	# Сбрасываем состояние актора для возможности нового диалога
	if enemy and enemy.has_method("reset_after_spare"):
		enemy.reset_after_spare()
		print_debug("DecisionSystem: состояние актора сброшено после пощады")
	
	# Помечаем как пощажённого
	if enemy:
		enemy.set_meta("spared", true)
	
	# Удаляем из группы врагов
	if enemy and enemy.is_in_group("enemies"):
		enemy.remove_from_group("enemies")
		print_debug("DecisionSystem: враг удалён из группы 'enemies'")
	
	# Сообщаем CombatManager, что враг пощажён
	EventBus.Combat.decision.enemy_spared.emit(enemy)
	
	_exit_decision_point()

func _exit_decision_point() -> void:
	"""Выход из точки решения"""
	print_debug("DecisionSystem: выход из точки решения")
	
	# Возвращаем нормальное время
	EventBus.Game.decision_point_deactivated.emit()
	
	# Сбрасываем флаги
	is_decision_active = false
	current_decision.clear()
	
	# Уведомляем UI
	EventBus.Combat.decision.ui_closed.emit()
