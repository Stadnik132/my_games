extends Resource
class_name PlayerData

# ==================== ЭКСПОРТИРУЕМЫЕ ДАННЫЕ ====================
@export var character_name: String = "Лука"
@export var ability_slot_assignments: Array[String] = ["basic_slash", "fireball", "frost_nova", "berserk"]

# Здоровье и ресурсы
@export_range(1, 9999, 1) var max_hp: int = 150
@export_range(0, 9999, 1) var current_hp: int = 100
@export_range(1, 9999, 1) var max_mp: int = 100
@export_range(0, 9999, 1) var current_mp: int = 9999
@export_range(0, 9999, 1) var max_stamina: int = 9999
@export_range(0, 9999, 1) var current_stamina: int = 100
@export var mp_regen_per_second: float = 10.0
@export var stamina_regen_per_second: float = 20.0
@export var block_stamina_cost_per_second: int = 20

# Характеристики
@export_range(1, 100, 1) var level: int = 10
@export_range(0, 999999, 1) var experience: int = 0
@export_range(100, 999999, 1) var experience_to_next_level: int = 100

# Базовые статы
@export var base_stats: Dictionary = {
	"attack": 10,
	"magic_attack": 10,
	"defense": 5,
	"magic_defense": 5,
	"speed": 10,
	"agility": 10
}

# Боевые параметры
@export var base_attack_damage: int = 15
@export var attack_cooldown: float = 0.8
@export var dodge_stamina_cost: int = 25
@export var block_damage_reduction: float = 0.5

# Снаряжение (ID предметов)
@export var equipment: Dictionary = {
	"weapon": "",
	"armor": "",
	"accessory_1": "",
	"accessory_2": ""
}

# Активные эффекты
@export var active_effects: Array[Dictionary] = []

# ==================== СИГНАЛЫ ====================
signal hp_changed(new_hp: int, old_hp: int)
signal mp_changed(new_mp: int, old_mp: int)
signal stamina_changed(new_stamina: int, old_stamina: int)
signal stat_changed(stat_name: String, new_value: int)
signal died
signal level_changed(new_level: int, old_level: int)
signal experience_changed(new_exp: int, old_exp: int)

# ==================== АККУМУЛЯТОРЫ РЕГЕНЕРАЦИИ ====================
var _mp_regen_accum: float = 0.0
var _stamina_regen_accum: float = 0.0

# ==================== БЕЗОПАСНЫЕ СЕТТЕРЫ ====================
func set_current_hp(value: int) -> void:
	var old_hp = current_hp
	current_hp = clampi(value, 0, max_hp)
	if current_hp != old_hp:
		hp_changed.emit(current_hp, old_hp)
		if current_hp <= 0:
			died.emit()

func set_current_mp(value: int) -> void:
	var old_mp = current_mp
	current_mp = clampi(value, 0, max_mp)
	if current_mp != old_mp:
		mp_changed.emit(current_mp, old_mp)

func set_current_stamina(value: int) -> void:
	var old_stamina = current_stamina
	current_stamina = clampi(value, 0, max_stamina)
	if current_stamina != old_stamina:
		stamina_changed.emit(current_stamina, old_stamina)

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
	if current_stamina >= amount:
		set_current_stamina(current_stamina - amount)  # ✅
		return true
	return false

func use_mana(amount: int) -> bool:
	"""Использовать ману, возвращает true если успешно"""
	if current_mp >= amount:
		set_current_mp(current_mp - amount)
		return true
	return false

func regenerate_resources(delta: float) -> void:
	"""Восстановление маны и выносливости с накоплением"""
	_mp_regen_accum += mp_regen_per_second * delta
	_stamina_regen_accum += stamina_regen_per_second * delta
	
	var mp_gain = int(_mp_regen_accum)
	var stamina_gain = int(_stamina_regen_accum)
	
	if mp_gain > 0:
		set_current_mp(current_mp + mp_gain)
		_mp_regen_accum -= mp_gain
	
	if stamina_gain > 0:
		set_current_stamina(current_stamina + stamina_gain)
		_stamina_regen_accum -= stamina_gain

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

# ==================== БОЕВЫЕ МЕТОДЫ ====================
func can_dodge() -> bool:
	"""Можно ли выполнить уворот"""
	return current_stamina >= dodge_stamina_cost

func calculate_blocked_damage(incoming_damage: int) -> int:
	"""Рассчитывает урон после блока"""
	return int(incoming_damage * (1.0 - block_damage_reduction))

func can_block() -> bool:
	"""Можно ли начать блокирование"""
	return current_stamina >= 5

func set_ability_slot_assignment(slot_index: int, ability_id: String) -> void:
	if slot_index >= 0 and slot_index < ability_slot_assignments.size():
		ability_slot_assignments[slot_index] = ability_id

# ==================== СОХРАНЕНИЕ ====================
func get_save_data() -> Dictionary:
	return {
		"character_name": character_name,
		"level": level,
		"experience": experience,
		"experience_to_next_level": experience_to_next_level,
		"current_hp": current_hp,
		"max_hp": max_hp,
		"current_mp": current_mp,
		"max_mp": max_mp,
		"current_stamina": current_stamina,
		"max_stamina": max_stamina,
		"base_stats": base_stats.duplicate(true),
		"equipment": equipment.duplicate(true),
		"active_effects": active_effects.duplicate(true),
		"ability_slot_assignments": ability_slot_assignments.duplicate()
	}

func load_save_data(data: Dictionary) -> void:
	# Явное копирование полей
	if data.has("character_name"): character_name = data.character_name
	if data.has("level"): set_level(data.level)
	if data.has("experience"): set_experience(data.experience)
	if data.has("experience_to_next_level"): experience_to_next_level = data.experience_to_next_level
	if data.has("current_hp"): set_current_hp(data.current_hp)
	if data.has("max_hp"): max_hp = data.max_hp
	if data.has("current_mp"): set_current_mp(data.current_mp)
	if data.has("max_mp"): max_mp = data.max_mp
	if data.has("current_stamina"): set_current_stamina(data.current_stamina)
	if data.has("max_stamina"): max_stamina = data.max_stamina
	if data.has("base_stats"): base_stats = data.base_stats.duplicate(true)
	if data.has("equipment"): equipment = data.equipment.duplicate(true)
	if data.has("active_effects"): active_effects = data.active_effects.duplicate(true)
	if data.has("ability_slot_assignments"): 
		ability_slot_assignments = data.ability_slot_assignments.duplicate()
