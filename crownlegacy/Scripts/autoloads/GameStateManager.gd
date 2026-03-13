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
	eb.Game.world_requested.connect(_on_transition_to_world_requested)
	eb.Game.dialogue_requested.connect(_on_transition_to_dialogue_requested)
	eb.Combat.started.connect(_on_transition_to_battle_requested)
	eb.Game.menu_requested.connect(_on_transition_to_menu_requested)
	eb.Game.cutscene_requested.connect(_on_transition_to_cutscene_requested)
	eb.Game.game_over_requested.connect(_on_transition_to_game_over_requested)
	eb.Entity.died.connect(_on_entity_died)
	eb.Combat.decision.dialogic_made.connect(_on_dialogic_decision_made)
	
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

func _on_dialogic_decision_made(choice: String) -> void:
	"""Обработка выбора в диалоге после точки решения"""
	match choice:
		"to_combat":
			change_state(GameState.BATTLE)
		"to_world":
			change_state(GameState.WORLD)

# ---------- ОБРАБОТЧИКИ ИГРОВЫХ СОБЫТИЙ ----------
func _on_entity_died(entity: Node) -> void:
	# Реагируем только на смерть игрока
	if not entity or not entity.is_in_group("player"):
		return
	
	# После смерти игрока возвращаемся в состояние WORLD
	change_state(GameState.WORLD)

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
