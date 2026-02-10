# PlayerData.gd (единый стиль)
extends Resource
class_name PlayerData

# ==================== ЭКСПОРТИРУЕМЫЕ ДАННЫЕ ====================
@export var character_name: String = "Клоус"
@export var ability_slot_assignments: Array[String] = ["basic_slash", "fireball", "frost_nova", "berserk"]


# Здоровье и ресурсы
@export_range(1, 9999, 1) var max_hp: int = 150
@export_range(0, 9999, 1) var current_hp: int = 100
@export_range(1, 9999, 1) var max_mp: int = 999
@export_range(0, 9999, 1) var current_mp: int = 999
@export_range(0, 9999, 1) var max_stamina: int = 100
@export_range(0, 9999, 1) var current_stamina: int = 100
@export var mp_regen_per_second: float = 10.0
@export var stamina_regen_per_second: float = 20.0

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

# Боевые параметры (новое!)
@export var base_attack_damage: int = 10
@export var attack_cooldown: float = 0.8
@export var dodge_stamina_cost: int = 25
@export var block_damage_reduction: float = 0.5

# Снаряжение
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

# ==================== БЕЗОПАСНЫЕ СЕТТЕРЫ ====================
func set_current_hp(value: int) -> void:
	var old_hp = current_hp
	current_hp = clamp(value, 0, max_hp)
	if current_hp != old_hp:
		hp_changed.emit(current_hp, old_hp)
		if current_hp <= 0:
			died.emit()

func set_current_mp(value: int) -> void:
	var old_mp = current_mp
	current_mp = clamp(value, 0, max_mp)
	if current_mp != old_mp:
		mp_changed.emit(current_mp, old_mp)

func set_current_stamina(value: int) -> void:
	var old_stamina = current_stamina
	current_stamina = clamp(value, 0, max_stamina)
	if current_stamina != old_stamina:
		stamina_changed.emit(current_stamina, old_stamina)

func set_stat(stat_name: String, value: int) -> void:
	if base_stats.has(stat_name):
		var old_value = base_stats[stat_name]
		base_stats[stat_name] = max(0, value)
		if base_stats[stat_name] != old_value:
			stat_changed.emit(stat_name, base_stats[stat_name])

# ==================== УПРАВЛЕНИЕ РЕСУРСАМИ ====================
func use_stamina(amount: int) -> bool:
	"""Использовать выносливость, возвращает true если успешно"""
	if current_stamina >= amount:
		set_current_stamina(current_stamina - amount)
		return true
	return false

func use_mana(amount: int) -> bool:
	"""Использовать ману, возвращает true если успешно"""
	if current_mp >= amount:
		set_current_mp(current_mp - amount)
		return true
	return false

func regenerate_resources(delta: float) -> void:
	"""Восстановление маны и выносливости (вызывать каждый кадр)"""
	var old_mp = current_mp
	var old_stamina = current_stamina
	
	# Восстановление
	current_mp = min(max_mp, current_mp + int(mp_regen_per_second * delta))
	current_stamina = min(max_stamina, current_stamina + int(stamina_regen_per_second * delta))
	
	# Сигналы при изменении
	if current_mp != old_mp:
		mp_changed.emit(current_mp, old_mp)
	if current_stamina != old_stamina:
		stamina_changed.emit(current_stamina, old_stamina)

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
	# Проверяем есть ли минимум выносливости для начала блока
	return current_stamina >= 5

func set_ability_slot_assignment(slot_index: int, ability_id: String):
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
	for key in data.keys():
		if key in self:
			set(key, data[key])
			if data.has("ability_slot_assignments"):
				ability_slot_assignments = data["ability_slot_assignments"].duplicate()
