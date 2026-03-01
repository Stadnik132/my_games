extends EntityData
class_name ActorData

# ==================== СПЕЦИФИЧНЫЕ ДЛЯ АКТЁРА ПОЛЯ ====================
@export_category("Основные настройки")
@export var display_name: String = "NPC"
@export var actor_id: String = "unnamed_actor"
@export var dialogue_timeline: String = ""

@export_category("Режимы и поведение")
@export var initial_mode: String = "world"  # "world" или "battle"
@export var is_interactive: bool = true

@export_category("Боевые настройки")
@export var decision_triggers: Array[Dictionary] = [
	{"type": "time", "seconds": 45.0, "dialogue_timeline": "enemy_surrender"},
	{"type": "hp", "threshold": 0.3, "dialogue_timeline": "enemy_surrender"}
]

@export_category("Защита")
@export_range(0, 100, 1) var physical_defense: int = 5
@export_range(0, 100, 1) var magical_defense: int = 5

@export_category("Атака")
@export var base_damage: int = 10

func _init() -> void:
	# Значения по умолчанию для актёра
	entity_name = "Actor"
	max_hp = 100
	current_hp = 100
	# Можно не использовать ману и стамину по умолчанию
	max_mp = 0
	max_stamina = 0

# ==================== МЕТОДЫ ====================
func get_actor_info() -> Dictionary:
	return {
		"actor_id": actor_id,
		"display_name": display_name,
		"current_health": current_hp,
		"max_health": max_hp,
		"current_mode": initial_mode,
		"is_interactive": is_interactive,
		"dialogue_timeline": dialogue_timeline
	}

# Переопределяем сохранение
func get_save_data() -> Dictionary:
	var data = super.get_save_data()
	data.merge({
		"display_name": display_name,
		"actor_id": actor_id,
		"dialogue_timeline": dialogue_timeline,
		"initial_mode": initial_mode,
		"is_interactive": is_interactive,
		"decision_triggers": decision_triggers.duplicate(true),
		"physical_defense": physical_defense,
		"magical_defense": magical_defense,
		"base_damage": base_damage
	})
	return data

func load_save_data(data: Dictionary) -> void:
	super.load_save_data(data)
	
	if data.has("display_name"): display_name = data.display_name
	if data.has("actor_id"): actor_id = data.actor_id
	if data.has("dialogue_timeline"): dialogue_timeline = data.dialogue_timeline
	if data.has("initial_mode"): initial_mode = data.initial_mode
	if data.has("is_interactive"): is_interactive = data.is_interactive
	if data.has("decision_triggers"): decision_triggers = data.decision_triggers.duplicate(true)
	if data.has("physical_defense"): physical_defense = data.physical_defense
	if data.has("magical_defense"): magical_defense = data.magical_defense
	if data.has("base_damage"): base_damage = data.base_damage
