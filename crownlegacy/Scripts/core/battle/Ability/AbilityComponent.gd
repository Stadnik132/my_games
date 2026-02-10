class_name AbilityComponent extends Node

# Начальные назначения слотов (можно менять в редакторе)
@export var initial_slot_assignments: Array[String] = ["basic_slash", "fireball", "frost_nova", "berserk"]

# Внутренние массивы
var slots: Array[AbilityResource] = []           # AbilityResource в слотах
var slot_assignments: Array[String] = []        # ID способностей в слотах
var cooldowns: Dictionary = {}                  # Кулдауны по индексам {0: 2.5, 1: 0.0, ...}

# Ссылки
var player_data: PlayerData
@onready var ability_manager = get_node("/root/AbilityManager")

func _ready():
	player_data = PlayerManager.player_data
	
	# Инициализация слотов
	_initialize_slots()
	
	print("AbilityComponent: инициализировано ", slots.size(), " слотов")
	print("Слоты: ", slot_assignments)

func _initialize_slots():
	slots.clear()
	slot_assignments = initial_slot_assignments.duplicate()
	
	for i in range(slot_assignments.size()):
		var ability_id = slot_assignments[i]
		
		if ability_id != "" and ability_manager.is_ability_unlocked(ability_id):
			var ability = ability_manager.get_ability(ability_id)
			slots.append(ability)
			print("  Слот ", i, ": ", ability.ability_name)
		else:
			slots.append(null)
			print("  Слот ", i, ": ПУСТОЙ (id='", ability_id, "')")
		
		cooldowns[i] = 0.0

func _process(delta: float):
	# Обновляем кулдауны
	for slot_index in cooldowns.keys():
		if cooldowns[slot_index] > 0:
			cooldowns[slot_index] = max(0, cooldowns[slot_index] - delta)
			_update_ui(slot_index)

# ==================== ОСНОВНЫЕ МЕТОДЫ ====================
func get_ability_in_slot(slot_index: int) -> AbilityResource:
	if slot_index < 0 or slot_index >= slots.size():
		return null
	return slots[slot_index]

func set_ability_in_slot(slot_index: int, ability_id: String) -> bool:
	"""Назначить способность в слот (возвращает успех)"""
	if slot_index < 0 or slot_index >= slots.size():
		return false
	
	# Проверяем что способность разблокирована
	if ability_id != "" and not ability_manager.is_ability_unlocked(ability_id):
		print("Способность не разблокирована: ", ability_id)
		return false
	
	# Назначаем
	slot_assignments[slot_index] = ability_id
	
	if ability_id != "":
		slots[slot_index] = ability_manager.get_ability(ability_id)
	else:
		slots[slot_index] = null
	
	print("Слот ", slot_index, " назначена способность: ", ability_id)
	
	# Сохраняем в PlayerData
	if player_data.has_method("set_ability_slot_assignment"):
		player_data.set_ability_slot_assignment(slot_index, ability_id)
	
	return true

func can_cast_ability(slot_index: int) -> bool:
	"""Можно ли использовать способность в слоте"""
	var ability = get_ability_in_slot(slot_index)
	if not ability:
		return false
	
	# Проверка кулдауна
	if is_on_cooldown(slot_index):
		return false
	
	# Проверка ресурсов
	if not ability.can_afford(player_data):
		return false
	
	return true

func is_on_cooldown(slot_index: int) -> bool:
	return cooldowns.get(slot_index, 0) > 0

func get_cooldown_percentage(slot_index: int) -> float:
	var ability = get_ability_in_slot(slot_index)
	if not ability or ability.cooldown == 0:
		return 1.0
	
	var remaining = cooldowns.get(slot_index, 0)
	return 1.0 - (remaining / ability.cooldown)

func start_cooldown(slot_index: int):
	"""Запустить кулдаун для слота"""
	var ability = get_ability_in_slot(slot_index)
	if ability:
		cooldowns[slot_index] = ability.cooldown
		_update_ui(slot_index)

func cast_ability(slot_index: int, target_position: Vector2 = Vector2.ZERO) -> bool:
	"""Использовать способность (возвращает успех)"""
	if not can_cast_ability(slot_index):
		return false
	
	var ability = get_ability_in_slot(slot_index)
	
	# Расход ресурсов
	if ability.mana_cost > 0:
		player_data.set_current_mp(player_data.current_mp - ability.mana_cost)
	if ability.stamina_cost > 0:
		player_data.set_current_stamina(player_data.current_stamina - ability.stamina_cost)
	if ability.health_cost > 0:
		player_data.set_current_hp(player_data.current_hp - ability.health_cost)
	
	start_cooldown(slot_index)
	
	# Сигнал о начале каста
	EventBus.Combat.ability_cast_started.emit(ability)
	
	# Анимация каста (если есть)
	if ability.cast_animation != "":
		EventBus.Player.animation_requested.emit(ability.cast_animation, ability.cast_time)
	
	# Таймер для фактического применения эффекта
	await get_tree().create_timer(ability.cast_time).timeout
	
	# Применение эффекта
	_apply_ability_effect(ability, target_position)
	
	# Сигнал о завершении
	EventBus.Combat.ability_cast_completed.emit()
	
	return true

