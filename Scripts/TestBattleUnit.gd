# TestBattleUnit.gd
extends RefCounted
class_name TestBattleUnit

# Базовые свойства юнита
var unit_name: String = "Тестовый юнит"
var max_hp: int = 100
var current_hp: int = 100
var attack_power: int = 10
var defense_power: int = 2

# Функция получения урона
func take_damage(damage: int):
	current_hp -= damage
	current_hp = max(0, current_hp)  # Не даем HP уйти ниже 0
	print(unit_name + " получает урон: " + str(damage) + ". Осталось HP: " + str(current_hp))
