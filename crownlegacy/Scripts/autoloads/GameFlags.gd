# GameFlags.gd (автозагрузка)
extends Node

# Структура флага для дополнительной информации
class FlagData:
	var value: Variant
	var timestamp: int  # время установки (для отладки/сюжета)
	var source: String  # откуда установлен (диалог, квест, консоль)
	
	func _init(p_value: Variant, p_source: String = "unknown"):
		value = p_value
		timestamp = Time.get_unix_time_from_system()
		source = p_source

# Хранилище флагов (основное)
var _flags: Dictionary = {} # ключ: String -> FlagData

func _ready() -> void:
	await get_tree().process_frame
	EventBus.Dialogue.set_flag.connect(_on_dialogue_set_flag)
	for flag_name in _flags:
		EventBus.Flags.flag_changed.emit(flag_name, _flags[flag_name].value)

# ==================== ОСНОВНЫЕ МЕТОДЫ ====================

func set_flag(flag_name: String, value: Variant = true, source: String = "unknown") -> void:
	_flags[flag_name] = FlagData.new(value, source)
	EventBus.Flags.flag_changed.emit(flag_name, value)

func get_flag(flag_name: String, default: Variant = null) -> Variant:
	if _flags.has(flag_name):
		return _flags[flag_name].value
	return default

func get_flag_data(flag_name: String) -> FlagData:
	return _flags.get(flag_name)

func has_flag(flag_name: String) -> bool:
	return _flags.has(flag_name)

func is_flag_true(flag_name: String) -> bool:
	if _flags.has(flag_name):
		var value = _flags[flag_name].value
		return value is bool and value == true
	return false

func is_flag_false(flag_name: String) -> bool:
	if _flags.has(flag_name):
		var value = _flags[flag_name].value
		return value is bool and value == false
	return false

func clear_flag(flag_name: String) -> void:
	if _flags.erase(flag_name):
		EventBus.Flags.flag_changed.emit(flag_name, null)

func toggle_flag(flag_name: String, source: String = "unknown") -> void:
	var current = get_flag(flag_name)
	if current is bool:
		set_flag(flag_name, !current, source)
	else:
		set_flag(flag_name, true, source)

func _on_dialogue_set_flag(flag_name: String, value: Variant) -> void:
	set_flag(flag_name, value, "dialogic")

# ==================== РАБОТА С ГРУППАМИ ФЛАГОВ ====================

func get_flags_by_prefix(prefix: String) -> Dictionary:
	var result = {}
	for flag_name in _flags:
		if flag_name.begins_with(prefix):
			result[flag_name] = _flags[flag_name].value
	return result

func get_all_flags() -> Dictionary:
	var result = {}
	for flag_name in _flags:
		result[flag_name] = _flags[flag_name].value
	return result

func get_flags_count() -> int:
	return _flags.size()

func reset_all_flags() -> void:
	var flag_names = _flags.keys()
	_flags.clear()
	for flag_name in flag_names:
		EventBus.Flags.flag_changed.emit(flag_name, null)

# ==================== ПРОВЕРКИ ДЛЯ НАРРАТИВА ====================

func check_condition(condition: Dictionary) -> bool:
	if not condition.has("flag"):
		return true

	var flag_name = condition["flag"]
	var expected = condition.get("value")
	var operator = condition.get("operator", "==")

	var actual = get_flag(flag_name)
	
	match operator:
		"exists":
			return has_flag(flag_name)
		"not_exists":
			return not has_flag(flag_name)
		"==":
			return actual == expected
		"!=":
			return actual != expected
		">":
			return actual > expected
		"<":
			return actual < expected
		">=":
			return actual >= expected
		"<=":
			return actual <= expected
		_:
			push_warning("GameFlags: неизвестный оператор ", operator)
			return false

# ==================== СОХРАНЕНИЕ ====================

func save_data() -> Dictionary:
	var data = {}
	for flag_name in _flags:
		var fd = _flags[flag_name]
		data[flag_name] = {
			"value": fd.value,
			"source": fd.source,
			"timestamp": fd.timestamp
		}
	return data

func load_data(data: Dictionary) -> void:
	_flags.clear()
	for flag_name in data:
		var flag_data = data[flag_name]
		var fd = FlagData.new(flag_data["value"], flag_data.get("source", "unknown"))
		fd.timestamp = flag_data.get("timestamp", 0)
		_flags[flag_name] = fd

	for flag_name in _flags:
		EventBus.Flags.flag_changed.emit(flag_name, _flags[flag_name].value)
