# CombatManager.gd
extends Node

# ==================== СИГНАЛЫ ====================
signal combat_started(enemies: Array)  # Начало боя
signal combat_ended(victory: bool, experience_gained: int)  # Конец боя
signal decision_point_triggered(enemy: Node, trigger_type: String, trigger_data: Dictionary)
signal decision_made(enemy: Node, choice: String)
signal enemy_died(enemy: Node)

# ==================== НАСТРОЙКИ ====================
@export var debug_mode: bool = true
@export var decision_cooldown: float = 15.0  # Минимум 15 секунд между точками решений
@export var base_experience_per_enemy: int = 25

# ==================== ПЕРЕМЕННЫЕ СОСТОЯНИЯ ====================
var active_enemies: Array = []  # Текущие враги в бою
var is_combat_active: bool = false  # Флаг активного боя
var is_decision_active: bool = false  # Флаг активной точки решения
var last_decision_time: float = 0.0  # Время последней точки решения
var current_decision: Dictionary = {}  # Данные текущей точки решения
var _initialized_enemies: Array = []


var eb = EventBus
# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func _ready() -> void:
	add_to_group("combat_manager")
	if debug_mode:
		print_debug("CombatManager (точки решений) загружен")

	_setup_connections()

	var timer = Timer.new()
	timer.wait_time = 0.5  # Проверка каждые 0.5 секунды
	timer.timeout.connect(_on_decision_check)
	add_child(timer)
	timer.start()
	
func _on_decision_check() -> void:
	if is_combat_active and not is_decision_active:
		check_decision_triggers()

func _setup_connections() -> void:
	"""Подключение к EventBus сигналам"""
	# Боевые события
	eb.Combat.started.connect(_on_combat_started)
	eb.Dialogue.start_battle.connect(_on_dialogue_start_battle)
	eb.Combat.decision_made.connect(_on_decision_made)
	eb.Player.died.connect(_on_player_died)
	eb.Combat.dialogic_decision_made.connect(_on_dialogic_decision_made)
	
	if debug_mode:
		print_debug("CombatManager: подключено к EventBus")

# ==================== МЕТОДЫ УПРАВЛЕНИЯ БОЕМ ====================
func start_combat(enemies: Array) -> void:
	if debug_mode:
		print_debug("CombatManager: начало боя с ", enemies.size(), " врагами")
	
	# Очищаем список уже инициализированных
	_initialized_enemies.clear()
	
	active_enemies = enemies.duplicate()
	is_combat_active = true
	is_decision_active = false
	last_decision_time = Time.get_ticks_msec() / 1000.0
	
	# Инициализируем каждого врага
	for enemy in enemies:
		_initialize_enemy(enemy)
	
	eb.Game.transition_to_battle_requested.emit()
	
	eb.Combat.started.emit(enemies)
	
	if debug_mode:
		print_debug("Бой начался.")

func end_combat(victory: bool, transition_to_dialogue: bool = false, dialogue_target: Node = null) -> void:
	"""Завершение боя с различными исходами"""
	if debug_mode:
		print_debug("CombatManager: конец боя. Победа: ", victory,
			", Диалог: ", transition_to_dialogue,
			", Цель: ", dialogue_target.name if dialogue_target else "нет")

	# Если есть активная точка решения - закрываем
	if is_decision_active:
		_exit_decision_point()
	
	# Считаем награду
	var experience_gained = _calculate_experience(victory)
	
	# Очищаем состояние
	active_enemies.clear()
	is_combat_active = false
	is_decision_active = false
	_initialized_enemies.clear()
	
	# Уведомляем системы
	combat_ended.emit(victory)
	eb.Combat.ended.emit(victory)
	
	if not victory:
		# Если проиграли - Game Over
		eb.Game.transition_to_game_over_requested.emit()
	elif transition_to_dialogue and dialogue_target:
		# Если победили с переходом в диалог (например, пощадить)
		var timeline_name = ""
		if dialogue_target is Actor:
			timeline_name = dialogue_target.dialogue_timeline
		
		if timeline_name != "":
			# Явный переход в диалог
			eb.Game.transition_to_dialogue_requested.emit(timeline_name)
	else:
		eb.Game.transition_to_world_requested.emit()
		pass

