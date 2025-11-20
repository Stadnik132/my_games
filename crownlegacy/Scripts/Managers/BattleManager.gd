# BattleManager.gd
extends Node

# Сигналы для связи с UI и другими системами
signal battle_started(initiator)        # Начало боя
signal battle_ended(result)             # Конец боя
signal player_health_changed(new_health) # Изменение здоровья игрока
signal enemy_health_changed(new_health)  # Изменение здоровья врага
signal atb_started(enemy_action, duration)  # Начало ATB фазы
signal atb_progress(progress)           # Прогресс ATB
signal atb_ended()                      # Конец ATB фазы
signal battle_log(message)              # Сообщение в лог боя

# Возможные состояния боя
enum BattleState {
	IDLE,              # Бой не активен
	START,             # Начальная фаза боя
	PLAYER_ATTACKING,  # Игрок атакует
	ENEMY_PREPARE,     # Враг готовится к атаке
	ENEMY_ATB,         # ATB фаза - игрок выбирает защиту
	ENEMY_ATTACKING,   # Враг атакует
	VICTORY,           # Победа
	DEFEAT             # Поражение
}

# Переменные управления боем
var current_battle_state: BattleState = BattleState.IDLE  # Текущее состояние
var turn_order: Array = []  # Очередь ходов
var current_turn_index: int = 0  # Текущий индекс в очереди
var battle_initiator: String = ""  # Кто начал бой
var current_player: Node = null  # Ссылка на игрока
var current_enemy: Node = null   # Ссылка на врага

# Переменные ATB системы
var atb_timer: Timer  # Таймер ATB
var current_atb_duration: float = 0.0  # Длительность текущего ATB
var atb_time_elapsed: float = 0.0  # Прошедшее время ATB
var enemy_prepared_action: String = ""  # Действие врага

# Ссылки
var battle_ui: Node = null  # Ссылка на BattleUI

func _ready() -> void:
	print("BattleManager загружен и готов к работе!")
	current_battle_state = BattleState.IDLE  # Начальное состояние
	
	# Получаем ссылку на BattleUI
	battle_ui = get_node("/root/BattleUI")
	if battle_ui:
		print("BattleUI найден!")
		# Подключаем сигналы от UI
		battle_ui.attack_pressed.connect(player_attack)
		battle_ui.defend_pressed.connect(player_defend)
		battle_ui.persuade_pressed.connect(player_persuade)
		battle_ui.item_pressed.connect(_on_item_pressed)
	else:
		print("Предупреждение: BattleUI не найден в автозагрузке")
	
	# Создаем таймер для ATB системы
	atb_timer = Timer.new()
	add_child(atb_timer)
	atb_timer.timeout.connect(_on_atb_timeout)
	atb_timer.one_shot = true  # Однократное срабатывание

func _process(delta: float) -> void:
	# Обновляем прогресс ATB если он активен
	if current_battle_state == BattleState.ENEMY_ATB:
		atb_time_elapsed += delta  # Увеличиваем прошедшее время
		var progress = atb_time_elapsed / current_atb_duration  # Вычисляем прогресс
		emit_signal("atb_progress", progress)  # Сообщаем UI

# ОСНОВНЫЕ ФУНКЦИИ УПРАВЛЕНИЯ БОЕМ

# Начинает бой с указанным врагом
func start_battle(enemy: Node, initiator: String = "player") -> void:
	GameStateManager.change_state(GameStateManager.GameState.BATTLE)
	if current_battle_state != BattleState.IDLE:  # Проверяем не активен ли уже бой
		print("Ошибка: бой уже активен!")
		return
	
	battle_initiator = initiator  # Сохраняем инициатора
	current_enemy = get_tree().get_first_node_in_group("enemy")  # Сохраняем врага
	current_player = get_tree().get_first_node_in_group("player")  # Ищем игрока
	
	if not current_player or not current_enemy:  # Проверяем участников
		print("Ошибка: не найден игрок или враг для боя!")
		return
	
	current_battle_state = BattleState.START  # Устанавливаем состояние начала
	calculate_turn_order()  # Рассчитываем очередь ходов
	emit_signal("battle_started", battle_initiator)  # Сигнал начала боя
	start_next_turn()  # Начинаем первый ход
	prepare_battle_visuals()  # Подготавливаем визуальные эффекты
	
	print("Бой начат! Инициатор: ", battle_initiator)
	print("Очередь ходов: ", turn_order)

