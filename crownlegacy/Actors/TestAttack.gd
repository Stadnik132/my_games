# TestAttack.gd - ИСПРАВЛЕННАЯ ВЕРСИЯ
extends Node

@export var attack_range: float = 100.0
@export var attack_damage: int = 30

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("test_attack"):
		# Проверяем состояние игры ПРОСТЫМ способом
		if _is_in_battle_state():
			_attack_nearest_enemy()
		else:
			print_debug("Атака невозможна: не в состоянии боя")

func _is_in_battle_state() -> bool:
	"""Проверяет, в состоянии ли боя ИГРА (не только Player)"""
	# Способ 1: Проверяем GameStateManager
	if Engine.has_singleton("GameStateManager"):
		var gsm = Engine.get_singleton("GameStateManager")
		# Проверяем числовое значение (BATTLE = 2)
		return gsm.get_current_state() == 2
	
	# Способ 2: Проверяем CombatManager
	var cm = get_tree().get_first_node_in_group("combat_manager")
	if cm and cm.has_method("is_in_combat"):
		return cm.is_in_combat()
	
	return false

func _attack_nearest_enemy() -> void:
	var player = get_parent()
	if not player:
		return
	
	var closest_enemy = null
	var closest_distance = attack_range
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	print_debug("Найдено врагов в группе 'enemies': ", enemies.size())
	
	# Отладочный вывод
	for enemy in enemies:
		print_debug("  - ", enemy.name, " (Actor: ", enemy is Actor, ", alive: ", 
				   enemy.is_alive() if enemy.has_method("is_alive") else "N/A", ")")
	
	for enemy in enemies:
		if enemy is Actor:
			# Проверяем, жив ли враг
			if enemy.has_method("is_alive") and not enemy.is_alive():
				continue  # Пропускаем мёртвых
				
			var distance = player.global_position.distance_to(enemy.global_position)
			print_debug("Расстояние до ", enemy.display_name, ": ", distance)
			
			if distance < closest_distance:
				closest_distance = distance
				closest_enemy = enemy
	
	# Атакуем
	if closest_enemy:
		print_debug("Атакую ", closest_enemy.display_name, 
				   " на расстоянии ", closest_distance)
		
		# Используем старый метод для совместимости
		closest_enemy.apply_combat_damage(attack_damage, player)
		
		print_debug("Игрок атаковал ", closest_enemy.display_name, 
				   " на ", attack_damage, " урона")
	else:
		print_debug("Нет живых врагов в радиусе атаки (", attack_range, ")")
