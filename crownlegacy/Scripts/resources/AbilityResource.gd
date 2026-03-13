class_name AbilityResource extends Resource

enum AbilityType { INSTANT, PROJECTILE, AREA, SELF_TARGET }
enum AimingType { NONE, AREA, PROJECTILE, SELF }

# Базовые поля
@export var ability_id: String = ""
@export var ability_name: String = ""
@export var icon_path: String = ""
@export var description: String = ""
@export var ability_type: AbilityType = AbilityType.INSTANT
@export var aiming_type: AimingType = AimingType.NONE

# Требования
@export var unlock_level: int = 1
@export var mana_cost: int = 0
@export var stamina_cost: int = 0
@export var health_cost: int = 0

# Время
@export var cast_time: float = 1.0
@export var cooldown: float = 5.0
@export var channeled: bool = false

# Параметры урона/эффектов
@export var damage_data_config: Dictionary = {}  # для JSON
@export var heal_amount: int = 0
@export var buff_duration: float = 10.0
@export var buff_stats: Dictionary = {}  # для баффов {"attack": 20, "speed": 50}

# Параметры эффекта (общие)
@export var projectile_speed: float = 300.0     # для PROJECTILE
@export var effect_radius: float = 100.0        # для AREA/INSTANT (ближний бой)
@export var effect_duration: float = 0.5        # для AREA/INSTANT
@export var max_cast_range: float = 500.0       # для прицеливания

# ЕДИНАЯ сцена эффекта
@export var effect_scene_path: String = ""      # путь к сцене
@export var effect_scene: PackedScene           # загруженная сцена

# Визуал прицеливания (опционально)
@export var visual_scene_path: String = ""
@export var visual_scene: PackedScene
@export var targeting_color: Color = Color(1, 0, 0, 0.3)

# Анимация и звук
@export var cast_animation: String = "cast"
@export var sound_effect_path: String = ""
var sound_effect: AudioStream

# Загруженные ассеты (для обратной совместимости)
var icon: Texture2D

func load_assets() -> void:
	"""Загружает ассеты по путям"""
	if icon_path != "" and not icon:
		icon = load(icon_path)
	
	if effect_scene_path != "" and not effect_scene:
		effect_scene = load(effect_scene_path)
	
	if visual_scene_path != "" and not visual_scene:
		visual_scene = load(visual_scene_path)
	
	if sound_effect_path != "" and not sound_effect:
		sound_effect = load(sound_effect_path)

func get_damage_data() -> DamageData:
	"""Создаёт DamageData из конфига"""
	if damage_data_config.is_empty():
		return null
	
	var data = DamageData.new()
	
	if damage_data_config.has("damage_type"):
		data.damage_type = damage_data_config["damage_type"] as DamageData.DamageType
	if damage_data_config.has("amount"):
		data.amount = damage_data_config["amount"]
	if damage_data_config.has("penetration"):
		data.penetration = damage_data_config["penetration"]
	if damage_data_config.has("can_crit"):
		data.can_crit = damage_data_config["can_crit"]
	if damage_data_config.has("crit_multiplier"):
		data.crit_multiplier = damage_data_config["crit_multiplier"]
	
	return data

func can_afford(health: HealthComponent, mana: ResourceComponent, stamina: ResourceComponent) -> bool:
	if health and health.get_current_health() <= health_cost:
		return false
	if mana and mana.get_current() < mana_cost:
		return false
	if stamina and stamina.get_current() < stamina_cost:
		return false
	return true

func get_aiming_visual_scene() -> PackedScene:
	"""Возвращает сцену для визуала прицеливания"""
	load_assets()
	
	# Если есть кастомная сцена - используем её
	if visual_scene:
		return visual_scene
	
	# Иначе возвращаем стандартную в зависимости от типа
	match aiming_type:
		AimingType.AREA:
			return load("res://Scenes/abilities/area_aiming_visual.tscn")
		AimingType.PROJECTILE:
			return load("res://Scenes/abilities/projectile_aiming_visual.tscn")
		_:
			return null

static func from_json(json_data: Dictionary) -> AbilityResource:
	"""Создаёт AbilityResource из JSON"""
	var ability = AbilityResource.new()
	
	# Базовые поля
	ability.ability_id = json_data.get("id", "")
	ability.ability_name = json_data.get("name", "")
	ability.description = json_data.get("description", "")
	ability.icon_path = json_data.get("icon_path", "")
	ability.ability_type = json_data.get("type", 0) as AbilityType
	
	# Определяем тип прицеливания на основе типа способности
	match ability.ability_type:
		AbilityType.INSTANT:
			ability.aiming_type = AimingType.AREA
		AbilityType.PROJECTILE:
			ability.aiming_type = AimingType.PROJECTILE
		AbilityType.AREA:
			ability.aiming_type = AimingType.AREA
		AbilityType.SELF_TARGET:
			ability.aiming_type = AimingType.SELF
	
	# Требования и время
	ability.unlock_level = json_data.get("unlock_level", 1)
	ability.mana_cost = json_data.get("mana_cost", 0)
	ability.stamina_cost = json_data.get("stamina_cost", 0)
	ability.health_cost = json_data.get("health_cost", 0)
	ability.cast_time = json_data.get("cast_time", 1.0)
	ability.cooldown = json_data.get("cooldown", 5.0)
	ability.channeled = json_data.get("channeled", false)
	
	# Параметры эффектов
	ability.damage_data_config = json_data.get("damage_data", {})
	ability.heal_amount = json_data.get("heal_amount", 0)
	ability.buff_duration = json_data.get("buff_duration", 10.0)
	ability.buff_stats = json_data.get("buff_stats", {})
	
	# Параметры эффекта
	ability.projectile_speed = json_data.get("projectile_speed", 300.0)
	ability.effect_radius = json_data.get("effect_radius", 100.0)
	ability.effect_duration = json_data.get("effect_duration", 0.5)
	ability.max_cast_range = json_data.get("max_cast_range", 500.0)
	
	# ЕДИНАЯ сцена эффекта
	ability.effect_scene_path = json_data.get("effect_scene", "")
	
	# Визуал прицеливания
	ability.visual_scene_path = json_data.get("visual_scene", "")
	ability.targeting_color = json_data.get("targeting_color", Color(1, 0, 0, 0.3))
	
	# Анимация и звук
	ability.cast_animation = json_data.get("cast_animation", "cast")
	ability.sound_effect_path = json_data.get("sound_effect", "")
	
	return ability
