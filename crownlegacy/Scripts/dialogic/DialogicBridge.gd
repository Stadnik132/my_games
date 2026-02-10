# DialogicBridge.gd
extends Node

# ==================== НАСТРОЙКИ ====================
@export var debug_mode: bool = true

# ==================== КЭШИРОВАННЫЕ ДАННЫЕ ====================
var _cached_trust_level: int = 50      # [-100, +100]
var _cached_will_power: int = 3        # Ограниченный ресурс для принуждения
var _cached_flags: Dictionary = {}     # Локальный кэш флагов
var _cached_player_level: int = 1      # Уровень игрока по умолчанию
var _cached_player_stats: Dictionary = {} # Кэш характеристик игрока

var eb = EventBus

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func _ready() -> void:
	if debug_mode:
		print_debug("=== DialogicBridge ИНИЦИАЛИЗАЦИЯ ===")
	
	# Устанавливаем значения по умолчанию
	_reset_to_defaults()
	
	# Настраиваем подключения
	_setup_event_bus_connections()
	_setup_dialogic_connections()
	
	if debug_mode:
		print_debug("DialogicBridge готов. Использует кэшированные данные через EventBus")

# ==================== НАСТРОЙКА ПОДКЛЮЧЕНИЙ ====================
func _setup_event_bus_connections() -> void:
	"""Подключение к сигналам EventBus для обновления кэша"""
	
	# === Отношения ===
	eb.Relationship.trust_changed.connect(_on_trust_changed)
	eb.Relationship.will_changed.connect(_on_will_changed)
	
	# === Флаги ===
	eb.Flags.flag_changed.connect(_on_flag_changed)
	
	# === Игрок ===
	eb.Player.level_up.connect(_on_player_level_up)
	eb.Player.equipment_changed.connect(_on_player_equipment_changed)
	
	# === Диалоги ===
	eb.Dialogue.requested.connect(_on_dialogue_requested)
	eb.Game.transition_to_dialogue_requested.connect(_on_transition_to_dialogue_requested)

	
	if debug_mode:
		print_debug("DialogicBridge: подключено к EventBus для кэширования данных")

func _on_transition_to_dialogue_requested(timeline_name: String = "") -> void:
	"""Обработчик ЯВНОГО запроса диалога через переход состояния"""
	if debug_mode:
		print_debug("DialogicBridge: явный запрос диалога '", timeline_name, "'")
	
	if not Dialogic:
		push_error("Dialogic не доступен!")
		return
	
	if timeline_name.is_empty():
		push_warning("DialogicBridge: timeline_name пустой!")
		return
	
	
	# Запускаем Dialogic
	print_debug("DialogicBridge: запускаю Dialogic с timeline '", timeline_name, "'")
	Dialogic.start(timeline_name)

func _setup_dialogic_connections() -> void:
	"""Подключение к сигналам Dialogic 2.0"""
	if not Dialogic:
		push_error("Dialogic не найден! Проверьте автозагрузку.")
		return
	
	# Подключаем сигналы Dialogic
	if Dialogic.has_signal("signal_event"):
		Dialogic.signal_event.connect(_on_dialogic_signal)
	else:
		push_warning("Dialogic.signal_event не найден")


# ==================== ОБРАБОТЧИКИ EVENTBUS (ОБНОВЛЕНИЕ КЭША) ====================
func _on_trust_changed(new_value: int, delta: int) -> void:
	"""Обновление кэшированного уровня доверия"""
	_cached_trust_level = new_value
	if debug_mode:
		print_debug("DialogicBridge: доверие обновлено -> ", _cached_trust_level, " (Δ", delta, ")")

func _on_will_changed(new_value: int, delta: int) -> void:
	"""Обновление кэшированной воли"""
	_cached_will_power = new_value
	if debug_mode:
		print_debug("DialogicBridge: воля обновлена -> ", _cached_will_power, " (Δ", delta, ")")

func _on_flag_changed(flag_name: String, value: Variant) -> void:
	"""Обновление кэшированных флагов"""
	_cached_flags[flag_name] = value
	if debug_mode:
		print_debug("DialogicBridge: флаг '", flag_name, "' = ", value)

func _on_player_level_up(new_level: int, stat_increases: Dictionary) -> void:
	"""Обновление уровня игрока"""
	_cached_player_level = new_level
	for stat in stat_increases:
		if not _cached_player_stats.has(stat):
			_cached_player_stats[stat] = 0
		_cached_player_stats[stat] += stat_increases[stat]
	
	if debug_mode:
		print_debug("DialogicBridge: уровень игрока -> ", _cached_player_level)

func _on_player_equipment_changed(slot: String, old_item: String, new_item: String) -> void:
	"""При изменении снаряжения (можно обновить кэш статов)"""
	if debug_mode:
		print_debug("DialogicBridge: снаряжение изменилось: ", slot, " ", old_item, " -> ", new_item)
	# Здесь можно обновить кэш характеристик, если нужно

# ==================== МЕТОДЫ ДЛЯ DIALOGIC EXPRESSIONS (СИНХРОННЫЕ) ====================
func get_trust_level() -> int:
	"""Возвращает текущий уровень доверия для условий в Dialogic"""
	return _cached_trust_level

func get_will_power() -> int:
	"""Возвращает оставшуюся Волю Героя"""
	return _cached_will_power

func can_afford_will(amount: int = 1) -> bool:
	"""Можно ли использовать Волю"""
	return _cached_will_power >= amount

