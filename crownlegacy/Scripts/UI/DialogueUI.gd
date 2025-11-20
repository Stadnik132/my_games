# DialogueUI.gd
extends CanvasLayer

# Ссылки на элементы UI
@onready var dialogue_panel = $ColorRect  # Фон диалогового окна
@onready var character_label = $ColorRect/CharacterName  # Имя персонажа
@onready var text_label = $ColorRect/DialogueText  # Текст реплики
@onready var options_container = $ColorRect/OptionsContainer  # Контейнер вариантов ответа
@onready var type_timer = $TypeTimer  # Таймер анимации печати текста

# Переменные для управления анимацией текста
var current_display_text: String = ""  # Текст который сейчас отображается
var full_text: String = ""  # Полный текст для отображения
var is_typing: bool = false  # Флаг идет ли печать текста
var typing_speed: float = 0.05  # Скорость печати (секунд на символ)

func _ready() -> void:
	hide_dialogue()  # Скрываем диалоговую панель при загрузке
	
	# Подключаемся к сигналам DialogueManager
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	DialogueManager.line_changed.connect(_on_line_changed)
	DialogueManager.options_changed.connect(_on_options_changed)
	
	# Подключаем таймер печати текста
	type_timer.timeout.connect(_on_type_timer_timeout)

func _input(event: InputEvent) -> void:
	# Обработка пробела для ускорения/продолжения диалога
	if event.is_action_pressed("ui_accept") and DialogueManager.is_dialogue_active:
		if is_typing:
			complete_typing()  # Мгновенно показываем весь текст
		else:
			# Ищем кнопку "Продолжить" и эмулируем нажатие
			for child in options_container.get_children():
				if child is Button and child.text == "Продолжить...":
					child.emit_signal("pressed")
					break

# Показать диалоговую панель
func show_dialogue() -> void:
	dialogue_panel.visible = true

# Скрыть диалоговую панель
func hide_dialogue() -> void:
	dialogue_panel.visible = false

# Обработчик начала диалога
func _on_dialogue_started(character_name: String) -> void:
	character_label.text = character_name  # Устанавливаем имя персонажа
	show_dialogue()  # Показываем диалоговую панель
	print("Диалог начался с: ", character_name)

# Обработчик завершения диалога
func _on_dialogue_ended() -> void:
	hide_dialogue()  # Скрываем диалоговую панель
	character_label.text = ""  # Очищаем имя персонажа
	text_label.text = ""  # Очищаем текст реплики
	clear_options()  # Очищаем варианты ответа
	print("Диалог завершен")

# Обработчик смены реплики
func _on_line_changed(line_data: Dictionary) -> void:
	full_text = line_data["text"]  # Сохраняем полный текст
	current_display_text = ""  # Сбрасываем текущий отображаемый текст
	text_label.text = ""  # Очищаем Label
	is_typing = true  # Устанавливаем флаг печати
	
	type_timer.wait_time = typing_speed  # Устанавливаем скорость печати
	type_timer.start()  # Запускаем таймер
	
	print("Новая реплика: ", line_data["text"])

# Обработчик смены вариантов ответа
func _on_options_changed(options: Array) -> void:
	clear_options()  # Очищаем старые варианты
	
	if options.size() == 0:  # Если вариантов нет
		add_continue_button()  # Создаем кнопку "Продолжить"
	else:  # Если есть варианты
		for i in range(options.size()):
			add_option_button(options[i], i)  # Создаем кнопки для каждого варианта

# Обработчик таймера печати текста
func _on_type_timer_timeout() -> void:
	if current_display_text.length() < full_text.length():  # Если текст не весь напечатан
		current_display_text += full_text[current_display_text.length()]  # Добавляем следующий символ
		text_label.text = current_display_text  # Обновляем Label
		type_timer.start()  # Перезапускаем таймер
	else:  # Если весь текст напечатан
		is_typing = false  # Сбрасываем флаг печати
		type_timer.stop()  # Останавливаем таймер

# Мгновенно показывает весь текст
func complete_typing() -> void:
	if is_typing:  # Проверяем идет ли печать
		current_display_text = full_text  # Устанавливаем полный текст
		text_label.text = current_display_text  # Обновляем Label
		is_typing = false  # Сбрасываем флаг печати
		type_timer.stop()  # Останавливаем таймер

# Очищает контейнер с вариантами ответа
func clear_options() -> void:
	for child in options_container.get_children():  # Проходим по всем дочерним нодам
		child.queue_free()  # Удаляем ноду

# Создает кнопку "Продолжить" (когда нет вариантов выбора)
func add_continue_button() -> void:
	var button = Button.new()  # Создаем новую кнопку
	button.text = "Продолжить..."  # Устанавливаем текст
	button.pressed.connect(_on_continue_pressed)  # Подключаем обработчик нажатия
	options_container.add_child(button)  # Добавляем в контейнер

# Создает кнопку для варианта ответа
func add_option_button(option_data: Dictionary, index: int) -> void:
	var button = Button.new()  # Создаем новую кнопку
	button.text = option_data["text"]  # Устанавливаем текст из данных варианта
	button.pressed.connect(_on_option_selected.bind(index))  # Подключаем обработчик с индексом
	options_container.add_child(button)  # Добавляем в контейнер

# Обработчик нажатия кнопки "Продолжить"
func _on_continue_pressed() -> void:
	DialogueManager.end_dialogue()  # Завершаем диалог

# Обработчик выбора варианта ответа
func _on_option_selected(option_index: int) -> void:
	DialogueManager.select_option(option_index)  # Передаем выбранный вариант
	print("Выбран вариант: ", option_index)  # Отладочная информация
