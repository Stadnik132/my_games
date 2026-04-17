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
var _flags: Dictionary = {
	"TestFlag": FlagData.new(true, "initial")
} # ключ: String -> FlagData

# Сигналы для отладки (опционально)
signal flag_debug_updated(flag_name: String, value: Variant, source: String)

func _ready() -> void:
	# Ждём один кадр, чтобы EventBus точно был готов
	await get_tree().process_frame
	EventBus.Dialogue.set_flag.connect(_on_dialogue_set_flag)
	# Отправляем все существующие флаги при старте
	for flag_name in _flags:
		EventBus.Flags.flag_changed.emit(flag_name, _flags[flag_name].value)
	
	print_debug("GameFlags: инициализировано, флагов: ", _flags.size())

# ==================== ОСНОВНЫЕ МЕТОДЫ ====================

# GameFlags.gd (фрагмент с исправлением)
func set_flag(flag_name: String, value: Variant = true, source: String = "unknown") -> void:
	"""
	Установить флаг.
	- flag_name: имя флага
	- value: значение
	- source: откуда установлен (по умолчанию "unknown")
	"""
	var old_value = get_flag(flag_name)
	
	_flags[flag_name] = FlagData.new(value, source)
	EventBus.Flags.flag_changed.emit(flag_name, value)
	
	if OS.is_debug_build() and old_value != value:
		print_debug("GameFlags: [", source, "] ", flag_name, " = ", value)

func get_flag(flag_name: String, default: Variant = null) -> Variant:
	"""
	Получить значение флага.
	- default: значение по умолчанию, если флаг не существует
	"""
	if _flags.has(flag_name):
		return _flags[flag_name].value
	return default

func get_flag_data(flag_name: String) -> FlagData:
	"""
	Получить полные данные флага (значение + метаданные).
	Полезно для отладки или сюжетных проверок.
	"""
	return _flags.get(flag_name)

func has_flag(flag_name: String) -> bool:
	"""
	Проверить существование флага (любое значение, кроме null).
	Для булевых флагов удобнее is_flag_true().
	"""
	return _flags.has(flag_name)

func is_flag_true(flag_name: String) -> bool:
	"""
	Проверить, что флаг существует и равен true.
	Игнорирует небулевы значения.
	"""
	if _flags.has(flag_name):
		var value = _flags[flag_name].value
		return value is bool and value == true
	return false

func is_flag_false(flag_name: String) -> bool:
	"""
	Проверить, что флаг существует и равен false.
	"""
	if _flags.has(flag_name):
		var value = _flags[flag_name].value
		return value is bool and value == false
	return false

func clear_flag(flag_name: String) -> void:
	"""Полностью удалить флаг из хранилища"""
	if _flags.erase(flag_name):
		# Отправляем null, чтобы подписчики знали, что флаг удалён
		EventBus.Flags.flag_changed.emit(flag_name, null)
		print_debug("GameFlags: флаг удалён: ", flag_name)

func toggle_flag(flag_name: String, source: String = "unknown") -> void:
	"""
	Переключить булевый флаг.
	Если флаг не существовал или не булевый — устанавливает true.
	"""
	var current = get_flag(flag_name)
	if current is bool:
		set_flag(flag_name, !current, source)
	else:
		set_flag(flag_name, true, source)

func _on_dialogue_set_flag(flag_name: String, value: Variant) -> void:
	set_flag(flag_name, value, "dialogic")

# ==================== РАБОТА С ГРУППАМИ ФЛАГОВ ====================

func get_flags_by_prefix(prefix: String) -> Dictionary:
	"""Получить все флаги, начинающиеся с префикса (например, 'quest_')"""
	var result = {}
	for flag_name in _flags:
		if flag_name.begins_with(prefix):
			result[flag_name] = _flags[flag_name].value
	return result

func get_all_flags() -> Dictionary:
	"""Получить копию всех флагов (только значения)"""
	var result = {}
	for flag_name in _flags:
		result[flag_name] = _flags[flag_name].value
	return result

func get_flags_count() -> int:
	return _flags.size()

func reset_all_flags() -> void:
	"""Очистить все флаги (осторожно!)"""
	_flags.clear()
	print_debug("GameFlags: все флаги сброшены")

# ==================== ПРОВЕРКИ ДЛЯ НАРРАТИВА ====================

func check_condition(condition: Dictionary) -> bool:
	"""
	Универсальная проверка условия для диалогов и квестов.
	condition может содержать:
	- "flag": имя флага
	- "value": ожидаемое значение (опционально)
	- "operator": "==", "!=", ">", "<", ">=", "<=", "exists", "not_exists"
	"""
	if not condition.has("flag"):
		return true  # нет флага — условие считается выполненным
	
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
	"""Сохранить все флаги (с метаданными)"""
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
	"""Загрузить флаги из сохранения"""
	_flags.clear()
	for flag_name in data:
		var flag_data = data[flag_name]
		var fd = FlagData.new(flag_data["value"], flag_data.get("source", "unknown"))
		fd.timestamp = flag_data.get("timestamp", 0)
		_flags[flag_name] = fd
	
	# После загрузки отправляем все флаги в EventBus
	for flag_name in _flags:
		EventBus.Flags.flag_changed.emit(flag_name, _flags[flag_name].value)
	
	print_debug("GameFlags: загружено флагов: ", _flags.size())
