# GameStateManager.gd
extends Node

enum GameState {
	WORLD,     # Свободное перемещение по миру
	DIALOGUE,        # Активен диалог
	BATTLE,       # Бой в реальном времени
	MENU,            # Открыто любое меню
	CUTSCENE,        # Катсцена
	GAME_OVER        # Конец игры
}

var _current_state: GameState = GameState.WORLD
var _previous_state: GameState = GameState.WORLD

var eb = EventBus

func _ready() -> void:
	_setup_event_bus_connections()
	print_debug("GameStateManager загружен. Начальное состояние: ", _get_state_name(_current_state))


func _setup_event_bus_connections() -> void:
	"""Подключение к EventBus сигналам"""
	eb.Game.transition_to_world_requested.connect(_on_transition_to_world_requested)
	eb.Game.transition_to_dialogue_requested.connect(_on_transition_to_dialogue_requested)
	eb.Game.transition_to_battle_requested.connect(_on_transition_to_battle_requested)
	eb.Game.transition_to_menu_requested.connect(_on_transition_to_menu_requested)
	eb.Game.transition_to_cutscene_requested.connect(_on_transition_to_cutscene_requested)
	eb.Game.transition_to_game_over_requested.connect(_on_transition_to_game_over_requested)
	eb.Player.died.connect(_on_player_died)  # Всегда -> GAME_OVER
	#Старые
	eb.Dialogue.started.connect(_on_dialogue_started_legacy)
	eb.Dialogue.ended.connect(_on_dialogue_ended_legacy)
	eb.UI.menu_requested.connect(_on_menu_requested)
	eb.Combat.started.connect(_on_combat_started_legacy)
	eb.Combat.ended.connect(_on_combat_ended_legacy)
	eb.Actors.interaction_started.connect(_on_actor_interaction_started)
	
	print_debug("GameStateManager подключён к EventBus")

# === ОСНОВНЫЕ МЕТОДЫ ===
func change_state(new_state: GameState, force: bool = false) -> void:
	"""Публичный метод смены состояния с проверкой перехода"""
	
	# Проверка перехода, если не принудительный
	if not force and not _is_transition_allowed(_current_state, new_state):
		print_debug("GameStateManager: Переход из ", _get_state_name(_current_state), 
				   " в ", _get_state_name(new_state), " не разрешен")
		return
	
	print_debug("GameStateManager: ", _get_state_name(_current_state), " -> ", _get_state_name(new_state))
	
	_previous_state = _current_state
	_current_state = new_state
	
	# Обрабатываем последствия смены состояния
	_handle_state_change_effects(new_state, _previous_state)
	eb.Game.state_changed.emit(new_state, _previous_state)

func _is_transition_allowed(from_state: GameState, to_state: GameState) -> bool:
	"""Матрица допустимых переходов"""
	var allowed = {
		GameState.WORLD: [GameState.DIALOGUE, GameState.BATTLE, GameState.MENU, GameState.CUTSCENE, GameState.GAME_OVER],
		GameState.BATTLE: [GameState.DIALOGUE, GameState.MENU, GameState.GAME_OVER, GameState.WORLD, GameState.CUTSCENE],
		GameState.DIALOGUE: [GameState.WORLD, GameState.BATTLE, GameState.GAME_OVER, GameState.MENU, GameState.CUTSCENE],
		GameState.MENU: [GameState.WORLD, GameState.BATTLE, GameState.DIALOGUE],
		GameState.CUTSCENE: [GameState.WORLD, GameState.DIALOGUE, GameState.BATTLE],
		GameState.GAME_OVER: [GameState.WORLD]
	}
	
	return to_state in allowed.get(from_state, [])

