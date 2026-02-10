# TestAbilityComponent.gd
extends Node

@onready var ability_component = $"../Player/AbilityComponent"

func _ready():
	print("=== AbilityComponent Test ===")
	print("Слотов: ", ability_component.slots.size())
	
	for i in range(ability_component.slots.size()):
		var ability = ability_component.get_ability_in_slot(i)
		if ability:
			print("Слот ", i, ": ", ability.ability_name)
			print("  Можно кастовать: ", ability_component.can_cast_ability(i))
		else:
			print("Слот ", i, ": пустой")
	
	# Тест каста
	if ability_component.can_cast_ability(0):
		print("\nПробуем кастовать слот 0...")
		ability_component.cast_ability(0, Vector2(100, 100))