# ==================== СИСТЕМА ТОЧЕК РЕШЕНИЙ ====================
func check_decision_triggers() -> void:
	"""Проверяет триггеры точек решений (вызывать извне)"""
	# Не проверяем если:
	# 1. Нет активного боя
	# 2. Уже активна точка решения
	# 3. Прошло мало времени с последней точки
	if not is_combat_active or is_decision_active:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_decision_time < decision_cooldown:
		return
	
	# Проверяем всех врагов на триггеры
	for enemy in active_enemies:
		if enemy.has_method("check_decision_triggers"):
			var trigger_data = enemy.check_decision_triggers()
			if not trigger_data.is_empty():
				_trigger_decision_point(enemy, trigger_data)
				break  # Только одна точка за раз

func _trigger_decision_point(enemy: Node, trigger_data: Dictionary) -> void:
	if is_decision_active:
		return
	
	print_debug("ТОЧКА РЕШЕНИЯ сработала!")
	
	# ЗАПОЛНИ current_decision
	current_decision = {
		"enemy": enemy,
		"trigger_data": trigger_data,
		"time_triggered": Time.get_ticks_msec()
	}
	
	# 1. Получаем Actor
	var actor = enemy
	if enemy is CombatComponent:
		actor = enemy.get_actor()  # Используем метод из CombatComponent
	
	# 2. Удаляем Actor из группы врагов
	if actor and actor.is_in_group("enemies"):
		actor.remove_from_group("enemies")
		print_debug("Враг удалён из группы 'enemies' для точки решения")
	# ===================================
	
	if enemy.has_method("mark_trigger_used"):
		var trigger_type = trigger_data.get("type", "")
		enemy.mark_trigger_used(trigger_type)
	
	var timeline_name = trigger_data.get("dialogue_timeline", "")
	if timeline_name.is_empty():
		print_debug("У врага нет диалога для точки решения")
		return
	
	# Передаём actor_id (не имя узла!)
	eb.Game.transition_to_dialogue_requested.emit(timeline_name)
	
	last_decision_time = Time.get_ticks_msec() / 1000.0
	is_decision_active = true

func _on_dialogic_decision_made(choice: String) -> void:
	"""Обработчик выбора игрока из Dialogic"""
	if not is_decision_active or current_decision.is_empty():
		return
	
	var enemy = current_decision.get("enemy")
	if enemy:
		_on_decision_made(enemy, choice)

func _on_decision_made(enemy: Node, choice: String) -> void:
	"""Обработка выбора игрока в точке решения"""
	if not is_decision_active or current_decision.is_empty():
		push_warning("Получен выбор, но нет активной точки решения")
		return
	
	# Проверяем, что выбор относится к текущему врагу
	if current_decision.enemy != enemy:
		push_warning("Выбор для неактивного врага: ", enemy.name)
		return
	
	if debug_mode:
		print_debug("Игрок выбрал: '", choice, "' для врага ", enemy.name)
	
	var actor = enemy
	if enemy is CombatComponent:
		actor = enemy.get_actor()
	# ===================================
	
	# Применяем последствия выбора
	match choice:
		"attack_continue", "to_combat":  # Добавил to_combat для совместимости
			_handle_attack_choice(actor)
		
		"start_dialogue", "to_dialogue":  # Добавил to_dialogue
			_handle_dialogue_choice(actor)
		
		"to_world":  # Новая опция
			_handle_spare_choice(actor)
		
		_:
			push_warning("Неизвестный выбор: ", choice)
			_handle_attack_choice(actor)
	
	# Сигнал о сделанном выборе (передаём actor)
	decision_made.emit(actor, choice)
	eb.Combat.decision_made.emit(actor, choice)

func _handle_attack_choice(actor: Node) -> void:
	"""Игрок выбрал 'Продолжить бой'"""
	if debug_mode:
		print_debug("Выбор: ПРОДОЛЖИТЬ БОЙ")
	
	if actor and not actor.is_in_group("enemies"):
		actor.add_to_group("enemies")
		print_debug("Враг возвращён в группу 'enemies'")
	
	if actor is Actor:
		actor.change_mode("hostile") 
		print_debug("Враг снова стал hostile")
	
	if actor.has_method("mark_trigger_used"):
		var trigger_type = current_decision.trigger_data.get("type", "")
		actor.mark_trigger_used(trigger_type)
	
	_exit_decision_point()

