extends Area2D
class_name Hurtbox

signal damage_taken(damage_data: DamageData, source: Node)

func _ready():
	area_entered.connect(_on_hitbox_entered)
	# Не вызываем update_layer_from_owner() здесь, 
	# потому что owner ещё не в группах

func update_layer_from_owner() -> void:
	"""Обновляет слои коллизий на основе групп владельца"""
	if not owner:
		collision_layer = 0
		collision_mask = 0
		return
	
	if owner.is_in_group("player"):
		collision_layer = 2  # Слой игрока
		collision_mask = 2
		print("Hurtbox: принадлежит игроку, слой 2")
	elif owner.is_in_group("enemies"):
		collision_layer = 4  # Слой врагов
		collision_mask = 4
		print("Hurtbox: принадлежит врагу, слой 4")
	elif owner.is_in_group("friendlies"):
		collision_layer = 2  # Слой союзников (как у игрока)
		collision_mask = 2
		print("Hurtbox: принадлежит союзнику, слой 2")
	else:
		collision_layer = 0
		collision_mask = 0
		print("Hurtbox: неизвестный владелец, слои = 0")

func _on_hitbox_entered(hitbox: Area2D):
	
	if not hitbox.has_method("get_damage_data"):
		return
	
	var damage_data = hitbox.get_damage_data()
	var source = damage_data.source

	damage_taken.emit(damage_data, source)
