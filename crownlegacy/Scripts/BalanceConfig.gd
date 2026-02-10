# BalanceConfig.gd
extends Resource
class_name BalanceConfig

# ==================== СИСТЕМА ДОВЕРИЯ ====================
@export_category("01. Система доверия")
@export_range(-100, 100) var initial_trust: int = 50
@export_range(0, 10) var initial_will: int = 3
@export var force_action_trust_penalty: int = 25
@export var trust_damage_multiplier: float = 0.005
@export var trust_dodge_chance: float = 0.001
@export var min_refusal_chance: float = 0.0
@export var max_refusal_chance: float = 0.5
#GameFlags.gd

# ==================== ПЕРЕМЕЩЕНИЕ ====================
@export_category("02. Перемещение")
@export var walk_speed: float = 200.0
@export var run_speed: float = 350.0
@export var acceleration: float = 15.0
@export var friction: float = 20.0

# ==================== БОЙ ====================
@export_category("03. Бой")
@export var attack_cooldown: float = 0.8
@export var dodge_cooldown: float = 0.5
@export var max_stamina: int = 100
@export var stamina_regen: int = 10
@export var base_physical_defense: int = 5
@export var base_magic_defense: int = 5

# ==================== ПРОГРЕССИЯ ====================
@export_category("04. Прогрессия")
@export var level_exp_multiplier: float = 1.5
@export var hp_per_level: int = 20
@export var mp_per_level: int = 10
@export var stats_per_level: Dictionary = {
	"attack": 2,
	"magic_attack": 2,
	"defense": 1,
	"magic_defense": 1,
	"speed": 1,
	"agility": 1,
	"stamina": 5
}
@export var base_experience: Dictionary = {
	"weak": 10,
	"normal": 25,
	"strong": 50,
	"boss": 200
}
