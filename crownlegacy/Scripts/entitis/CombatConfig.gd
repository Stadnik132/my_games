extends Resource
class_name CombatConfig

@export var attack_combo_damage: Array[float] = [1.0, 1.2, 1.5, 2.0]
@export var attack_combo_window: float = 1.2
@export var attack_duration: float = 0.8
@export var cancel_window_start: float = 0.1
@export var dodge_distance: float = 200.0
@export var dodge_duration: float = 0.3
@export var dodge_collider_radius: float = 15.0
@export var dodge_stamina_cost: int = 25
@export var attack_idle_inside_duration: float = 3.0
@export var move_speed: float = 200.0
@export var acceleration: float = 15.0
@export var friction: float = 20.0
@export var block_damage_reduction: float = 0.5
@export var block_base_stamina_cost: int = 5
@export var block_stamina_damage_factor: float = 0.2
@export var stun_duration: float = 0.5
@export var attack_hitbox_offset: float = 15.0  # дистанция спавна хитбокса
