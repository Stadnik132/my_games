# BattleManager.gd - скрипт менеджера боя
extends Node2D

# Ссылки на узлы UI интерфейса боя
@onready var player_panel = $UI/PlayerPanel           # Панель статистики игрока
@onready var enemy_panel = $UI/EnemyPanel             # Панель статистики врага
@onready var actions_panel = $UI/ActionsPanel         # Панель с кнопками действий
@onready var trust_label: Label = $UI/PlayerPanel/PlayerStats/PlayerTrustLabel      # Метка уровня доверия
@onready var trust_bar: ProgressBar = $UI/PlayerPanel/PlayerStats/PlayerTrustBar    # Прогресс-бар доверия
@onready var trust_status: Label = $UI/PlayerPanel/PlayerStats/PlayerTrustStatus    # Текстовый статус доверия

# Переменные для участников боя
var player_unit: BattleUnitVisual    # Ссылка на ВИЗУАЛЬНОЕ представление игрока
var enemy_unit: BattleUnitVisual     # Ссылка на ВИЗУАЛЬНОЕ представление врага

# Переменные для управления очередностью ходов
var is_player_turn: bool = true    # True если ход игрока, False если ход врага
var battle_active: bool = true     # False когда бой завершен (победа/поражение)

# Список доступных действий в бою
var available_actions: Array = []

func _ready():
	# Инициализация боевой сцены при загрузке
	print("Боевая сцена загружена!")
	setup_battle()           # 1. Создаем юнитов и настраиваем бой
	update_trust_display()   # 2. Обновляем отображение доверия
	setup_action_buttons()   # 3. Создаем кнопки действий
	start_player_turn()      # 4. Начинаем с хода игрока

# Функция начала хода игрока
func start_player_turn():
	is_player_turn = true    # Устанавливаем флаг что сейчас ход игрока
	print("--- Ход игрока ---")
	enable_action_buttons(true)  # Включаем кнопки для игрока

# Функция начала хода врага  
func start_enemy_turn():
	is_player_turn = false   # Устанавливаем флаг что сейчас ход врага
	print("--- Ход врага ---")
	enable_action_buttons(false)  # Выключаем кнопки для игрока
	process_enemy_turn()          # Враг делает свой ход

# Включение/выключение кнопок действий
func enable_action_buttons(enabled: bool):
	for button in actions_panel.get_children():  # Проходим по всем кнопкам в панели
		button.disabled = not enabled  # disabled = true если кнопка выключена

# Обработка хода врага (пока упрощенная версия)
func process_enemy_turn():
	print("Враг атакует!")
	var damage = 10  # Базовый урон врага
	player_unit.take_damage(damage)  # Наносим урон ВИЗУАЛЬНОМУ представлению игрока
	
	check_battle_end()  # Проверяем не закончился ли бой
	
	# Если бой продолжается - передаем ход игроку
	if battle_active:
		start_player_turn()

# Обновление отображения уровня доверия в UI
func update_trust_display():
	var current_trust = RelationshipManager.sync_level  # Получаем текущий уровень доверия из менеджера отношений
	
	# Обновляем текстовую метку
	trust_label.text = "Доверие: " + str(current_trust)
	
	# Обновляем прогресс-бар (значение от -100 до 100)
	trust_bar.value = current_trust
	
	# Определяем текстовый статус в зависимости от уровня доверия
	var status_text = ""
	if current_trust <= -50:
		status_text = "Вражда"
	elif current_trust <= 0:
		status_text = "Неприязнь" 
	elif current_trust <= 50:
		status_text = "Нейтрально"
	else:
		status_text = "Доверие"
		
	trust_status.text = status_text  # Устанавливаем текстовый статус

# Попытка выполнения действия игроком с проверкой доверия
func attempt_player_action(action: BattleAction) -> bool:
	# Проверяем достаточно ли доверия для этого действия
	var has_enough_trust = RelationshipManager.sync_level >= action.sync_required
	
	if has_enough_trust:
		# Доверие достаточно - выполняем действие
		action.execute(player_unit, enemy_unit)  # Передаем ВИЗУАЛЬНЫЕ представления юнитов
		RelationshipManager.change_sync(action.sync_change)  # Изменяем доверие
		update_trust_display()  # Обновляем отображение доверия
		return true  # Действие выполнено успешно
	else:
		# Доверия недостаточно - обрабатываем отказ
		handle_refusal(action)
		update_trust_display()  # Обновляем отображение доверия
		return false  # Действие не выполнено

# Обработка отказа игрока выполнять приказ
func handle_refusal(action: BattleAction):
	var refusal_penalty = action.refusal_penalty  # Получаем штраф за отказ
	RelationshipManager.change_sync(refusal_penalty)  # Применяем штраф к доверию
	
	# Алексей автоматически защищается вместо выбранного действия
	print("Алексей отказался! Вместо этого защищается")
	var defend_action = DefendAction.new()  # Создаем действие защиты
	defend_action.execute(player_unit, enemy_unit)  # Выполняем защиту
	end_player_turn()  # Передаем ход врагу после отказа

