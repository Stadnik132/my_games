# GameStatemanager.gd
extends Node

# Управление состоянием игры (Диалог, бой, меню и т.д)
signal state_changed(new_state) # Сигнал при смене состояния

# Перечисление всех возвожных состояний в массиве
enum GameState {
	WORLD, # Свободное перемещение
	DIALOGUE, # Диалог с NPC
	MENU, # Открытое меню
	BATTLE, # Бой (Добавить позже)
	CUTSCENE, # Сценарные сцены
	DEAD # Смерть	
}

# Текущее состояние игры (current_state - текущее состояние)
var current_state: int = GameState.WORLD

# Функция для смены состояния (change_state - изменение состояния)
func change_state (new_state: int) -> void:
	# Меняему текущее состояние
	current_state = new_state
	# Сообщаем всем подписчикам об изменении состоянии
	emit_signal("state_changed", new_state)
	# Выводим в консоль для отладки
	print("Состояние игры изменено на: ", get_state_name(new_state))
	
# Функция для получения имени состояния (get_state_name - получить имя состояния)
func get_state_name(state: int) -> String:
	match state:
		GameState.WORLD: return "WORLD"
		GameState.DIALOGUE: return "DIALOGUE"
		GameState.MENU: return "MENU"
		GameState.BATTLE: return "BATTLE"
		GameState.CUTSCENE: return "CUTSCENE"
		GameState.DEAD: return "DEAD"
		_: return "UNKNOWN"

# Функция првоерки может ли игрок двигаться (can_player_move - может ли игрок двигаться?)
func can_player_move() -> bool:
	# Возвращаем true, только если в состоянии WORLD
	return current_state == GameState.WORLD