func _handle_dialogue_choice(enemy: Node) -> void:
	"""Игрок выбрал 'Начать диалог'"""
	if debug_mode:
		print_debug("Выбор: НАЧАТЬ ДИАЛОГ")
	
	# Получаем timeline для диалога
	var timeline_name = current_decision.trigger_data.get("dialogue_timeline", "")
	if timeline_name.is_empty():
		push_warning("У врага ", enemy.name, " нет timeline для диалога")
		_exit_decision_point()
		return
	
	# Завершаем бой с переходом в диалог
	end_combat(false, true, enemy)  # Не победа, но переход в диалог
	
	# Запускаем диалог через EventBus
	eb.Game.transition_to_dialogue_requested.emit(timeline_name)

func _exit_decision_point() -> void:
	"""Выход из точки решения"""
	if debug_mode:
		print_debug("Выход из точки решения")
	
	# Возвращаем нормальное время через GameStateManager
	var gsm = _get_game_state_manager()
	if gsm and gsm.has_method("exit_decision_point"):
		gsm.exit_decision_point()
	else:
		# Fallback
		Engine.time_scale = 1.0
	
	# Сбрасываем флаги
	is_decision_active = false
	current_decision.clear()
	
	# Уведомляем UI о закрытии
	eb.Combat.decision_ui_closed.emit()

# ==================== ОБРАБОТКА ВРАГОВ ====================
func _initialize_enemy(enemy: Node) -> void:
	"""Инициализация врага для участия в бою"""
	print_debug("Инициализация врага: ", enemy.name)
	
	# ПРОВЕРКА на рекурсию
	if enemy.has_meta("in_combat"):
		print_debug("Враг уже в бою: ", enemy.name)
		return
	
	# Сообщаем врагу, что он в бою
	if enemy is Actor:
		enemy.enter_combat(self)
	
	# ТОЛЬКО подписываемся на смерть
	var combat_component = enemy.get_node_or_null("CombatComponent")
	if combat_component and combat_component.has_signal("died"):
		combat_component.died.connect(_on_enemy_died.bind(enemy))
	
	# Помечаем как участвующего в бою
	enemy.set_meta("in_combat", true)
	
	print_debug("Враг добавлен в бой: ", enemy.name)

func _on_enemy_died(enemy: Node) -> void:
	"""Обработчик смерти врага"""
	if debug_mode:
		print_debug("Враг умер: ", enemy.name)
	
	# Удаляем из списка инициализированных
	if enemy in _initialized_enemies:
		_initialized_enemies.erase(enemy)
	
	# Удаляем из активных врагов
	if enemy in active_enemies:
		active_enemies.erase(enemy)
		
		# Если была активная точка решения с этим врагом - закрываем
		if is_decision_active and not current_decision.is_empty():
			if current_decision.enemy == enemy:
				_exit_decision_point()
		
		# Сигнал о смерти врага
		enemy_died.emit(enemy)
		eb.Combat.enemy_died.emit(enemy, base_experience_per_enemy)
		
		# Проверяем конец боя
		if active_enemies.size() == 0:
			end_combat(true)  # Победа!

func _on_enemy_health_changed(current_hp: int, max_hp: int, enemy: Node) -> void:
	"""Обработчик изменения HP врага"""
	eb.Combat.enemy_health_changed.emit(enemy, current_hp, max_hp)

# ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ====================
func _calculate_experience(victory: bool) -> int:
	"""Расчёт опыта за бой"""
	if not victory:
		return 0
	
	# База за каждого врага + модификаторы
	var total_exp = base_experience_per_enemy * (active_enemies.size() + 1)
	
	# Можно добавить модификаторы от доверия, сложности и т.д.
	# var trust_modifier = RelationshipManager.get_combat_modifier("xp_multiplier")
	# total_exp = int(total_exp * trust_modifier)
	
	return total_exp

func _on_player_died() -> void:
	"""Обработчик смерти игрока"""
	if debug_mode:
		print_debug("Игрок умер в бою")
	
	# Завершаем бой поражением
	end_combat(false)

