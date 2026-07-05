extends Node

const SAVE_DIR := "user://saves/"

func _ready() -> void:
	# Гарантируем, что папка сохранений существует
	var err := DirAccess.make_dir_absolute(SAVE_DIR)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_warning("SaveManager: не удалось создать каталог сохранений: %s" % SAVE_DIR)


func save_game(slot_name: String) -> void:
	if slot_name.is_empty():
		push_warning("SaveManager: пустое имя слота")
		return
	
	var save_data: Dictionary = {
		"player": PlayerManager.save_player_data() if PlayerManager.has_method("save_player_data") else {},
		"relationship": RelationshipManager.save_data() if RelationshipManager.has_method("save_data") else {},
		"game_state": GameStateManager.get_current_state() if GameStateManager.has_method("get_current_state") else GameStateManager.GameState.WORLD,
		"abilities": AbilityManager.save_data() if AbilityManager.has_method("save_data") else {},
		"flags": GameFlags.save_data() if GameFlags.has_method("save_data") else {},
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	var full_path := SAVE_DIR + slot_name + ".save"
	var file := FileAccess.open(full_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: не удалось открыть файл для записи: %s" % full_path)
		return
	
	file.store_var(save_data)
	file.flush()
	file.close()


func load_game(slot_name: String) -> void:
	if slot_name.is_empty():
		return
	
	var full_path := SAVE_DIR + slot_name + ".save"
	if not FileAccess.file_exists(full_path):
		push_warning("SaveManager: файл сохранения не найден: %s" % full_path)
		return
	
	var file := FileAccess.open(full_path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: не удалось открыть файл для чтения: %s" % full_path)
		return
	
	var save_data: Dictionary = file.get_var()
	file.close()
	
	if typeof(save_data) != TYPE_DICTIONARY:
		push_warning("SaveManager: неверный формат данных сохранения")
		return
	
	if "player" in save_data and PlayerManager.has_method("load_player_data"):
		PlayerManager.load_player_data(save_data["player"])
	
	if "relationship" in save_data and RelationshipManager.has_method("load_data"):
		RelationshipManager.load_data(save_data["relationship"])
	
	if "game_state" in save_data and GameStateManager.has_method("change_state"):
		GameStateManager.change_state(save_data["game_state"], true)

	if "abilities" in save_data and AbilityManager.has_method("load_data"):
		AbilityManager.load_data(save_data["abilities"])

	if "flags" in save_data and GameFlags.has_method("load_data"):
		GameFlags.load_data(save_data["flags"])


func delete_save(slot_name: String) -> void:
	if slot_name.is_empty():
		return
	
	var full_path := SAVE_DIR + slot_name + ".save"
	if FileAccess.file_exists(full_path):
		var err := DirAccess.remove_absolute(full_path)
		if err != OK:
			push_warning("SaveManager: не удалось удалить файл сохранения: %s" % full_path)


func reset_game() -> void:
	if PlayerManager.has_method("load_player_data"):
		PlayerManager.load_player_data({})
	if RelationshipManager.has_method("load_data"):
		RelationshipManager.load_data({ "trust_level": 0, "will_power": 3, "character_flags": [] })
	if AbilityManager.has_method("load_data"):
		AbilityManager.load_data({})
	if GameFlags.has_method("reset_all_flags"):
		GameFlags.reset_all_flags()
	if GameStateManager.has_method("change_state"):
		GameStateManager.change_state(GameStateManager.GameState.WORLD, true)


func get_save_list() -> Array:
	var saves: Array = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return saves
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".save"):
			var slot_name := file_name.trim_suffix(".save")
			
			# Пытаемся прочитать timestamp, но не падаем, если формат сломан
			var full_path := SAVE_DIR + file_name
			var time_string := ""
			var file := FileAccess.open(full_path, FileAccess.READ)
			if file != null:
				var data: Dictionary = file.get_var()
				file.close()
				if typeof(data) == TYPE_DICTIONARY and "timestamp" in data:
					time_string = str(data["timestamp"])
			
			saves.append({
				"name": slot_name,
				"time": time_string
			})
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return saves
