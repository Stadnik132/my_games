extends Resource
class_name EntityData

# ==================== БАЗОВЫЕ ПОЛЯ ====================
@export var entity_name: String = "Entity"
@export var level: int = 1
@export var experience: int = 0
@export var experience_to_next_level: int = 100

# Здоровье
@export_range(1, 9999) var max_hp: int = 100
@export_range(0, 9999) var current_hp: int = 100

# Мана (опционально — если существо её использует)
@export_range(0, 9999) var max_mp: int = 100
@export_range(0, 9999) var current_mp: int = 100
@export var mp_regen_per_second: float = 0.0

# Выносливость (опционально)
@export_range(0, 9999) var max_stamina: int = 100
@export_range(0, 9999) var current_stamina: int = 100
@export var stamina_regen_per_second: float = 0.0

# Базовые характеристики (расширяемый словарь)
@export var base_stats: Dictionary = {
	"attack": 5,
	"defense": 5,
	"speed": 5,
	"agility": 5
}

# Активные эффекты (баффы/дебаффы)
@export var active_effects: Array[Dictionary] = []

# ==================== СИГНАЛЫ (локальные, для внутреннего использования) ====================
signal health_changed(new_value: int, old_value: int, max_value: int)
signal mana_changed(new_value: int, old_value: int, max_value: int)
signal stamina_changed(new_value: int, old_value: int, max_value: int)
signal stat_changed(stat_name: String, new_value: int)
signal level_changed(new_level: int, old_level: int)
signal experience_changed(new_exp: int, old_exp: int)
signal died

# ==================== АККУМУЛЯТОРЫ РЕГЕНЕРАЦИИ ====================
var _mp_regen_accum: float = 0.0
var _stamina_regen_accum: float = 0.0

# ==================== БЕЗОПАСНЫЕ СЕТТЕРЫ ====================
func set_current_hp(value: int) -> void:
	var old_value = current_hp
	current_hp = clampi(value, 0, max_hp)
	if current_hp != old_value:
		health_changed.emit(current_hp, old_value, max_hp)
		if current_hp <= 0:
			died.emit()

func set_current_mp(value: int) -> void:
	if max_mp <= 0:
		return  # существо не использует ману
	
	var old_value = current_mp
	current_mp = clampi(value, 0, max_mp)
	if current_mp != old_value:
		mana_changed.emit(current_mp, old_value, max_mp)

func set_current_stamina(value: int) -> void:
	if max_stamina <= 0:
		return  # существо не использует выносливость
	
	var old_value = current_stamina
	current_stamina = clampi(value, 0, max_stamina)
	if current_stamina != old_value:
		stamina_changed.emit(current_stamina, old_value, max_stamina)

func set_stat(stat_name: String, value: int) -> void:
	if base_stats.has(stat_name):
		var old_value = base_stats[stat_name]
		base_stats[stat_name] = maxi(0, value)
		if base_stats[stat_name] != old_value:
			stat_changed.emit(stat_name, base_stats[stat_name])

func set_level(value: int) -> void:
	var old_level = level
	level = maxi(1, value)
	if level != old_level:
		level_changed.emit(level, old_level)

func set_experience(value: int) -> void:
	var old_exp = experience
	experience = maxi(0, value)
	if experience != old_exp:
		experience_changed.emit(experience, old_exp)

# ==================== УПРАВЛЕНИЕ РЕСУРСАМИ ====================
func use_stamina(amount: int) -> bool:
	if max_stamina <= 0:
		return true  # если выносливость не используется, считаем что успех
	
	if current_stamina >= amount:
		set_current_stamina(current_stamina - amount)
		return true
	return false

func use_mana(amount: int) -> bool:
	if max_mp <= 0:
		return true  # если мана не используется, считаем что успех
	
	if current_mp >= amount:
		set_current_mp(current_mp - amount)
		return true
	return false

func use_health(amount: int) -> bool:
	"""Использовать здоровье как ресурс (для способностей ценой HP)"""
	if current_hp > amount:
		set_current_hp(current_hp - amount)
		return true
	return false

func regenerate_resources(delta: float) -> void:
	"""Восстановление ресурсов с накоплением"""
	if max_mp > 0:
		_mp_regen_accum += mp_regen_per_second * delta
		var mp_gain = int(_mp_regen_accum)
		if mp_gain > 0:
			set_current_mp(current_mp + mp_gain)
			_mp_regen_accum -= mp_gain
	
	if max_stamina > 0:
		_stamina_regen_accum += stamina_regen_per_second * delta
		var stamina_gain = int(_stamina_regen_accum)
		if stamina_gain > 0:
			set_current_stamina(current_stamina + stamina_gain)
			_stamina_regen_accum -= stamina_gain

# ==================== ПРОВЕРКИ РЕСУРСОВ ====================
func can_afford(stamina_cost: int = 0, mana_cost: int = 0, health_cost: int = 0) -> bool:
	"""Проверка, хватает ли ресурсов"""
	if max_stamina > 0 and current_stamina < stamina_cost:
		return false
	if max_mp > 0 and current_mp < mana_cost:
		return false
	if current_hp <= health_cost:  # нельзя умереть от стоимости
		return false
	return true

# ==================== ГЕТТЕРЫ ====================
func get_stat(stat_name: String) -> int:
	return base_stats.get(stat_name, 0)

func is_alive() -> bool:
	return current_hp > 0

func get_hp_percentage() -> float:
	return float(current_hp) / max_hp if max_hp > 0 else 0.0

func get_mp_percentage() -> float:
	return float(current_mp) / max_mp if max_mp > 0 else 0.0

func get_stamina_percentage() -> float:
	return float(current_stamina) / max_stamina if max_stamina > 0 else 0.0

# ==================== СОХРАНЕНИЕ ====================
func get_save_data() -> Dictionary:
	return {
		"entity_name": entity_name,
		"level": level,
		"experience": experience,
		"experience_to_next_level": experience_to_next_level,
		"max_hp": max_hp,
		"current_hp": current_hp,
		"max_mp": max_mp,
		"current_mp": current_mp,
		"max_stamina": max_stamina,
		"current_stamina": current_stamina,
		"mp_regen_per_second": mp_regen_per_second,
		"stamina_regen_per_second": stamina_regen_per_second,
		"base_stats": base_stats.duplicate(true),
		"active_effects": active_effects.duplicate(true)
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("entity_name"): entity_name = data.entity_name
	if data.has("level"): set_level(data.level)
	if data.has("experience"): set_experience(data.experience)
	if data.has("experience_to_next_level"): experience_to_next_level = data.experience_to_next_level
	if data.has("max_hp"): max_hp = data.max_hp
	if data.has("current_hp"): set_current_hp(data.current_hp)
	if data.has("max_mp"): max_mp = data.max_mp
	if data.has("current_mp"): set_current_mp(data.current_mp)
	if data.has("max_stamina"): max_stamina = data.max_stamina
	if data.has("current_stamina"): set_current_stamina(data.current_stamina)
	if data.has("mp_regen_per_second"): mp_regen_per_second = data.mp_regen_per_second
	if data.has("stamina_regen_per_second"): stamina_regen_per_second = data.stamina_regen_per_second
	if data.has("base_stats"): base_stats = data.base_stats.duplicate(true)
	if data.has("active_effects"): active_effects = data.active_effects.duplicate(true)
