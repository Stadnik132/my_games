# BattleUI.gd
extends CanvasLayer

# Сигналы действий игрока в бою
signal attack_pressed()     # Атака
signal defend_pressed()     # Защита
signal persuade_pressed()   # Убеждение
signal item_pressed()       # Использование предмета

# Ссылки на элементы UI
@onready var player_health_bar = $VBoxContainer/TopPanel/PlayerHealth/HealthBar
@onready var enemy_health_bar = $VBoxContainer/TopPanel/EnemyHealth/HealthBar
@onready var atb_progress_bar = $VBoxContainer/ATBProgressBar
@onready var action_buttons = $VBoxContainer/ActionButtons
@onready var battle_log = $VBoxContainer/BattleLog

# Ссылки на кнопки действий
@onready var attack_button = $VBoxContainer/ActionButtons/AttackButton
@onready var defend_button = $VBoxContainer/ActionButtons/DefenderButton
@onready var persuade_button = $VBoxContainer/ActionButtons/PersuadeButton
@onready var item_button = $VBoxContainer/ActionButtons/ItemButton

func _ready() -> void:
	print("BattleUI загружен и готов к работе!")
	hide_battle_ui()  # Скрываем UI при загрузке
	
	connect_to_battle_manager()  # Подключаемся к BattleManager
	connect_buttons()  # Подключаем обработчики кнопок

# Подключает UI к сигналам BattleManager
func connect_to_battle_manager() -> void:
	if not BattleManager:  # Проверяем наличие BattleManager
		print("Ошибка: BattleManager не найден!")
		return
	
	# Подключаем все необходимые сигналы
	BattleManager.battle_started.connect(_on_battle_started)
	BattleManager.battle_ended.connect(_on_battle_ended)
	BattleManager.player_health_changed.connect(_on_player_health_changed)
	BattleManager.enemy_health_changed.connect(_on_enemy_health_changed)
	BattleManager.atb_started.connect(_on_atb_started)
	BattleManager.atb_progress.connect(_on_atb_progress)
	BattleManager.atb_ended.connect(_on_atb_ended)
	BattleManager.battle_log.connect(_on_battle_log)

# Подключает сигналы кнопок к функциям-обработчикам
func connect_buttons() -> void:
	attack_button.pressed.connect(_on_attack_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	persuade_button.pressed.connect(_on_persuade_pressed)
	item_button.pressed.connect(_on_item_pressed)

# Показывает весь UI боя
func show_battle_ui() -> void:
	visible = true  # Делаем CanvasLayer видимым
	print("BattleUI показан")

# Скрывает весь UI боя
func hide_battle_ui() -> void:
	visible = false  # Делаем CanvasLayer невидимым
	print("BattleUI скрыт")

# ОБРАБОТЧИКИ СИГНАЛОВ BATTLEMANAGER

func _on_battle_started(initiator: String) -> void:
	show_battle_ui()  # Показываем UI
	add_battle_log("Бой начался! Инициатор: " + initiator)  # Логируем начало
	update_action_buttons()  # Обновляем кнопки

func _on_battle_ended(result: String) -> void:
	add_battle_log("Бой окончен! Результат: " + result)  # Логируем результат
	# Скрываем UI через 3 секунды
	var timer = get_tree().create_timer(3.0)
	timer.timeout.connect(hide_battle_ui)

func _on_player_health_changed(new_health: int) -> void:
	update_player_health(new_health)  # Обновляем здоровье игрока
	add_battle_log("Здоровье игрока: " + str(new_health))  # Логируем изменение

func _on_enemy_health_changed(new_health: int) -> void:
	update_enemy_health(new_health)  # Обновляем здоровье врага
	add_battle_log("Здоровье врага: " + str(new_health))  # Логируем изменение

func _on_atb_started(enemy_action: String, duration: float) -> void:
	show_atb_bar()  # Показываем полоску ATB
	atb_progress_bar.max_value = duration  # Устанавливаем максимальное значение
	atb_progress_bar.value = 0  # Сбрасываем текущее значение
	defend_button.disabled = false  # Включаем кнопку защиты
	add_battle_log("Враг готовит: " + enemy_action + " (" + str(duration) + "сек)")  # Логируем

func _on_atb_progress(progress: float) -> void:
	atb_progress_bar.value = progress * atb_progress_bar.max_value  # Обновляем прогресс

func _on_atb_ended() -> void:
	hide_atb_bar()  # Скрываем полоску ATB
	add_battle_log("ATB фаза завершена")  # Логируем

func _on_battle_log(message: String) -> void:
	add_battle_log(message)  # Добавляем сообщение в лог

# ОБРАБОТЧИКИ НАЖАТИЯ КНОПОК

func _on_attack_pressed() -> void:
	print("КНОПКА АТАКИ НАЖАТА!")
	emit_signal("attack_pressed")  # Сигнал атаки
	add_battle_log("Игрок выбирает атаку")  # Логируем действие
	set_buttons_enabled(false)  # Блокируем кнопки до следующего хода

func _on_defend_pressed() -> void:
	emit_signal("defend_pressed")  # Сигнал защиты
	add_battle_log("Игрок выбирает защиту")  # Логируем действие
	set_buttons_enabled(false)  # Блокируем кнопки

func _on_persuade_pressed() -> void:
	emit_signal("persuade_pressed")  # Сигнал убеждения
	add_battle_log("Игрок пытается убедить врага")  # Логируем действие
	set_buttons_enabled(false)  # Блокируем кнопки

func _on_item_pressed() -> void:
	emit_signal("item_pressed")  # Сигнал использования предмета
	add_battle_log("Игрок использует предмет")  # Логируем действие
	set_buttons_enabled(false)  # Блокируем кнопки

# ФУНКЦИИ ОБНОВЛЕНИЯ UI

func update_player_health(health: int) -> void:
	player_health_bar.value = health  # Обновляем полоску здоровья
	player_health_bar.get_node("../HealthLabel").text = "Игрок: " + str(health)  # Обновляем текст

func update_enemy_health(health: int) -> void:
	enemy_health_bar.value = health  # Обновляем полоску здоровья
	enemy_health_bar.get_node("../HealthLabel").text = "Враг: " + str(health)  # Обновляем текст

func show_atb_bar() -> void:
	atb_progress_bar.visible = true  # Показываем полоску ATB

func hide_atb_bar() -> void:
	atb_progress_bar.visible = false  # Скрываем полоску ATB

func add_battle_log(message: String) -> void:
	battle_log.text = message + "\n" + battle_log.text  # Добавляем сообщение в начало
	
	# Ограничиваем количество сообщений (последние 10)
	var lines = battle_log.text.split("\n")
	if lines.size() > 10:
		battle_log.text = "\n".join(lines.slice(0, 10))  # Оставляем только 10 строк

func update_action_buttons() -> void:
	# Обновляем доступность кнопок в зависимости от состояния боя
	if BattleManager and BattleManager.is_battle_active():
		set_buttons_enabled(true)  # Включаем кнопки если бой активен
	else:
		set_buttons_enabled(false)  # Выключаем кнопки если бой не активен

func set_buttons_enabled(enabled: bool) -> void:
	attack_button.disabled = not enabled  # Управляем кнопкой атаки
	defend_button.disabled = not enabled  # Управляем кнопкой защиты
	persuade_button.disabled = not enabled  # Управляем кнопкой убеждения
	item_button.disabled = not enabled  # Управляем кнопкой предмета