# Рассчитывает очередь ходов на основе инициативы
func calculate_turn_order() -> void:
	turn_order = []  # Очищаем очередь
	
	# Получаем инициативу участников
	var player_initiative: int = PlayerData.get_initiative() if PlayerData else 10
	var enemy_initiative: int = current_enemy.get_initiative() if current_enemy else 10
	
	# Инициатор ВСЕГДА ходит первым
	if battle_initiator == "player":
		turn_order = ["player_attacking", "enemy_attacking"]
	else:
		turn_order = ["enemy_attacking", "player_attacking"]
	
	# Дополнительные ходы за разницу инициативы
	var initiative_diff = player_initiative - enemy_initiative
	
	if initiative_diff >= 2:  # Игрок быстрее
		if battle_initiator == "player":
			turn_order.append("player_attacking")
		else:
			turn_order.insert(1, "player_attacking")
		print("Игрок получает +1 ход за высокую инициативу")
		
	if initiative_diff >= 4:  # Игрок намного быстрее
		if battle_initiator == "player":
			turn_order.append("player_attacking")
		else:
			turn_order.insert(1, "player_attacking")
		print("Игрок получает +2 хода за очень высокую инициативу")
	
	if initiative_diff <= -2:  # Враг быстрее
		if battle_initiator == "player":
			turn_order.insert(1, "enemy_attacking")
		else:
			turn_order.append("enemy_attacking")
		print("Враг получает +1 ход за высокую инициативу")
		
	if initiative_diff <= -4:  # Враг намного быстрее
		if battle_initiator == "player":
			turn_order.insert(1, "enemy_attacking")
		else:
			turn_order.append("enemy_attacking")
		print("Враг получает +2 хода за очень высокую инициативу")
	
	current_turn_index = 0  # Сбрасываем индекс хода

# Начинает следующий ход в очереди
func start_next_turn() -> void:
	if current_battle_state == BattleState.VICTORY or current_battle_state == BattleState.DEFEAT:
		return  # Выходим если бой завершен
	
	var current_turn = turn_order[current_turn_index]  # Получаем текущий ход
	
	match current_turn:
		"player_attacking":
			current_battle_state = BattleState.PLAYER_ATTACKING
			if battle_ui and battle_ui.has_method("set_buttons_enabled"):
				battle_ui.set_buttons_enabled(true)  # Разблокируем кнопки
				print("Кнопки разблокированы - ход игрока")
		"enemy_attacking":
			current_battle_state = BattleState.ENEMY_PREPARE
			if battle_ui and battle_ui.has_method("set_buttons_enabled"):
				battle_ui.set_buttons_enabled(false)  # Блокируем кнопки
				print("Кнопки заблокированы - ход врага")
			start_enemy_prepare_phase()  # Запускаем подготовку врага
	
	current_turn_index += 1  # Увеличиваем индекс
	
	if current_turn_index >= turn_order.size():  # Если дошли до конца очереди
		current_turn_index = 0  # Начинаем цикл заново

# Завершает текущий ход
func end_current_turn() -> void:
	start_next_turn()  # Переходим к следующему ходу

# ATB СИСТЕМА - ФАЗЫ ХОДА ВРАГА

# Начинает фазу подготовки врага к атаке
func start_enemy_prepare_phase() -> void:
	current_battle_state = BattleState.ENEMY_PREPARE
	
	# Враг выбирает случайное действие
	var possible_actions = ["attack", "fireball", "ice_spell"]
	enemy_prepared_action = possible_actions[randi() % possible_actions.size()]
	
	print("Враг готовит: ", enemy_prepared_action)
	
	# Переходим к ATB фазе через задержку
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(start_enemy_atb_phase)

