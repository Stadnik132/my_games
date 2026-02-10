# StateDebugger.gd
extends Node

func _ready() -> void:
	print("StateDebugger готов. Нажми F2 для вывода состояния")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_state"):  # F2
		print_current_state()

func print_current_state() -> void:
	"""Печатает текущее состояние игры в консоль"""
	var gsm = _get_game_state_manager()
	if not gsm:
		print("❌ GameStateManager не найден!")
		return
	
	
	print("🎮 ТЕКУЩЕЕ СОСТОЯНИЕ ИГРЫ")
	print("Состояние: ", _get_state_name(gsm.get_current_state()))
	print("Предыдущее: ", _get_state_name(gsm._previous_state))
	

func _get_state_name(state: int) -> String:
	"""Конвертирует enum в читаемое имя"""
	var gsm = _get_game_state_manager()
	if gsm and gsm.has_method("_get_state_name"):
		return gsm._get_state_name(state)
	
	# Fallback
	var state_names = ["EXPLORATION", "DIALOGUE", "REAL_TIME", 
					  "MENU", "CUTSCENE", "GAME_OVER"]
	return state_names[state] if state < state_names.size() else "UNKNOWN"

func _get_game_state_manager():
	"""Находит GameStateManager"""
	# Пробуем разные пути
	if Engine.has_singleton("GameStateManager"):
		return Engine.get_singleton("GameStateManager")
	
	return get_node_or_null("/root/GameStateManager")
