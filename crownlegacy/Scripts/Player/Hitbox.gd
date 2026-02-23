# Не привязан. Нужна реализация.
extends Area2D
class_name Hitbox

# Зона урона. Hurtbox при area_entered вызывает get_damage_data() и применяет урон.
# Слой хитбокса зависит от владельца:
# - если владелец в группе "player", бьём врагов → слой 4
# - если владелец в группе "enemies", бьём игрока → слой 2

var damage_data: DamageData

func get_damage_data() -> DamageData:
	return damage_data

func set_damage_data(data: DamageData) -> void:
	damage_data = data
func _ready() -> void:
	_update_layer_from_owner()

func _update_layer_from_owner() -> void:
	if not owner:
		collision_layer = 0
		collision_mask = 0
		return
	
	# Владелец — игрок: бьём врагов (их Hurtbox на слое 4)
	if owner.is_in_group("player"):
		collision_layer = 4
		collision_mask = 0
	
	# Владелец — враг: бьём игрока (его Hurtbox на слое 2)
	elif owner.is_in_group("enemies"):
		collision_layer = 2
		collision_mask = 0
	
	# На всякий случай для других типов — выключаем
	else:
		collision_layer = 0
		collision_mask = 0