# ==================== ПУБЛИЧНЫЕ МЕТОДЫ ====================
func is_in_combat() -> bool:
	"""Проверка, активен ли бой сейчас"""
	return is_combat_active

func get_active_enemies() -> Array:
	"""Получение копии списка активных врагов"""
	return active_enemies.duplicate()

func get_current_decision() -> Dictionary:
	"""Получение данных текущей точки решения"""
	return current_decision.duplicate()

func force_end_decision_point() -> void:
	"""Принудительное завершение точки решения"""
	if is_decision_active:
		_exit_decision_point()

# ==================== УТИЛИТЫ ====================
func _get_game_state_manager():
	"""Безопасное получение GameStateManager"""
	if Engine.has_singleton("GameStateManager"):
		return Engine.get_singleton("GameStateManager")
	return null

# ==================== ОБРАБОТЧИКИ EVENTBUS ====================
func _on_combat_started(enemies: Array) -> void:
	"""Обработчик начала боя извне"""
	if debug_mode:
		print_debug("CombatManager: получен внешний сигнал начала боя")

func _on_dialogue_start_battle(npc_id: String) -> void:
	"""Начало боя с конкретным NPC после диалога"""
	if debug_mode:
		print_debug("CombatManager: запрос боя с NPC ID = '", npc_id, "'")
	
	# Ищем NPC по ID
	var target_npc = _find_npc_by_id(npc_id)
	if not target_npc:
		push_warning("CombatManager: NPC с ID '", npc_id, "' не найден")
		return
		
	   # Начинаем бой с этим NPC
	start_combat_with_npc(target_npc)

func start_combat_with_npc(npc: Actor) -> void:
	"""Начало боя с конкретным NPC"""
	if debug_mode:
		print_debug("CombatManager: начало боя с NPC '", npc.display_name, "'")
	
	# Делаем NPC врагом
	if npc.has_method("become_enemy"):
		npc.become_enemy(self)
	
	# Начинаем бой
	start_combat([npc])
	
	# Можно добавить других врагов из группы
	var additional_enemies = get_tree().get_nodes_in_group("allied_enemies")
	for enemy in additional_enemies:
		if enemy != npc and enemy.has_method("become_enemy"):
			enemy.become_enemy(self)
			active_enemies.append(enemy)

func _find_npc_by_id(npc_id: String) -> Actor:
	"""Поиск NPC по ID среди всех актёров"""
	var actors = get_tree().get_nodes_in_group("actors")
	
	if debug_mode:
		print_debug("Поиск NPC '", npc_id, "' среди ", actors.size(), " актёров")
	
	for actor in actors:
		if actor is Actor:
			# Проверяем actor_id
			if actor.actor_id == npc_id:
				if debug_mode:
					print_debug("Найден NPC: ", actor.display_name)
				return actor
			
			# Проверяем display_name как fallback
			if actor.display_name == npc_id:
				if debug_mode:
					print_debug("Найден NPC по имени: ", actor.display_name)
				return actor
	
	if debug_mode:
		print_debug("NPC с ID '", npc_id, "' не найден")
	return null

func _load_test_enemies(battle_id: String) -> Array:
	"""Загрузка тестовых врагов (заглушка)"""
	# В будущем загружать из ресурсов
	# Сейчас возвращаем пустой массив
	return []

# ==================== ДЛЯ ВНЕШНЕГО ВЫЗОВА ====================
func process_combat_tick(delta: float) -> void:
	"""Вызывать извне для обработки боя (например, из основной игры)"""
	# Проверяем триггеры точек решений
	check_decision_triggers()
	
	# Можно добавить другую периодическую логику боя
	# Например, проверку победы/поражения, тиков эффектов и т.д.

func _on_decision_spare() -> void:
	print_debug("CombatManager: ПОЩАДИТЬ")
	
	if not is_decision_active or current_decision.is_empty():
		push_warning("Нет активной точки решения!")
		return
	
	var enemy = current_decision.get("enemy")
	if not enemy:
		return
	
	# Получаем Actor
	var actor = enemy if enemy is Actor else enemy.get_actor() if enemy.has_method("get_actor") else null
	if not actor:
		push_warning("Не могу получить Actor для пощады")
		_exit_decision_point()
		return
	
	# Обрабатываем пощаду
	_handle_spare_choice(actor)
	
	# Выходим из точки решения
	_exit_decision_point()
	
	# Очищаем решение
	current_decision.clear()
	
