extends Resource
class_name CombatConfig

@export var attack_combo_damage: Array[float] = [1.0, 1.2, 1.5, 2.0]
@export var attack_combo_window: float = 1.2
@export var attack_duration: float = 0.8
@export var attack_variance_pct: float = 0.2
@export var cancel_window_start: float = 0.1
@export var dodge_distance: float = 40.0
@export var dodge_duration: float = 0.4
@export var dodge_stamina_cost: int = 25
@export var move_speed: float = 80.0
@export var acceleration: float = 15.0
@export var friction: float = 20.0
@export var block_base_stamina_cost: int = 5
@export var block_stamina_damage_factor: float = 0.2
@export var stun_duration: float = 0.5
@export var micro_stun_duration: float = 0.15
@export var attack_hitbox_offset: float = 15.0  # дистанция спавна хитбокса

# === КРИТ И ПРОБИТИЕ ===
@export var can_crit: bool = false
@export var crit_chance: float = 0.05
@export var crit_multiplier: float = 2.0
@export var penetration: float = 0.0

# === ДВИЖЕНИЕ ПРИ АТАКЕ ===
@export var attack_lunge_duration: float = 0.3   # длительность выпада
@export var attack_lunge_distance: float = 30.0  # дистанция выпада
@export var attack_combo_lunge: Array[float] = [20.0, 20.0, 20.0, 30.0]  # в расчёте на шаг комбо

# === ОГЛУШЕНИЕ / СТОЙКОСТЬ ===
@export var base_poise_damage: int = 20  # базовый урон по стойкости у обычной атаки
@export var combo_finisher_poise_damage: int = 40  # урон по стойкости у финального удара

# === ОТБРАСЫВАНИЕ ===
@export var base_knockback_distance: float = 15.0  # обычное отбрасывание
@export var combo_finisher_knockback_distance: float = 40.0  # отбрасывание при финальном ударе комбо
@export var knockback_duration: float = 0.25  # длительность отбрасывания
