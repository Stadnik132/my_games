extends Node


# ==================== СИГНАЛЫ ====================
signal abilities_loaded
signal ability_unlocked(ability_id: String)

# ==================== ПЕРЕМЕННЫЕ ====================
var abilities_by_id: Dictionary = {}
var unlocked_abilities: Array[String] = []


# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func _ready():
	load_abilities_from_json("res://Scripts/Ability/abilities.json")
	
	# ВРЕМЕННО: разблокировать все способности для теста
	# После отладки заменить на нормальную систему разблокировки
	_unlock_all_abilities_for_test()
	
	print("AbilityManager: загружено ", abilities_by_id.size(), " способностей")
	print("AbilityManager: разблокировано ", unlocked_abilities.size(), " способностей")

func load_abilities_from_json(json_path: String):
	if not FileAccess.file_exists(json_path):
		push_error("AbilityManager: файл не найден: ", json_path)
		return
	
	var file = FileAccess.open(json_path, FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	
	if error != OK:
		push_error("AbilityManager: ошибка парсинга JSON: ", json.get_error_message())
		return
	
	var data = json.get_data()
	if not data or not data.has("abilities"):
		push_error("AbilityManager: некорректный формат JSON")
		return
	
	# Загружаем все способности
	for ability_data in data["abilities"]:
		var ability = AbilityResource.from_json(ability_data)
		if ability:
			abilities_by_id[ability.ability_id] = ability
			ability.load_assets()
	
	abilities_loaded.emit()

# ВРЕМЕННЫЙ метод для тестирования
func _unlock_all_abilities_for_test():
	for ability_id in abilities_by_id.keys():
		if not ability_id in unlocked_abilities:
			unlocked_abilities.append(ability_id)
			print("  Разблокировано: ", ability_id)

# ==================== ОСНОВНЫЕ МЕТОДЫ ====================
func get_ability(ability_id: String) -> AbilityResource:
	return abilities_by_id.get(ability_id)

func is_ability_unlocked(ability_id: String) -> bool:
	return ability_id in unlocked_abilities

func unlock_ability(ability_id: String):
	if ability_id in unlocked_abilities:
		return
	
	if not abilities_by_id.has(ability_id):
		push_error("AbilityManager: способность не найдена: ", ability_id)
		return
	
	unlocked_abilities.append(ability_id)
	ability_unlocked.emit(ability_id)
	print("AbilityManager: разблокирована способность: ", ability_id)

func get_unlocked_abilities() -> Array[AbilityResource]:
	var result: Array[AbilityResource] = []
	for ability_id in unlocked_abilities:
		var ability = get_ability(ability_id)
		if ability:
			result.append(ability)
	return result

# ==================== СОХРАНЕНИЕ ====================
func save_data() -> Dictionary:
	return {
		"unlocked_abilities": unlocked_abilities.duplicate()
	}

func load_data(data: Dictionary) -> void:
	if data.has("unlocked_abilities"):
		unlocked_abilities = data["unlocked_abilities"].duplicate()
		print("AbilityManager: загружено ", unlocked_abilities.size(), " разблокированных способностей")
