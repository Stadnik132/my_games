# GameStateManager.gd
extends Node

# Этот скрипт - центральный управляющий состоянием игры. 
# Он как дирижёр оркестра - решает, когда какая часть игры должна играть.

# Сигналы для изменения состояния игры
# Сигналы - это способ сообщить другим скриптам о событиях
signal game_state_changed(new_state)  # Вызывается при любой смене состояния
signal dialogue_started()             # Вызывается при начале диалога
signal dialogue_ended()               # Вызывается при завершении диалога
signal battle_started()               # Вызывается при начале боя
signal battle_ended()                 # Вызывается при завершении боя

# Перечисление возможных состояний игры
# enum - это список констант, как варианты в меню
enum GameState {
	WORLD,      # Состояние 0: Игрок свободно перемещается по миру
	DIALOGUE,   # Состояние 1: Идёт диалог с NPC
	BATTLE,     # Состояние 2: Идёт бой
	MENU        # Состояние 3: Открыто меню или пауза
}

# Текущее состояние игры
# var - объявление переменной. GameState - тип (из нашего enum)
var current_state: GameState = GameState.WORLD  # Начинаем в режиме мира

func _ready():
	# Функция, которая автоматически вызывается когда узел готов к работе
	print("GameStateManager готов!")  # Выводим сообщение в консоль для отладки
	# Автозагрузка настроена в Project Settings -> AutoLoad

# Основная функция смены состояния игры
# func - объявление функции. new_state - параметр (новое состояние)
func change_state(new_state: GameState):
	# Если новое состояние совпадает с текущим, ничего не делаем
	if current_state == new_state:
		return  # return - выход из функции досрочно
	
	# Выводим в консоль информацию о смене состояния для отладки
	print("Смена состояния игры: ", GameState.keys()[current_state], " -> ", GameState.keys()[new_state])
	current_state = new_state  # Обновляем текущее состояние
	game_state_changed.emit(current_state)  # emit - "кричим" сигнал, сообщая о изменении
	
	# Автоматически управляем контролем игрока в зависимости от нового состояния
	manage_player_control()

# Функция управления контролем игрока в зависимости от состояния
func manage_player_control():
	# Получаем ссылку на игрока в мире
	var player = get_player_node()
	# Если игрок не найден, выходим из функции
	if not player:
		return
	
	# match - оператор выбора (похож на switch в других языках)
	# В зависимости от текущего состояния...
	match current_state:
		GameState.WORLD:  # Если состояние "Мир"
			player.set_movement_enabled(true)  # Включаем движение игрока
		GameState.DIALOGUE, GameState.BATTLE, GameState.MENU:  # Если диалог, бой или меню
			player.set_movement_enabled(false)  # Выключаем движение игрока

# Функция поиска игрока на текущей сцене
func get_player_node():
	# Ищем узел с именем "PlayerWorld" на текущей сцене
	var player = get_tree().current_scene.find_child("PlayerWorld", true, false)
	# Если игрок найден И у него есть метод set_movement_enabled...
	if player and player.has_method("set_movement_enabled"):
		return player  # Возвращаем найденного игрока
	return null  # Если игрок не найден, возвращаем "ничего"

# Публичные методы для удобства - эти функции могут вызывать другие скрипты

# Функция начала диалога
func start_dialogue():
	change_state(GameState.DIALOGUE)  # Меняем состояние на "Диалог"
	dialogue_started.emit()           # Сообщаем о начале диалога

# Функция завершения диалога
func end_dialogue():
	change_state(GameState.WORLD)  # Возвращаемся в состояние "Мир"
	dialogue_ended.emit()          # Сообщаем о завершении диалога

# Функция начала боя
func start_battle():
	change_state(GameState.BATTLE)  # Меняем состояние на "Бой"
	battle_started.emit()           # Сообщаем о начале боя

# Функция завершения боя
func end_battle():
	change_state(GameState.WORLD)  # Возвращаемся в состояние "Мир"
	battle_ended.emit()            # Сообщаем о завершении боя

# Функции-проверки для других систем

# Проверка: находится ли игра в режиме мира?
func is_in_world() -> bool:
	return current_state == GameState.WORLD  # Возвращает true если в мире

# Проверка: идёт ли сейчас диалог?
func is_in_dialogue() -> bool:
	return current_state == GameState.DIALOGUE  # Возвращает true если диалог

# Проверка: идёт ли сейчас бой?
func is_in_battle() -> bool:
	return current_state == GameState.BATTLE  # Возвращает true если бой
