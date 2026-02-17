# AbilityManager.gd (автозагрузка или в PlayerManager)
extends Node

var abilities_by_id: Dictionary = {}  # {ability_id: AbilityResource}
var unlocked_abilities: Array[String] = []  # ID разблокированных способностей

func _ready():
	load_abilities_from_json("res://Scripts/core/battle/Ability/abilities.json")
	
	# ТЕСТ - правильный способ
	print("=== ABILITY SYSTEM SELF-TEST ===")
	
	# 1. Проверка загрузки
	print("1. Loaded abilities: ", abilities_by_id.size())
	for id in abilities_by_id.keys():
		print("   - ", id)
	
	# 2. Проверка данных
	var fireball = get_ability("fireball")
	if fireball:
		print("2. Fireball test:")
		print("   Name: ", fireball.ability_name)
		print("   Type: ", fireball.ability_type)
		print("   Mana: ", fireball.mana_cost)
		print("   Can afford (dummy): ", fireball.can_afford(PlayerManager.player_data))
	
	print("3. Test PASSED (no runtime errors)")
	unlocked_abilities = []
	for ability_id in abilities_by_id.keys():
		unlock_ability(ability_id)
	print("Авторазблокировка всех способностей для теста")

func load_abilities_from_json(json_path: String):
	var file = FileAccess.open(json_path, FileAccess.READ)
	if not file:
		push_error("Не удалось загрузить файл способностей: ", json_path)
		return
	
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error != OK:
		push_error("Ошибка парсинга JSON: ", json.get_error_message())
		return
	
	var data = json.get_data()
	if not data or not data.has("abilities"):
		push_error("Некорректный формат JSON способностей")
		return
	
	# Загружаем все способности
	for ability_data in data["abilities"]:
		var ability = AbilityResource.from_json(ability_data)
		abilities_by_id[ability.ability_id] = ability
	
	print("Загружено способностей: ", abilities_by_id.size())

func get_ability(ability_id: String) -> AbilityResource:
	return abilities_by_id.get(ability_id)

func is_ability_unlocked(ability_id: String) -> bool:
	return ability_id in unlocked_abilities

func unlock_ability(ability_id: String):
	if not unlocked_abilities.has(ability_id):
		unlocked_abilities.append(ability_id)
		print("Разблокирована способность: ", ability_id)
		EventBus.UI.notification.emit("Разблокирована новая способность!", 3.0)

func get_unlocked_abilities() -> Array[AbilityResource]:
	var result: Array[AbilityResource] = []
	for ability_id in unlocked_abilities:
		var ability = get_ability(ability_id)
		if ability:
			result.append(ability)
	return result
