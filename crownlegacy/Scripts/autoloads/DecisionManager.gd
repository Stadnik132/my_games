extends Node

# ==================== СИГНАЛЫ ====================
signal decision_point_triggered(enemy: Node, trigger_type: String, trigger_data: Dictionary)
signal decision_made(enemy: Node, choice: String)

# ==================== НАСТРОЙКИ ====================
@export var debug_mode: bool = true
@export var decision_cooldown: float = 15.0

# ==================== ПЕРЕМЕННЫЕ СОСТОЯНИЯ ====================
var is_decision_active: bool = false
var current_decision: Dictionary = {}  # {enemy, trigger_data, time}
var last_decision_time: float = -9999.0
var _enemies_before_decision: Array = []  # список всех врагов до активации

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func _ready() -> void:
	_setup_connections()
	if debug_mode:
		print_debug("DecisionSystem загружен, last_decision_time = ", last_decision_time)

func _setup_connections() -> void:
	EventBus.Combat.decision.point_requested.connect(_on_decision_point_requested)
	EventBus.Combat.decision.dialogic_made.connect(_on_dialogic_decision_made)

# ==================== ПУБЛИЧНЫЕ МЕТОДЫ ====================
func force_end_decision_point() -> void:
	if is_decision_active:
		_exit_decision_point()

func is_decision_point_available() -> bool:
	if is_decision_active:
		if debug_mode:
			print_debug("DecisionSystem: точка решения НЕ доступна - уже активна")
		return false
	
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if current_time - last_decision_time < decision_cooldown:
		if debug_mode:
			print_debug("DecisionSystem: точка решения НЕ доступна - кулдаун")
		return false
	
	return true

# ==================== ВНУТРЕННИЕ МЕТОДЫ ====================
func _on_decision_point_requested(enemy: Node, trigger_data: Dictionary) -> void:
	if debug_mode:
		print_debug("DecisionSystem: получен запрос точки решения от ", enemy.name if enemy else "unknown")
	
	if not is_decision_point_available():
		return
	
	_trigger_decision_point(enemy, trigger_data)

func _trigger_decision_point(enemy: Node, trigger_data: Dictionary) -> void:
	print_debug("=== ТОЧКА РЕШЕНИЯ АКТИВИРОВАНА (DecisionManager) ===")
	
	# Сохраняем всех врагов, которые были в бою
	_enemies_before_decision = get_tree().get_nodes_in_group("enemies")
	print_debug("  всего врагов в бою: ", _enemies_before_decision.size())
	
	# Сохраняем данные об инициаторе
	current_decision = {
		"enemy": enemy,
		"trigger_data": trigger_data,
		"time_triggered": Time.get_ticks_msec()
	}
	
	# Переводим ВСЕХ врагов в мирный режим
	for e in _enemies_before_decision:
		if is_instance_valid(e):
			if e.is_in_group("enemies"):
				e.remove_from_group("enemies")
				print_debug("  враг удалён из группы 'enemies': ", e.name)
			
			if e.has_method("change_mode"):
				e.change_mode("world")
				print_debug("  враг переведён в WORLD: ", e.name)
			
			if e.has_method("stop_ai"):
				e.stop_ai()
				print_debug("  AI остановлен: ", e.name)
	
	# Обновляем время
	last_decision_time = Time.get_ticks_msec() / 1000.0
	is_decision_active = true
	
	# Запускаем диалог
	var timeline_name = trigger_data.get("dialogue_timeline", "")
	if timeline_name.is_empty():
		print_debug("DecisionSystem: у врага нет диалога для точки решения")
		_exit_decision_point()
		return
	
	print_debug("DecisionSystem: запускаю диалог '", timeline_name, "'")
	EventBus.Game.decision_point_activated.emit()
	EventBus.Game.dialogue_requested.emit(timeline_name)
	decision_point_triggered.emit(enemy, trigger_data.get("type", ""), trigger_data)

func _on_dialogic_decision_made(choice: String) -> void:
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
	print_debug("DecisionSystem: игрок выбрал '", choice, "'")
	
	match choice:
		"attack_continue", "to_combat":
			_handle_attack_choice()
		
		"start_dialogue", "to_dialogue":
			_handle_dialogue_choice(enemy)
		
		"to_world", "spare":
			_handle_spare_choice(enemy)
		
		_:
			push_warning("DecisionSystem: неизвестный выбор: ", choice)
			_handle_attack_choice()
	
	decision_made.emit(enemy, choice)

func _handle_attack_choice() -> void:
	"""Продолжить бой - все враги возвращаются"""
	print_debug("DecisionSystem: выбор -> ПРОДОЛЖИТЬ БОЙ")
	
	for e in _enemies_before_decision:
		if is_instance_valid(e):
			if not e.is_in_group("enemies"):
				e.add_to_group("enemies")
				print_debug("  враг возвращён в группу 'enemies': ", e.name)
			
			if e.has_method("change_mode"):
				e.change_mode("battle")
				print_debug("  враг переведён в BATTLE: ", e.name)
	
	_exit_decision_point()

func _handle_dialogue_choice(enemy: Node) -> void:
	"""Перейти в диалог (завершает бой)"""
	print_debug("DecisionSystem: выбор -> НАЧАТЬ ДИАЛОГ")
	
	var timeline = current_decision.trigger_data.get("dialogue_timeline", "")
	if timeline.is_empty():
		push_warning("DecisionSystem: нет timeline для диалога")
		_exit_decision_point()
		return
	
	EventBus.Combat.decision.transition_to_dialogue.emit(enemy, timeline)

func _handle_spare_choice(enemy: Node) -> void:
	"""Пощадить конкретного врага, остальные возвращаются в бой"""
	print_debug("DecisionSystem: выбор -> ПОЩАДИТЬ")
	
	# Помечаем пощажённого
	if enemy:
		enemy.set_meta("spared", true)
		
		if enemy.has_method("change_mode"):
			enemy.change_mode("world")
		
		if enemy.has_method("reset_after_spare"):
			enemy.reset_after_spare()
		
		if enemy.is_in_group("enemies"):
			enemy.remove_from_group("enemies")
		
		EventBus.Combat.decision.enemy_spared.emit(enemy)
	
	# Остальных возвращаем в бой
	for e in _enemies_before_decision:
		if e == enemy or not is_instance_valid(e):
			continue
		
		if not e.is_in_group("enemies"):
			e.add_to_group("enemies")
		
		if e.has_method("change_mode"):
			e.change_mode("battle")
	
	_exit_decision_point()

func _exit_decision_point() -> void:
	print_debug("DecisionSystem: выход из точки решения")
	
	EventBus.Game.decision_point_deactivated.emit()
	
	is_decision_active = false
	current_decision.clear()
	_enemies_before_decision.clear()
	
	EventBus.Combat.decision.ui_closed.emit()
