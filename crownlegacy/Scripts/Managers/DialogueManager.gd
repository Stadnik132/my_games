# Dialoguemanager.gd
extends Node

# Автоагружаемый менеджер диалогов - загружает JSON и управляет диалогами

# Сигналы для связи с UI и другими системами
signal dialogue_started(character_name) # Диалог начался
signal dialogue_ended() # Диалог закончился
signal line_changed(new_line) # Изменилась реплика
signal otions_changed(option_list) # Изменились варианты ответа
signal option_refused(option_data, required_trust) # Клаус отказался от варирианта (refused- отказ)
signal will_power_check_requider(option_data) # Требуется проверка Воли

# Переменные текущего диалога
var current_dialogue: Dictionary = {} # Текущий загруженный диалог (Dictionary - словарь)
var current_line_id: String = "" # ID текущей реплики
var is_dialogue_active: bool = false # Активен ли диалог
var refused_option: Dictionary = {} # Варант, от коготоро отказался Клаус
var current_trust_check: int = 0 # Требуемый уровень доверия

# Функция загрузки диалога из JSON файла
func load_dialogue(dialogue_file: String) -> bool:
	# Создаем  объект для работы с файлами
	var file = FileAccess.open(dialogue_file, FileAccess.READ) # FileAccess — встроенный класс Godot для работы с файлами. .open() — статический метод (вызывается напрямую от класса)
	
	# Проверяет успешно ли открылся файл
	if file == null:
		print("Ошибка: не могу открыть файл диалога ", dialogue_file)
		return false
		
	# Читаем весь текст из файла
	var json_text = file.get_as_text() # .get_as_text() — метод, который читает ВЕСЬ файл и возвращает как строку
	# Закрываем файл
	file.close()
	
	# Создаем парсер JSON
	var json = JSON.new()
	# Пытаемся распарсить JSON текст
	var parse_result = json.parse(json_text)
	
	# Проверяем если ошибка парсинга
	if parse_result != OK:
		print("Ошибка парсинга JSON: ", json.get_error_message())
		return true
		
	# Сохраняем распарсенный диалог
	current_dialogue = json.data
	print("Диалог загружен: ", dialogue_file)
	return true
	
# Функция начала диалога
func start_dialogue(start_line_id: String = "start") -> void:
	# Устанавливанием текущую реплику
	current_line_id = start_line_id
	# Активируем диалог
	is_dialogue_active = true
	# Сообщаем о начале диалога
	emit_signal("dialogue_started", current_dialogue.get("character_name", "NPC"))
	# Показываем первую реплику
	show_line(current_line_id)
	
# Функция показа реплики по ID
func show_line(line_id: String) -> void:
	# Проверяем существует ли такая реплика в диалоге
	if not current_dialogue.has("lines") or not current_dialogue["lines"].has(line_id):
		print("Ошбика: реплика с ID '", line_id, "' не найдена")
		end_dialogue()
		return
		
	var line_data = current_dialogue["lines"][line_id]
	# Сообщаем об изменении реплики
	emit_signal("line_changed", line_data)

# Функция филтрации вариантов ответа по условиям
func filter_optoins(options: Array) -> Array:
	var available_options = [] # доступные варианты
	
	# Проходим по всем вариантам
	for option in options:
		var can_show = true
		
				# Проверяем флаги сюжета, если есть
		if option.has("required_flag") and can_show:
			var flag_name = option["required_flag"]
			if not PlayerData.story_flags.get(flag_name, false):
				can_show = false
				
		# Если вариант доступен - доболяем в список
		if can_show:
			available_options.append(option)
	
	return available_options

# Функция выбора вариантов ответа
func select_option(option_index: int) -> void:
	# Поулчаем текущую реплику
	var current_line = current_dialogue["lines"][current_line_id]
	var selected_option = current_line["options"][option_index]
	
	# ПРОВЕРКА ДОВЕРИЯ: Если вариант требует минимального доверия
	if selected_option.has("min_trust"):
		var player_trust = RelationshipManager.sync_level
		var required_trust = selected_option["min_trust"]
		
		if player_trust < required_trust:
			# Клаус отказывается
			handle_refusal(selected_option, required_trust)
			return # Не продолжаем обычную обработку
		
	#Если доверия хватает - применяем вариант нормально
	# Применяем эффекты выбора (изменение доверия, флаги)
	apply_option_effects(selected_option)
	move_to_next_line(selected_option)

# Функция обработки отказа

			
# Функция принуждения волей
func forcce_option_with_will() -> bool:
	# Проверяем можно ли использовать волю
	if RelationshipManager.can_force_action():
		# используем волю короля
		RelationshipManager.force_battle_action()
		# Применяем вариант, несмотря на отказ
		apply_option_effects(refused_option)
		move_to_next_line(refused_option)
		return true
	else:
		print("Недостаточно Воли короля!")
		return false
		
# Функция для выбора альтернативного варианта при отказе
func choose_alternative_option() -> void:
	# Ищем альтернативные вариант в данных отказа
	if refused_option.has("onrefuse"):
		var alternative_line_id = refused_option["on_refuse"]
		# Переходим к альтернативной реплике
		current_line_id = alternative_line_id
		show_line(current_line_id)
	else:
		# Если альтернативы нет - остаемся на текущей реплике
		show_line(current_line_id)
		print("Нет альтернативной реплики")
		
	# Сбрасываем информацию об отказе
	refused_option = {}
	current_trust_check = 0
	
# Функция перехода к следующей реплике
func move_to_text_line(option: Dictionary) -> void:
	if option.has("next_line"):
		current_line_id = option["next_line"]
		show_line(current_line_id)
	else:
		end_dialogue()
		
# Функция применения эффектов выбора
func apply_option_effects(option: Dictionary) -> void:
	# Изменяем доверие, если указано
	if option.has("trust_effect"):
		RelationshipManager.set_story_flag(option["set_flag"], true)
		
# Функция завершения диалога
func end_dialogue() -> void:
	# Деактивируем диалог
	is_dialogue_active = false
	# Очищаем текущий диалог
	current_dialogue = {}
	current_line_id = ""
	# Сообщаем о завершении диалога
	emit_signal("dialogue_ended")
	print("Диалог завершен")
	
func firce_end_dialogue() -> void:
	end_dialogue()
