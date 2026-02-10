# TestAbilities.gd
extends Node

func _ready():
	# Проверяем загрузку
	var manager = get_node("/root/AbilityManager")
	print("Загружено способностей: ", manager.abilities_by_id.size())
	
	# Проверяем конкретную способность
	var fireball = manager.get_ability("fireball")
	if fireball:
		print("Fireball найдена:")
		print("  Name: ", fireball.ability_name)
		print("  Mana cost: ", fireball.mana_cost)
		print("  Damage: ", fireball.get_damage_data().amount if fireball.get_damage_data() else "No damage")
	
	# Проверяем AbilityComponent
	var player = get_node("/root/PlayerManager")
	if player:
		print("PlayerManager найден")
