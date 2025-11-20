# DialogueManager.gd
extends Node

# Сигналы для связи с UI и другими системами
signal dialogue_started(character_name)  # Начало диалога
signal dialogue_ended()                  # Завершение диалога  
signal line_changed(new_line)            # Смена реплики
signal options_changed(option_list)      # Смена вариантов ответа

# Переменные управления текущим диалогом
var current_dialogue: Dictionary = {}     # Данные текущего диалога из JSON
var current_line_id: String = ""          # ID текущей активной реплики
var is_dialogue_active: bool = false      # Флаг активности диалога
var completed_dialogues: Dictionary = {}  # Словарь завершенных диалогов

func _ready() -> void:
	print("DialogueManager загружен")

# Загружает диалог из JSON файла
func load_dialogue(dialogue_file: String) -> bool:
	var file = FileAccess.open(dialogue_file, FileAccess.READ)  # Открываем файл для чтения
	if file == null:  # Проверяем успешность открытия
		print("Ошибка: не могу открыть файл диалога ", dialogue_file)
		return false
		
	var json_text = file.get_as_text()  # Читаем весь текст файла
	file.close()  # Закрываем файл
	
	var json = JSON.new()  # Создаем парсер JSON
	var parse_result = json.parse(json_text)  # Парсим JSON текст
	
	if parse_result != OK:  # Проверяем ошибки парсинга
		print("Ошибка парсинга JSON: ", json.get_error_message())
		return false
		
	current_dialogue = json.data  # Сохраняем распарсенные данные
	print("Диалог загружен: ", dialogue_file)
	return true  # Успешная загрузка

# Начинает диалог с указанной начальной реплики
func start_dialogue(start_line_id: String = "start") -> void:
	GameStateManager.change_state(GameStateManager.GameState.DIALOGUE)
	current_line_id = start_line_id  # Устанавливаем начальную реплику
	is_dialogue_active = true  # Устанавливаем флаг активности
	
	emit_signal("dialogue_started", current_dialogue.get("character_name", "NPC"))  # Сигнал начала
	show_line(current_line_id)  # Показываем первую реплику

# Показывает реплику по указанному ID
func show_line(line_id: String) -> void:
	# Проверяем существование реплики
	if not current_dialogue.has("lines") or not current_dialogue["lines"].has(line_id):
		print("Ошибка: реплика с ID '", line_id, "' не найдена")
		end_dialogue()  # Завершаем диалог при ошибке
		return
		
	var line_data = current_dialogue["lines"][line_id]  # Получаем данные реплики
	
	# Проверяем триггер боя
	if line_data.has("trigger_battle") and line_data["trigger_battle"]:
		var initiator = line_data.get("battle_initiator", "player")  # Получаем инициатора
		print("Диалог запускает бой! Инициатор: ", initiator)
		trigger_battle_from_dialogue(initiator)  # Запускаем бой
		return  # Завершаем диалог
	
	emit_signal("line_changed", line_data)  # Сигнал смены реплики
	
	# Обрабатываем варианты ответа
	if line_data.has("options") and line_data["options"].size() > 0:
		var available_options = filter_options(line_data["options"])  # Фильтруем варианты
		emit_signal("options_changed", available_options)  # Показываем доступные варианты
	else:
		emit_signal("options_changed", [])  # Нет вариантов - кнопка "Продолжить"

# Фильтрует варианты ответа по условиям
func filter_options(options: Array) -> Array:
	var available_options = []  # Массив доступных вариантов
	
	for option in options:  # Проходим по всем вариантам
		var can_show = true  # Флаг доступности варианта
		
		# Проверка требуемого флага сюжета
		if option.has("required_flag"):
			var flag_name = option["required_flag"]
			if not PlayerData.story_flags.get(flag_name, false):
				can_show = false  # Флаг не установлен - вариант недоступен
				
		# Проверка требования Воли Короля
		if option.has("requires_will") and can_show:
			if not RelationshipManager.can_force_action():
				can_show = false  # Воли нет - вариант недоступен
				
		if can_show:  # Если вариант прошел проверки
			available_options.append(option)  # Добавляем в доступные
	
	return available_options

# Обрабатывает выбор варианта ответа игроком
func select_option(option_index: int) -> void:
	var current_line = current_dialogue["lines"][current_line_id]  # Текущая реплика
	var selected_option = current_line["options"][option_index]  # Выбранный вариант
	
	# Проверка требования Воли Короля
	if selected_option.has("requires_will"):
		if RelationshipManager.force_action():  # Пытаемся использовать Волю
			apply_option_effects(selected_option)  # Применяем эффекты варианта
			move_to_next_line(selected_option)  # Переходим к следующей реплике
		else:
			show_line(current_line_id)  # Остаемся на текущей реплике
		return
	
	# Проверка минимального доверия
	if selected_option.has("min_trust"):
		var player_trust = RelationshipManager.sync_level
		var required_trust = selected_option["min_trust"]
		
		if player_trust < required_trust:  # Доверия недостаточно
			if selected_option.has("on_refuse"):
				current_line_id = selected_option["on_refuse"]  # Переходим к реплике отказа
				show_line(current_line_id)
			else:
				show_line(current_line_id)  # Остаемся на текущей реплике
			return
	
	# Нормальное выполнение варианта
	apply_option_effects(selected_option)
	move_to_next_line(selected_option)

# Переходит к следующей реплике на основе выбранного варианта
func move_to_next_line(option: Dictionary) -> void:
	if option.has("next_line"):  # Если есть указание на следующую реплику
		current_line_id = option["next_line"]  # Устанавливаем следующую реплику
		show_line(current_line_id)  # Показываем следующую реплику
	else:
		end_dialogue()  # Завершаем диалог

# Применяет эффекты выбранного варианта
func apply_option_effects(option: Dictionary) -> void:
	# Изменение доверия
	if option.has("trust_effect"):
		RelationshipManager.change_trust(option["trust_effect"])
	
	# Установка флагов сюжета
	if option.has("set_flag"):
		PlayerData.set_story_flag(option["set_flag"], true)

# Завершает текущий диалог
func end_dialogue() -> void:
	GameStateManager.change_state(GameStateManager.GameState.WORLD)
	is_dialogue_active = false  # Сбрасываем флаг активности
	
	# Помечаем диалог как завершенный
	var dialogue_key = current_dialogue.get("character_name", "unknown")
	completed_dialogues[dialogue_key] = true
	
	# Очищаем данные текущего диалога
	current_dialogue = {}
	current_line_id = ""
	
	emit_signal("dialogue_ended")  # Сигнал завершения
	print("Диалог завершен")

# Запускает бой когда в диалоге срабатывает триггер
func trigger_battle_from_dialogue(initiator: String) -> void:
	print("Запуск боя из диалога. Инициатор: ", initiator)
	
	end_dialogue()  # Завершаем текущий диалог
	
	var current_npc = find_active_npc_for_battle()  # Ищем активного NPC
	if current_npc:
		if current_npc.has_method("start_battle"):
			current_npc.start_battle(initiator)  # Запускаем бой через NPC
		else:
			print("Ошибка: NPC не имеет метода start_battle")
	else:
		print("Ошибка: NPC для боя не найден!")

# Вспомогательная функция для поиска активного NPC
func find_active_npc_for_battle() -> Node:
	var npc = get_tree().get_first_node_in_group("npc_dialogue_active")  # Ищем в группе диалога
	if not npc:
		npc = get_tree().get_first_node_in_group("enemy")  # Альтернативный поиск в группе врагов
	return npc
