extends EntityData
class_name PlayerData

# ==================== СПЕЦИФИЧНЫЕ ДЛЯ ИГРОКА ПОЛЯ ====================
@export var character_name: String = "Лука"
@export var ability_slot_assignments: Array[String] = ["basic_slash", "fireball", "frost_nova", "berserk"]

# Боевые параметры (специфичные для игрока)
@export var base_attack_damage: int = 15
@export var attack_cooldown: float = 0.8
@export var dodge_stamina_cost: int = 25
@export var block_damage_reduction: float = 0.5
@export var block_stamina_cost_per_second: int = 20

# Снаряжение (ID предметов)
@export var equipment: Dictionary = {
	"weapon": "",
	"armor": "",
	"accessory_1": "",
	"accessory_2": ""
}

# ==================== ПЕРЕОПРЕДЕЛЁННЫЕ МЕТОДЫ ====================
func _init():
	# Устанавливаем значения по умолчанию для игрока
	entity_name = "Luka"
	max_hp = 150
	current_hp = 100
	max_mp = 100
	current_mp = 9999  # баг? должно быть 100
	max_stamina = 9999  # баг? должно быть разумное значение
	current_stamina = 100
	mp_regen_per_second = 10.0
	stamina_regen_per_second = 20.0
	base_stats = {
		"attack": 10,
		"magic_attack": 10,
		"defense": 5,
		"magic_defense": 5,
		"speed": 10,
		"agility": 10
	}
	level = 10
	experience = 0
	experience_to_next_level = 100

# ==================== СПЕЦИФИЧНЫЕ ДЛЯ ИГРОКА МЕТОДЫ ====================
func set_ability_slot_assignment(slot_index: int, ability_id: String) -> void:
	if slot_index >= 0 and slot_index < ability_slot_assignments.size():
		ability_slot_assignments[slot_index] = ability_id

func can_dodge() -> bool:
	"""Можно ли выполнить уворот (проверка выносливости)"""
	return current_stamina >= dodge_stamina_cost

func calculate_blocked_damage(incoming_damage: int) -> int:
	"""Рассчитывает урон после блока"""
	return int(incoming_damage * (1.0 - block_damage_reduction))

func can_block() -> bool:
	"""Можно ли начать блокирование"""
	return current_stamina >= 5

# ==================== ПЕРЕОПРЕДЕЛЁННЫЕ МЕТОДЫ СОХРАНЕНИЯ ====================
func get_save_data() -> Dictionary:
	var data = super.get_save_data()
	data.merge({
		"character_name": character_name,
		"ability_slot_assignments": ability_slot_assignments.duplicate(),
		"base_attack_damage": base_attack_damage,
		"attack_cooldown": attack_cooldown,
		"dodge_stamina_cost": dodge_stamina_cost,
		"block_damage_reduction": block_damage_reduction,
		"block_stamina_cost_per_second": block_stamina_cost_per_second,
		"equipment": equipment.duplicate(true)
	})
	return data

func load_save_data(data: Dictionary) -> void:
	super.load_save_data(data)
	
	if data.has("character_name"): character_name = data.character_name
	if data.has("ability_slot_assignments"): 
		ability_slot_assignments = data.ability_slot_assignments.duplicate()
	if data.has("base_attack_damage"): base_attack_damage = data.base_attack_damage
	if data.has("attack_cooldown"): attack_cooldown = data.attack_cooldown
	if data.has("dodge_stamina_cost"): dodge_stamina_cost = data.dodge_stamina_cost
	if data.has("block_damage_reduction"): block_damage_reduction = data.block_damage_reduction
	if data.has("block_stamina_cost_per_second"): block_stamina_cost_per_second = data.block_stamina_cost_per_second
	if data.has("equipment"): equipment = data.equipment.duplicate(true)
