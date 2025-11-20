# GameStateManager.gd
extends Node

# Сигнал изменения состояния игры
signal state_changed(new_state)

# Возможные глобальные состояния игры
enum GameState {
	WORLD,      # Свободное перемещение по миру
	DIALOGUE,   # Ведутся переговоры с NPC
	MENU,       # Открыто меню (инвентарь, настройки)
	BATTLE,     # Активен бой
	CUTSCENE,   # Идет сценарная сцена
	DEAD        # Смерть/проигрыш
}

# Текущее активное состояние игры
var current_state: int = GameState.WORLD

# Меняет текущее состояние игры на новое
func change_state(new_state: int) -> void:
	var old_state = current_state
	current_state = new_state  # Обновляем текущее состояние
	emit_signal("state_changed", new_state)  # Сообщаем подписчикам об изменении
	print("Состояние игры изменено на: ", get_state_name(new_state))  # Отладочная информация

# Возвращает текстовое название состояния для отладки
func get_state_name(state: int) -> String:
	match state:
		GameState.WORLD:
			return "WORLD"      # Свободное перемещение
		GameState.DIALOGUE:
			return "DIALOGUE"   # Диалог с персонажами
		GameState.MENU:
			return "MENU"       # Открыто меню
		GameState.BATTLE:
			return "BATTLE"     # Активен бой
		GameState.CUTSCENE:
			return "CUTSCENE"   # Сценарная сцена
		GameState.DEAD:
			return "DEAD"       # Игрок умер
		_:
			return "UNKNOWN"    # Неизвестное состояние

# Проверяет может ли игрок в данный момент двигаться
func can_player_move() -> bool:
	return current_state == GameState.WORLD

func is_dialogue_active() -> bool:
	return current_state == GameState.DIALOGUE

func is_battle_active() -> bool:
	return current_state == GameState.BATTLE
