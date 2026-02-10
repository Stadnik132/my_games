# AbilityResource.gd
class_name AbilityResource extends Resource

enum AbilityType {
	INSTANT,      # Мгновенная (лечение, бафф)
	PROJECTILE,   # Снаряд (огненный шар)
	AREA,         # Зонная (метеорит)
	SELF_TARGET   # На себя (берсерк)
}

# Базовые поля (загружаются из JSON)
@export var ability_id: String = ""
@export var ability_name: String = ""
@export var icon_path: String = ""
@export var description: String = ""
@export var ability_type: AbilityType = AbilityType.INSTANT
@export var unlock_level: int = 1

@export_category("Ресурсы")
@export var mana_cost: int = 0
@export var stamina_cost: int = 0
@export var health_cost: int = 0

@export_category("Время")
@export var cast_time: float = 1.0
@export var cooldown: float = 5.0
@export var channeled: bool = false

@export_category("Эффекты")
@export var damage_data_config: Dictionary = {}  # Конфиг для создания DamageData
@export var heal_amount: int = 0
@export var buff_duration: float = 10.0
@export var effect_radius: float = 100.0
@export var projectile_speed: float = 300.0

@export_category("Визуал")
@export var cast_animation: String = "cast"
@export var effect_scene_path: String = ""
@export var sound_effect_path: String = ""

# Runtime поля (не сериализуются)
var icon: Texture2D
var effect_scene: PackedScene
var sound_effect: AudioStream

func load_assets():
	"""Загружает ресурсы по путям"""
	if icon_path != "":
		icon = load(icon_path)
	if effect_scene_path != "":
		effect_scene = load(effect_scene_path)
	if sound_effect_path != "":
		sound_effect = load(sound_effect_path)

func get_damage_data() -> DamageData:
	"""Создаёт DamageData из конфига"""
	if damage_data_config.is_empty():
		return null
	
	var data = DamageData.new()
	data.damage_type = damage_data_config.get("damage_type", DamageData.DamageType.PHYSICAL)
	data.amount = damage_data_config.get("amount", 10)
	data.penetration = damage_data_config.get("penetration", 0.0)
	data.can_crit = damage_data_config.get("can_crit", false)
	data.crit_multiplier = damage_data_config.get("crit_multiplier", 1.5)
	
	return data

func can_afford(player_data: PlayerData) -> bool:
	return (player_data.current_mp >= mana_cost and
			player_data.current_stamina >= stamina_cost and
			(player_data.current_hp > health_cost or health_cost == 0))

static func from_json(json_data: Dictionary) -> AbilityResource:
	"""Создаёт AbilityResource из JSON данных"""
	var ability = AbilityResource.new()
	
	# Основные поля
	ability.ability_id = json_data.get("id", "")
	ability.ability_name = json_data.get("name", "Unnamed")
	ability.description = json_data.get("description", "")
	ability.icon_path = json_data.get("icon_path", "")
	ability.ability_type = json_data.get("type", 0)
	ability.unlock_level = json_data.get("unlock_level", 1)
	
	# Ресурсы
	ability.mana_cost = json_data.get("mana_cost", 0)
	ability.stamina_cost = json_data.get("stamina_cost", 0)
	ability.health_cost = json_data.get("health_cost", 0)
	
	# Время
	ability.cast_time = json_data.get("cast_time", 1.0)
	ability.cooldown = json_data.get("cooldown", 5.0)
	ability.channeled = json_data.get("channeled", false)
	
	# Эффекты
	ability.damage_data_config = json_data.get("damage_data", {})
	ability.heal_amount = json_data.get("heal_amount", 0)
	ability.buff_duration = json_data.get("buff_duration", 10.0)
	ability.effect_radius = json_data.get("effect_radius", 100.0)
	ability.projectile_speed = json_data.get("projectile_speed", 300.0)
	
	# Визуал
	ability.cast_animation = json_data.get("cast_animation", "cast")
	ability.effect_scene_path = json_data.get("effect_scene", "")
	ability.sound_effect_path = json_data.get("sound_effect", "")
	
	# Загружаем ресурсы
	ability.load_assets()
	
	return ability