# === ОБРАБОТКА ПОСЛЕДСТВИЙ СМЕНЫ СОСТОЯНИЯ ===
func _handle_state_change_effects(new_state: GameState, old_state: GameState) -> void:
	"""Применяет эффекты смены состояния (время, пауза и т.д.)"""
	
	# Сначала сбрасываем всё
	Engine.time_scale = 1.0
	get_tree().paused = false
	
	match new_state:
		GameState.MENU, GameState.GAME_OVER:
			# Полная пауза
			Engine.time_scale = 0.0
			get_tree().paused = true
			EventBus.Game.paused.emit(true)
		
		GameState.DIALOGUE:
			# Диалог - только блокировка управления
			EventBus.Game.paused.emit(true)
		
		GameState.CUTSCENE:
			# Катсцена - замедленное время
			Engine.time_scale = 0.5
			EventBus.Game.paused.emit(false)
		
		GameState.WORLD, GameState.BATTLE:
			# Нормальное время
			EventBus.Game.paused.emit(false)
			print_debug("WORLD/BATTLE. Time scale: ", Engine.time_scale)
	
	print_debug("Состояние: ", _get_state_name(new_state), 
			   " (time_scale: ", Engine.time_scale, 
			   ", paused: ", get_tree().paused, ")")

# === ОБРАБОТЧИКИ EVENTBUS ===
func _on_transition_to_world_requested() -> void:
	change_state(GameState.WORLD)
	
func _on_transition_to_dialogue_requested(timeline_name: String = "") -> void:
	change_state(GameState.DIALOGUE)
	if timeline_name:
		print_debug("Запрошен диалог: ", timeline_name)

func _on_transition_to_battle_requested(enemies: Array = []) -> void:
	change_state(GameState.BATTLE)
	if enemies.size() > 0:
		print_debug("Начало боя с ", enemies.size(), " врагами")
		
func _on_transition_to_menu_requested() -> void:
	change_state(GameState.MENU)

func _on_transition_to_cutscene_requested(cutscene_id: String) -> void:
	change_state(GameState.CUTSCENE)

func _on_transition_to_game_over_requested() -> void:
	change_state(GameState.GAME_OVER)
	
# ---------- ОБРАБОТЧИКИ ИГРОВЫХ СОБЫТИЙ ----------
func _on_player_died() -> void:
	# Смерть игрока всегда ведет к GAME_OVER
	change_state(GameState.GAME_OVER)

# ==================== УСТАРЕВШИЕ МЕТОДЫ (для обратной совместимости) ====================
func _on_dialogue_started_legacy(timeline_name: String) -> void:
	print_debug("GameStateManager: Устаревший сигнал dialogue_started. Используйте transition_to_dialogue_requested")
	eb.Game.transition_to_dialogue_requested.emit(timeline_name)
	
func _on_dialogue_ended_legacy() -> void:
	print_debug("GameStateManager: Устаревший сигнал dialogue_ended. Используйте явные переходы")

func _on_menu_requested() -> void:
	"""Запрос меню"""
	if _current_state in [GameState.WORLD, GameState.BATTLE]:
		change_state(GameState.MENU)


func _on_combat_started_legacy(enemies: Array) -> void:
	print_debug("GameStateManager: Устаревший сигнал combat_started. Используйте transition_to_battle_requested")
	eb.Game.transition_to_battle_requested.emit(enemies)
	
func _on_combat_ended_legacy(victory: bool) -> void:
	print_debug("GameStateManager: Устаревший сигнал combat_ended. Используйте явные переходы")

func _on_actor_interaction_started(actor: Node) -> void:
	"""Взаимодействие с актёром"""
	print_debug("Взаимодействие с: ", actor.name if actor else "unknown")

# === ПУБЛИЧНЫЕ МЕТОДЫ ===
func get_current_state() -> GameState:
	return _current_state

func get_current_state_name() -> String:
	return _get_state_name(_current_state)

func can_player_move() -> bool:
	return _current_state in [GameState.WORLD, GameState.BATTLE]

func is_ui_blocking() -> bool:
	return _current_state in [GameState.DIALOGUE, GameState.MENU, GameState.GAME_OVER, GameState.CUTSCENE]

func is_in_combat() -> bool:
	return _current_state == GameState.BATTLE

func is_dialogue_active() -> bool:
	return _current_state == GameState.DIALOGUE

# === ВСПОМОГАТЕЛЬНЫЕ ===
func _get_state_name(state: GameState) -> String:
	return GameState.keys()[state] if state < GameState.size() else "UNKNOWN"