# Начинает ATB фазу
func start_enemy_atb_phase() -> void:
	current_battle_state = BattleState.ENEMY_ATB
	
	# Определяем длительность ATB в зависимости от действия
	match enemy_prepared_action:
		"attack":
			current_atb_duration = 2.0
		"fireball":
			current_atb_duration = 3.0
		"ice_spell":
			current_atb_duration = 2.5
		_:
			current_atb_duration = 2.0
	
	atb_time_elapsed = 0.0  # Сбрасываем время
	atb_timer.start(current_atb_duration)  # Запускаем таймер
	
	emit_signal("atb_started", enemy_prepared_action, current_atb_duration)  # Сигнал начала ATB

# Обработчик окончания ATB таймера
func _on_atb_timeout() -> void:
	if current_battle_state == BattleState.ENEMY_ATB:
		current_battle_state = BattleState.ENEMY_ATTACKING
		execute_enemy_attack()  # Выполняем атаку врага

# ФУНКЦИИ ДЕЙСТВИЙ ИГРОКА

func player_attack() -> void:
	if current_battle_state != BattleState.PLAYER_ATTACKING:
		print("Ошибка: не время атаковать!")
		return
		
	var player_attack_power = PlayerData.attack_power
	var enemy = get_tree().get_first_node_in_group("enemy")
		
	if enemy and enemy.has_method("take_damage"):
		var is_dead = enemy.take_damage(player_attack_power)
		emit_signal("battle_log", "Игрок атакует! Урон: " + str(player_attack_power))

		if is_dead:
			end_battle("victory")  # Враг умер
		else:
			end_current_turn()     # Продолжаем бой

func player_defend() -> void:
	if current_battle_state != BattleState.ENEMY_ATB:
		print("Ошибка: не время защищаться!")
		return
	emit_signal("battle_log", "Игрок защищается от " + enemy_prepared_action)
	print("Игрок выбрал защиту от ", enemy_prepared_action)
	# ATB продолжает отсчет

func player_persuade() -> void:
	if current_battle_state != BattleState.PLAYER_ATTACKING:
		print("Ошибка: не время убеждать!")
		return
	emit_signal("battle_log", "Игрок пытается убедить врага!")
	print("Игрок пытается убедить врага!")
	end_current_turn()  # Завершаем ход

func _on_item_pressed() -> void:
	if current_battle_state != BattleState.PLAYER_ATTACKING:
		print("Ошибка: не время использовать предмет!")
		return
	print("Игрок использует предмет!")
	# TODO: Логика использования предмета
	end_current_turn()  # Завершаем ход

# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ

# Подготавливает визуальные эффекты боя
func prepare_battle_visuals() -> void:
	print("Подготовка визуальных эффектов боя...")
	
	# Игрок отпрыгивает назад
	if current_player and current_player.has_method("jump_back"):
		current_player.jump_back()
	
	# TODO: Враг принимает боевую стойку
	# if current_enemy and current_enemy.has_method("enter_battle_stance"):
	#     current_enemy.enter_battle_stance()

# Выполняет атаку врага (заглушка)
func execute_enemy_attack() -> void:
	var enemy_attack_power = current_enemy.attack_power
	
	# Игрок получает урон
	PlayerData.change_health(-enemy_attack_power)
	emit_signal("battle_log", "Враг атакует! Урон: " + str(enemy_attack_power))
	
	# ПРОВЕРЯЕМ СМЕРТЬ ИГРОКА
	if PlayerData.health <= 0:
		end_battle("defeat")  # Игрок умер
	else:
		end_current_turn()    # Продолжаем бой

# Проверяет активен ли бой
func is_battle_active() -> bool:
	return current_battle_state != BattleState.IDLE

# Возвращает текстовое название текущего состояния
func get_battle_state_name() -> String:
	match current_battle_state:
		BattleState.IDLE: return "IDLE"
		BattleState.START: return "START"
		BattleState.PLAYER_ATTACKING: return "PLAYER_ATTACKING"
		BattleState.ENEMY_PREPARE: return "ENEMY_PREPARE"
		BattleState.ENEMY_ATB: return "ENEMY_ATB"
		BattleState.ENEMY_ATTACKING: return "ENEMY_ATTACKING"
		BattleState.VICTORY: return "VICTORY"
		BattleState.DEFEAT: return "DEFEAT"
		_: return "UNKNOWN"

func end_battle(result: String) -> void:
	GameStateManager.change_state(GameStateManager.GameState.WORLD)
	emit_signal("battle_ended", result)
