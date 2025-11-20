# TestNoRecursion.gd
extends Node

func _ready():
	print("=== ТЕСТ БЕЗ РЕКУРСИИ ===")
	
	# Ждем загрузки всех систем
	get_tree().create_timer(1.0).timeout.connect(test_safe)

func test_safe():
	print("1. Начальное состояние:", GameStateManager.get_state_name(GameStateManager.current_state))
	
	print("2. Пробуем перейти в DIALOGUE...")
	GameStateManager.change_state(GameStateManager.GameState.DIALOGUE)
	
	print("3. Пробуем перейти в BATTLE...") 
	GameStateManager.change_state(GameStateManager.GameState.BATTLE)
	
	print("4. Возвращаемся в WORLD...")
	GameStateManager.change_state(GameStateManager.GameState.WORLD)
	
	print("=== ТЕСТ ЗАВЕРШЕН ===")
