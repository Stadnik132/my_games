extends Node
class_name ResourceComponent

# ==================== ТИП РЕСУРСА ====================
enum ResourceType {
	MANA,
	STAMINA,
	# RAGE,        # на будущее
	# FOCUS,       # на будущее
	# ENERGY
}

# ==================== ЭКСПОРТ ====================
@export var resource_type: ResourceType = ResourceType.MANA
@export var entity_data: EntityData  # ссылка на данные игрока/сущности

# ==================== СИГНАЛЫ ====================
signal changed(new_value: int, old_value: int, max_value: int)
signal depleted()  # ресурс кончился (достиг нуля)
signal replenished()  # ресурс восполнился (был 0, стал >0)

# ==================== ПЕРЕМЕННЫЕ ====================
var _regen_accum: float = 0.0
var _was_depleted: bool = false

# ==================== ВСТРОЕННЫЕ МЕТОДЫ ====================
func _ready() -> void:
	if not entity_data:
		push_error("ResourceComponent: entity_data не назначен!")
		return
	
	# Определяем, за какой ресурс отвечаем
	match resource_type:
		ResourceType.MANA:
			entity_data.mana_changed.connect(_on_resource_changed)
		ResourceType.STAMINA:
			entity_data.stamina_changed.connect(_on_resource_changed)
	
	# Запоминаем начальное состояние
	_was_depleted = (get_current() <= 0)

func _process(delta: float) -> void:
	# Регенерация только если ресурс используется (max > 0)
	if get_max() > 0:
		_regenerate(delta)

# ==================== ОБРАБОТЧИКИ ====================
func _on_resource_changed(new_value: int, old_value: int, max_value: int) -> void:
	changed.emit(new_value, old_value, max_value)
	
	# Проверка на истощение и восполнение
	var is_depleted_now = (new_value <= 0)
	if is_depleted_now and not _was_depleted:
		depleted.emit()
	elif not is_depleted_now and _was_depleted:
		replenished.emit()
	
	_was_depleted = is_depleted_now

# ==================== ПУБЛИЧНЫЕ МЕТОДЫ ====================
func use(amount: int) -> bool:
	"""Попытаться использовать amount ресурса. Возвращает true если успешно."""
	if not entity_data:
		return false
	
	var success: bool = false
	match resource_type:
		ResourceType.MANA:
			success = entity_data.use_mana(amount)
		ResourceType.STAMINA:
			success = entity_data.use_stamina(amount)
	
	return success

func can_afford(amount: int) -> bool:
	"""Проверить, хватает ли ресурса без траты."""
	return get_current() >= amount

func add(amount: int) -> void:
	"""Добавить ресурс (восполнение)."""
	if not entity_data:
		return
	
	match resource_type:
		ResourceType.MANA:
			entity_data.set_current_mp(entity_data.current_mp + amount)
		ResourceType.STAMINA:
			entity_data.set_current_stamina(entity_data.current_stamina + amount)

func set_max(value: int) -> void:
	"""Установить максимальное значение."""
	if not entity_data:
		return
	
	match resource_type:
		ResourceType.MANA:
			entity_data.max_mp = max(0, value)
			if entity_data.current_mp > entity_data.max_mp:
				entity_data.set_current_mp(entity_data.max_mp)
		ResourceType.STAMINA:
			entity_data.max_stamina = max(0, value)
			if entity_data.current_stamina > entity_data.max_stamina:
				entity_data.set_current_stamina(entity_data.max_stamina)

func get_current() -> int:
	if not entity_data:
		return 0
	
	match resource_type:
		ResourceType.MANA:
			return entity_data.current_mp
		ResourceType.STAMINA:
			return entity_data.current_stamina
	return 0

func get_max() -> int:
	if not entity_data:
		return 0
	
	match resource_type:
		ResourceType.MANA:
			return entity_data.max_mp
		ResourceType.STAMINA:
			return entity_data.max_stamina
	return 0

func get_percentage() -> float:
	var max_val = get_max()
	if max_val <= 0:
		return 0.0
	return float(get_current()) / max_val

func is_full() -> bool:
	return get_current() >= get_max()

func is_empty() -> bool:
	return get_current() <= 0

# ==================== РЕГЕНЕРАЦИЯ ====================
func _regenerate(delta: float) -> void:
	"""Внутренний метод регенерации с накоплением."""
	var regen_rate: float = 0.0
	
	match resource_type:
		ResourceType.MANA:
			regen_rate = entity_data.mp_regen_per_second
		ResourceType.STAMINA:
			regen_rate = entity_data.stamina_regen_per_second
	
	if regen_rate <= 0:
		return
	
	_regen_accum += regen_rate * delta
	var gain = int(_regen_accum)
	
	if gain > 0:
		add(gain)
		_regen_accum -= gain