# Настройка боевой системы
func setup_battle():
	# Берем ДАННЫЕ игрока из глобального менеджера отношений
	var player_data = RelationshipManager.player_data
	
	# Создаем ВИЗУАЛЬНУЮ сцену игрока и передаем ей ДАННЫЕ
	player_unit = load("res://Scenes/Units/Player/PlayerBattle.tscn").instantiate()
	player_unit.setup_visual(player_data)  # Передаем данные в визуальное представление
	
	# Создаем ДАННЫЕ врага
	var enemy_data = BattleUnitData.new()  # Создаем новый объект данных врага
	enemy_data.setup_unit("Страж", 80, 12, 3)  # Настраиваем параметры врага
	
	# Создаем ВИЗУАЛЬНУЮ сцену врага и передаем ей ДАННЫЕ
	enemy_unit = load("res://Scenes/Units/Enemies/GuardEnemy.tscn").instantiate()
	enemy_unit.setup_visual(enemy_data)  # Передаем данные в визуальное представление
	
	# Добавляем юнитов на сцену
	$Units.add_child(player_unit)
	$Units.add_child(enemy_unit)
	
	# Позиционируем юнитов на сцене
	player_unit.position = Vector2(200, 300)   # Игрок слева
	enemy_unit.position = Vector2(600, 300)    # Враг справа
	player_unit.scale = Vector2(2, 2)          # Масштабируем для лучшей видимости
	enemy_unit.scale = Vector2(2, 2)
	
	# Выводим информацию о начале боя (обращаемся к данным через визуальные представления)
	print("Бой начался! Игрок: " + str(player_unit.unit_data.current_hp) + " HP, Враг: " + str(enemy_unit.unit_data.current_hp) + " HP")
	
	# СОЗДАЕМ ДОСТУПНЫЕ ДЕЙСТВИЯ используя наши классы
	var attack_action = AttackAction.new()     # Действие атаки
	var defend_action = DefendAction.new()     # Действие защиты
	var persuade_action = PersuadeAction.new() # Действие убеждения
	
	# Добавляем действия в массив доступных
	available_actions.append(attack_action)
	available_actions.append(defend_action)
	available_actions.append(persuade_action)
	
	print("Создано действий: " + str(available_actions.size()))  # Выводим количество созданных действий

# Создание кнопок действий в UI
func setup_action_buttons():
	print("Создаем кнопки действий...")
	
	# Очищаем старые кнопки (если есть)
	for child in actions_panel.get_children():
		child.queue_free()  # Безопасно удаляем кнопки
	
	# Создаем кнопки для КАЖДОГО действия в массиве
	for action in available_actions:
		var button = Button.new()                    # Создаем новую кнопку
		button.text = action.action_name            # Устанавливаем текст = название действия
		
		var action_data = action                    # Создаем локальную копию для передачи
		# Подключаем сигнал нажатия кнопки к функции обработки
		button.pressed.connect(_on_action_selected.bind(action_data))
		
		actions_panel.add_child(button)             # Добавляем кнопку в контейнер
		print("Создана кнопка: " + action.action_name)  # Выводим информацию о созданной кнопке

# Обработчик выбора действия игроком
func _on_action_selected(action: BattleAction): 
	# Проверяем можно ли сейчас совершать действия (ход игрока и бой активен)
	if not is_player_turn or not battle_active:
		return  # Выходим если не ход игрока или бой завершен
	
	print("Игрок выбрал: " + action.action_name)  # Выводим информацию о выборе
	
	# Пытаемся выполнить действие с проверкой доверия
	var action_success = attempt_player_action(action)
	
	# Завершаем ход только если действие ВЫПОЛНЕНО
	if action_success:
		end_player_turn()

# Завершение хода игрока
func end_player_turn():
	enable_action_buttons(false)  # Выключаем кнопки действий
	check_battle_end()            # Проверяем не закончился ли бой
	
	# Если бой продолжается - передаем ход врагу
	if battle_active:
		start_enemy_turn()

# Проверка условий окончания боя
func check_battle_end():
	# Проверяем жив ли игрок (через визуальное представление)
	if not player_unit.is_alive():
		print("Игрок проиграл!")
		battle_active = false  # Устанавливаем флаг что бой завершен
	# Проверяем жив ли враг (через визуальное представление)
	elif not enemy_unit.is_alive():
		print("Игрок победил!")
		battle_active = false  # Устанавливаем флаг что бой завершен
	else:
		# Бой продолжается - выводим текущее состояние (обращаемся к данным через визуальные представления)
		print("Бой продолжается. Игрок HP: " + str(player_unit.unit_data.current_hp) + ", Враг HP: " + str(enemy_unit.unit_data.current_hp))
