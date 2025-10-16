# BattleUnit.gd
extends Node2D

# BattleUnit - это базовый класс, от которого будут наследоваться и игрок, и враги. Содержит общую логику для всех участников боя.

# Переменные параметров юнита
var unit_name: String
var max_hp: int
var current_hp: int
var attack_power: int
var defense_power: int

# setup_unit() - функция инициализации параметров
func setup_unit(name: String, hp: int, attack: int, defense: int):
	unit_name = name
	max_hp = hp
	current_hp = hp
	attack_power = attack
	defense_power = defense
	
# 	take_damage() - обработка получения урона
func take_damage(damage: int):
	current_hp -= damage
	current_hp = max(0, current_hp)
	print(unit_name + " получает урон: " + str(damage) + ". Осталось HP: " + str(current_hp))

# is_alive() - проверка жив ли юнит	
func is_alive () -> bool:
	return current_hp > 0