func _apply_ability_effect(ability: AbilityResource, target_position: Vector2):
	"""Применяет эффект способности"""
	match ability.ability_type:
		AbilityResource.AbilityType.INSTANT:
			var damage_data = ability.get_damage_data()
			if damage_data:
				_apply_damage_effect(ability, target_position)
			elif ability.heal_amount > 0:
				_apply_heal_effect(ability)
		
		AbilityResource.AbilityType.PROJECTILE:
			_spawn_projectile(ability, target_position)
		
		AbilityResource.AbilityType.AREA:
			_create_area_effect(ability, target_position)
		
		AbilityResource.AbilityType.SELF_TARGET:
			_apply_self_buff(ability)

func _apply_damage_effect(ability: AbilityResource, target_position: Vector2):
	print("=== APPLY DAMAGE EFFECT ===")
	print("Способность: ", ability.ability_name)
	print("Цель: ", target_position)
	print("Радиус: ", ability.effect_radius)
	
	var damage_data = ability.get_damage_data()
	if not damage_data:
		print("  -> Нет damage_data!")
		return
	
	print("Урон: ", damage_data.amount, " (тип: ", damage_data.get_damage_type_name(), ")")
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	print("Найдено врагов: ", enemies.size())
	
	for i in range(enemies.size()):
		var enemy = enemies[i]
		var distance = enemy.global_position.distance_to(target_position)
		print("  Враг ", i, ": позиция ", enemy.global_position, ", дистанция ", distance)
		
		if distance <= ability.effect_radius:
			if enemy.has_method("apply_combat_damage_data"):
				print("    -> ПОПАДАНИЕ! Наносим урон")
				enemy.apply_combat_damage_data(damage_data, get_parent())
			else:
				print("    -> Враг не имеет метода apply_combat_damage_data")

func _apply_heal_effect(ability: AbilityResource):
	player_data.set_current_hp(player_data.current_hp + ability.heal_amount)
	EventBus.Player.healed.emit(ability.heal_amount, player_data.current_hp)

func _spawn_projectile(ability: AbilityResource, target_position: Vector2):
	"""Временный снаряд (без сцены)"""
	print("PROJECTILE: ", ability.ability_name, " в ", target_position)
	
	var damage_data = ability.get_damage_data()
	if not damage_data:
		return
	
	# Простая проверка попадания по ближайшему врагу
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest_enemy = null
	var closest_distance = INF
	
	for enemy in enemies:
		var distance = enemy.global_position.distance_to(target_position)
		if distance < closest_distance and distance <= ability.effect_radius:
			closest_distance = distance
			closest_enemy = enemy
	
	if closest_enemy and closest_enemy.has_method("apply_combat_damage_data"):
		closest_enemy.apply_combat_damage_data(damage_data, get_parent())
		print("Снаряд попал в врага")
		EventBus.Combat.enemy_hit.emit(closest_enemy, damage_data.amount, false)

func _create_area_effect(ability: AbilityResource, target_position: Vector2):
	"""Временная зонная атака"""
	print("AREA: ", ability.ability_name, " в ", target_position)
	
	var damage_data = ability.get_damage_data()
	if not damage_data:
		return
	
	# Проверяем всех врагов в радиусе
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	
	for enemy in enemies:
		var distance = enemy.global_position.distance_to(target_position)
		if distance <= ability.effect_radius:
			if enemy.has_method("apply_combat_damage_data"):
				enemy.apply_combat_damage_data(damage_data, get_parent())
				hit_count += 1
	
	print("Зонная атака поражено: ", hit_count, " врагов")
	if hit_count > 0:
		EventBus.Combat.enemy_hit.emit(null, damage_data.amount * hit_count, false)

func _apply_self_buff(ability: AbilityResource):
	"""Временный самобафф"""
	print("SELF_TARGET: ", ability.ability_name)
	
	if ability.heal_amount > 0:
		player_data.set_current_hp(player_data.current_hp + ability.heal_amount)
		EventBus.Player.healed.emit(ability.heal_amount, player_data.current_hp)
		print("Восстановлено HP: +", ability.heal_amount)
	
	# TODO: Добавить систему баффов

# ==================== УТИЛИТЫ ====================
func find_slot_index(ability: AbilityResource) -> int:
	"""Найти индекс слота по AbilityResource"""
	for i in range(slots.size()):
		if slots[i] == ability:
			return i
	return -1

func get_unlocked_abilities() -> Array[AbilityResource]:
	return ability_manager.get_unlocked_abilities()

func get_slot_assignment(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= slot_assignments.size():
		return ""
	return slot_assignments[slot_index]

func _update_ui(slot_index: int):
	"""Отправить данные в UI"""
	EventBus.UI.hud_update_required.emit({
		"type": "ability_cooldown",
		"slot_index": slot_index,
		"percentage": get_cooldown_percentage(slot_index),
		"on_cooldown": is_on_cooldown(slot_index),
		"ability_name": slots[slot_index].ability_name if slots[slot_index] else ""
	})

# ==================== СОХРАНЕНИЕ ====================
func save_assignments() -> Array[String]:
	return slot_assignments.duplicate()

func load_assignments(saved_assignments: Array[String]):
	if saved_assignments.size() == slot_assignments.size():
		slot_assignments = saved_assignments.duplicate()
		_initialize_slots()
