# DialogUI.gd - скрипт сцены диалогового UI
extends Control

# ССылки на узлы сцены (Диалоговое окно). 
# @onready означает что переменные инициализируются когда узел полностью готов
@onready var speaker_label: Label = $SpeakerLabel  # Показывает имя говорящего персонажа
@onready var dialog_label: Label = $DialogLabel    # Показывает текст реплики
@onready var options_container: VBoxContainer = $VBoxContainer  # Контейнер для кнопок ответов

# Переменные для хранения данных диалога
var current_dialogue_data: Array   # Массив всех реплик диалога из JSON файла
var current_line_id: int = 0       # ID текущей реплики (начинается с 0)

func _ready():
	# Прячем диалоговое окно при запуске - оно покажется когда нужно
	hide()

# Функция для запуска диалога извне (вызывается из NPC)
func start_dialogue(dialogue_file: String):
	# Вместо своего сигнала используем GameStateManager
	GameStateManager.start_dialogue()
	
	load_dialogue(dialogue_file)
	show()

# Функция загрузки диалога из JSON файла
func load_dialogue(file_path: String):
	print("=== ЗАГРУЗКА ДИАЛОГА: ", file_path, " ===")
	
	# Пытаемся открыть файл для чтения
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("ОШИБКА: Файл диалога не найден: ", file_path)
		return  # Прекращаем выполнение функции если файл не найден
	
	# Создаем парсер JSON и пытаемся прочитать файл
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	
	if error == OK:  # Если парсинг успешен (OK = 0)
		var data = json.data  # Получаем распарсенные данные
		current_dialogue_data = data["lines"]  # Сохраняем массив реплик
		show_line(0)  # Начинаем с первой реплики (ID = 0)
	else:
		# Выводим подробную информацию об ошибке парсинга
		print("ОШИБКА ПАРСИНГА JSON в строке ", json.get_error_line(), ": ", json.get_error_message())

# Основная функция показа реплики диалога
func show_line(line_id: int):
	current_line_id = line_id  # Запоминаем текущую реплику
	var line = current_dialogue_data[line_id]  # Получаем данные реплики по ID

	# Устанавливаем текст говорящего и реплики в UI элементы
	speaker_label.text = line["speaker"]
	dialog_label.text = line["text"]

	# Очищаем старые кнопки ответов (если они есть)
	for child in options_container.get_children():
		child.queue_free()  # Безопасно удаляем кнопки

	# Создаем новые кнопки для каждого варианта ответа
	for response in line["responses"]:
		var button = Button.new()  # Создаем новую кнопку
		button.text = response["text"]  # Устанавливаем текст кнопки
		
		# Создаем локальную копию данных ответа для передачи в функцию
		var response_data = response
		# Подключаем сигнал нажатия кнопки к функции обработки
		button.pressed.connect(_on_option_selected.bind(response_data))
		
		# Добавляем кнопку в контейнер (теперь она видна игроку)
		options_container.add_child(button)

# Обработчик выбора варианта ответа игроком
func _on_option_selected(response: Dictionary):
	# ПРОВЕРЯЕМ ДОСТАТОЧНО ЛИ ДОВЕРИЯ ДЛЯ ЭТОГО ДЕЙСТВИЯ
	var has_enough_trust = RelationshipManager.sync_level >= response.get("sync_required", 0)
	
	var next_line_id = -1  # ID следующей реплики (-1 = конец диалога)
	
	if has_enough_trust:
		# Игрок выполняет приказ - доверия достаточно
		if response.has("sync_change"):
			RelationshipManager.change_sync(response["sync_change"])  # Изменяем доверие
		print("Персонаж выполнил приказ: ", response["text"])
		next_line_id = response.get("success_line", -1)  # Берем ID реплики успеха
	else:
		# Игрок ОТКАЗЫВАЕТСЯ выполнять приказ - доверия недостаточно
		var refusal_penalty = response.get("refusal_penalty", -15)
		RelationshipManager.change_sync(refusal_penalty)  # Штрафуем доверие
		print("Персонаж отказался выполнять приказ! Доверие снижено.")
		next_line_id = response.get("failure_line", -1)  # Берем ID реплики отказа
	
	# ПОЛУЧАЕМ действие которое нужно выполнить после этого выбора
	var post_action = response.get("post_action", "none")
	
	# Проверяем закончился ли диалог
	if next_line_id == -1:
		# ДИАЛОГ ЗАКОНЧЕН - выполняем указанное действие
		handle_post_dialogue_action(post_action)
		hide()  # Прячем диалоговое окно
	else:
		# Продолжаем диалог - показываем следующую реплику
		show_line(next_line_id)

# Функция обработки действий после завершения диалога
func handle_post_dialogue_action(action: String):
	print("Выполняем действие после диалога: ", action)
	
	# Сигнализируем о завершении диалога через GameStateManager
	GameStateManager.end_dialogue()
	# Выбираем что делать в зависимости от указанного действия
	match action:
		"start_battle":
			print("→ Запускаем бой")
			start_battle()
		"none":
			print("→ Диалог завершён без дополнительных действий")
			# Ничего не делаем, просто закрываем диалог
		_:
			print("→ Неизвестное действие: ", action)

# Функция перехода в боевую сцену
func start_battle():
	print("Запускаем бой после диалога...")
	var battle_scene = load("res://Scenes/Battle/BattleScene.tscn")  # Загружаем сцену боя
	get_tree().change_scene_to_packed(battle_scene)  # Переключаемся на боевую сцену