func check_flag(flag_name: String) -> bool:
	"""Проверяет флаг для условий в Dialogic"""
	return _cached_flags.get(flag_name, false)

func get_player_level() -> int:
	"""Возвращает уровень игрока"""
	return _cached_player_level

func get_player_stat(stat_name: String) -> int:
	"""Возвращает характеристику игрока (для сложных условий)"""
	return _cached_player_stats.get(stat_name, 0)

# ==================== ОБРАБОТЧИКИ DIALOGIC ====================
func _on_dialogue_requested(timeline_name: String, npc_id: String) -> void:
	"""Обработчик запроса диалога от NPC через EventBus"""
	if debug_mode:
		print_debug("DialogicBridge: запрос диалога '", timeline_name, "' от NPC '", npc_id, "'")
	
	if not Dialogic:
		push_error("Dialogic не доступен для запроса от NPC!")
		return
		
	# Запускаем Dialogic
	Dialogic.start(timeline_name)

func _on_dialogic_signal(argument: String) -> void:
	"""Обрабатывает сигналы из timeline Dialogic"""
	if debug_mode:
		print_debug("Dialogic сигнал получен: ", argument)
	
	# Разбираем сигнал: формат "тип:значение"
	var parts = argument.split(":", true, 1)
	var signal_type = parts[0]
	var signal_value = parts[1] if parts.size() > 1 else ""
	
	match signal_type:
		"start_battle":
			# Начать бой
			EventBus.Dialogue.start_battle.emit(signal_value if signal_value else "default_battle")
		
		"to_combat":
			# Вернуться в бой после точки решения (продолжить бой)
			if debug_mode:
				print_debug("DialogicBridge: запрос продолжения боя")
			EventBus.Game.transition_to_battle_requested.emit()
			EventBus.Combat.dialogic_decision_made.emit("to_combat")
		
		"to_world":
			# Вернуться в мир после боя/диалога
			if debug_mode:
				print_debug("DialogicBridge: запрос перехода в WORLD")
			EventBus.Game.transition_to_battle_requested.emit()
			EventBus.Combat.dialogic_decision_made.emit("to_world")
		
		"end_dialogue":
			# Вернуться в мир после диалога
			if debug_mode:
				print_debug("DialogicBridge: запрос окончания диалога")
			EventBus.Game.transition_to_world_requested.emit()
		
		
		"game_over":
			# Конец игры
			if debug_mode:
				print_debug("DialogicBridge: запрос GAME_OVER")
			EventBus.Game.transition_to_game_over_requested.emit()
		
		"use_will":
			# Использовать Волю
			var amount = int(signal_value) if signal_value.is_valid_int() else 1
			EventBus.Dialogue.use_will.emit(amount)
			if debug_mode:
				print_debug("Диалог запросил использование Воли: ", amount)
		
		"trust":
			# Изменить доверие
			if signal_value.is_valid_int():
				var amount = int(signal_value)
				EventBus.Dialogue.change_trust.emit(amount)
		
		"flag":
			# Установить флаг
			if signal_value:
				EventBus.Dialogue.set_flag.emit(signal_value, true)
		
		"quest":
			# Обновить квест
			if signal_value:
				var quest_parts = signal_value.split(",", true, 1)
				if quest_parts.size() == 2:
					EventBus.Flags.quest_updated.emit(quest_parts[0], int(quest_parts[1]))
		
		_:
			# Для обратной совместимости
			if argument.begins_with("flag_"):
				var flag_name = argument.trim_prefix("flag_")
				EventBus.Dialogue.set_flag.emit(flag_name, true)
			
			elif argument.begins_with("trust_"):
				var amount_str = argument.trim_prefix("trust_")
				if amount_str.is_valid_int():
					var amount = int(amount_str)
					EventBus.Dialogue.change_trust.emit(amount)


# ==================== УТИЛИТЫ ====================
func _reset_to_defaults() -> void:
	"""Сброс кэша к значениям по умолчанию из GDD"""
	_cached_trust_level = 50
	_cached_will_power = 3
	_cached_flags.clear()
	_cached_player_level = 1
	_cached_player_stats = {
		"attack": 10,
		"magic_attack": 10,
		"defense": 5,
		"magic_defense": 5,
		"speed": 10,
		"agility": 10,
		"stamina": 100
	}
	
	if debug_mode:
		print_debug("DialogicBridge: кэш сброшен к значениям по умолчанию")

func force_dialogue_end() -> void:
	"""Принудительно завершить диалог (для аварийных случаев)"""
	if Dialogic and Dialogic.has_method("end_dialog"):
		if debug_mode:
			print_debug("Принудительное завершение диалога")
		
		Dialogic.end_dialog()
		EventBus.Dialogue.ended.emit()

func is_dialogue_active() -> bool:
	"""Проверяет, активен ли диалог в данный момент"""
	# Простая проверка - ищем CanvasLayer Dialogic
	for node in get_tree().root.get_children():
		if node is CanvasLayer and "Dialogic" in node.name:
			return true
	return false

# ==================== ОТЛАДКА ====================
func get_cache_status() -> Dictionary:
	"""Возвращает статус кэша для отладки"""
	return {
		"trust": _cached_trust_level,
		"will": _cached_will_power,
		"flags_count": _cached_flags.size(),
		"player_level": _cached_player_level,
		"player_stats": _cached_player_stats
	}
