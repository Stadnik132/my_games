# EnemyFactory.gd
# Этот скрипт создаёт данные для врагов из JSON файла

extends Node

# Функция загрузки данных врагов из JSON файла
func load_enemy_data() -> Dictionary:
	# Указываем путь к нашему JSON файлу
	var file_path = "res://Data/EnemyData.json"
	
	# Пытаемся открыть файл для чтения
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	# Проверяем удалось ли открыть файл
	if file == null:
		# Если файл не найден - выводим ошибку
		print("ОШИБКА: Файл EnemyData.json не найден!")
		return {}  # Возвращаем пустой словарь
	
	# Создаём новый парсер JSON
	var json = JSON.new()
	
	# Пытаемся распарсить текст из файла
	var error = json.parse(file.get_as_text())
	
	# Проверяем успешен ли парсинг
	if error == OK:  # OK = 0 (успех)
		# Возвращаем распарсенные данные
		return json.data
	else:
		# Если ошибка парсинга - выводим сообщение
		print("ОШИБКА ПАРСИНГА JSON: ", json.get_error_message())
		return {}  # Возвращаем пустой словарь

# Функция создания врага по типу
func create_enemy(enemy_type: String) -> BattleUnitData:
	# Загружаем все данные врагов из JSON файла
	var enemy_data_dict = load_enemy_data()
	
	# Проверяем есть ли запрошенный тип врага в наших данных
	if enemy_data_dict.has(enemy_type):
		# Получаем информацию о конкретном враге
		var enemy_info = enemy_data_dict[enemy_type]
		
		# Создаём новый объект данных для врага
		var enemy_data = BattleUnitData.new()
		
		# Настраиваем параметры врага из JSON данных
		enemy_data.setup_unit(
			enemy_info["name"],      # Берём имя из JSON
			enemy_info["hp"],        # Берём HP из JSON  
			enemy_info["attack"],    # Берём атаку из JSON
			enemy_info["defense"]    # Берём защиту из JSON
		)
		
		# Возвращаем готовые данные врага
		return enemy_data
	else:
		# Если тип врага не найден в JSON - создаём стандартного врага
		print("Враг типа '", enemy_type, "' не найден в JSON. Создаю стандартного.")
		
		# Создаём данные для стандартного врага
		var enemy_data = BattleUnitData.new()
		enemy_data.setup_unit("Враг", 50, 10, 2)
		
		# Возвращаем стандартные данные
		return enemy_data