func _on_decision_continue() -> void:
	"""Игрок выбрал 'Продолжить бой' в точке решения"""
	print_debug("CombatManager: ПРОДОЛЖИТЬ БОЙ")
	
	if not is_decision_active or current_decision.is_empty():
		push_warning("Нет активной точки решения!")
		return
	
	# Получаем врага из current_decision
	var enemy = current_decision.get("enemy")
	if not enemy:
		push_warning("Нет врага в текущем решении!")
		return
	
	# Получаем Actor
	var actor = enemy
	if enemy is CombatComponent:
		actor = enemy.get_actor()
	
	# Логика продолжения боя
	_handle_attack_choice(actor)

func _revive_enemy_as_friendly() -> void:
	"""Оживить врага как мирного NPC"""
	if current_decision.is_empty():
		return
	
	var enemy = current_decision.get("enemy")
	if enemy and enemy is Actor:
		# Восстанавливаем здоровье
		var combat_component = enemy.get_node_or_null("CombatComponent")
		if combat_component:
			combat_component.current_health = combat_component.max_health
		
		# Возвращаем в мирный режим
		enemy.change_mode("peaceful")
		
		# Меняем цвет обратно
		var sprite = enemy.get_node_or_null("Sprite2D")
		if sprite:
			sprite.modulate = Color(1, 1, 1, 1)
		
		print_debug("Враг ", enemy.display_name, " стал мирным")

func request_decision_point(enemy: Node, trigger_data: Dictionary) -> void:
	"""Запрос точки решения от CombatComponent (немедленный)"""
	if is_decision_active:
		return
	
	# Помечаем триггер как использованный
	if enemy.has_method("mark_trigger_used"):
		enemy.mark_trigger_used(trigger_data.get("type", ""))
	
	# Добавляем флаг used в trigger_data для CombatComponent
	trigger_data["used"] = true
	
	# Вызываем существующий метод
	_trigger_decision_point(enemy, trigger_data)

func _handle_spare_choice(actor: Actor) -> void:
	"""Обработка выбора 'Пощадить'"""
	if debug_mode:
		print_debug("Обработка ПОЩАДЫ для ", actor.display_name)
	
	# 1. Враг становится мирным
	actor.change_mode("peaceful")
	
	# 2. Полностью выводим его из боя
	_remove_enemy_from_combat(actor)
	
	# 5. Проверяем конец боя
	_check_combat_end_after_spare()

func _remove_enemy_from_combat(enemy: Node) -> void:
	"""Полное удаление врага из боевой системы"""
	
	# Удаляем из всех списков
	if enemy in active_enemies:
		active_enemies.erase(enemy)
	
	if enemy in _initialized_enemies:
		_initialized_enemies.erase(enemy)
	
	# Убираем метки боя
	if enemy.has_meta("in_combat"):
		enemy.remove_meta("in_combat")
	
	# Убираем из группы врагов
	if enemy.is_in_group("enemies"):
		enemy.remove_from_group("enemies")
	
	# Помечаем как пощажённого (чтобы больше не срабатывали триггеры)
	enemy.set_meta("spared", true)
	
	# Отключаем CombatComponent если есть
	var combat_component = enemy.get_node_or_null("CombatComponent")
	if combat_component and combat_component.has_method("set_active"):
		combat_component.set_active(false)
	
	print_debug("Враг ", enemy.name, " полностью выведен из боя")

func _check_combat_end_after_spare() -> void:
	"""Проверка окончания боя после пощады"""
	
	# Если врагов не осталось - победа
	if active_enemies.size() == 0:
		print_debug("Все враги пощажены или побеждены. ПОБЕДА!")
		end_combat(true)  # Победа
	else:
		# Продолжаем бой с оставшимися врагами
		print_debug("Бой продолжается с ", active_enemies.size(), " врагами")
		# Возвращаем нормальное время
		var gsm = _get_game_state_manager()
		if gsm and gsm.has_method("exit_decision_point"):
			gsm.exit_decision_point()
