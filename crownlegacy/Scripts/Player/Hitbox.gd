# Не привязан. Нужна реализация.
extends Area2D
class_name Hitbox

# Зона урона. Hurtbox при area_entered вызывает get_damage_data() и применяет урон.
# Настрой: collision_layer = 2 (слой hitbox), collision_mask = 0 (маска задаётся у Hurtbox на слой 2).

var damage_data: DamageData

func get_damage_data() -> DamageData:
	return damage_data

func set_damage_data(data: DamageData) -> void:
	damage_data = data

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
