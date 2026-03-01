class_name AbilityComponent extends Node

# ==================== ЭКСПОРТ ====================
@export var initial_slot_assignments: Array[String] = ["basic_slash", "fireball", "frost_nova", "berserk"]

# ==================== ССЫЛКИ (ЗАПОЛНЯЮТСЯ ИЗВНЕ) ====================
var entity: Entity                          # Владелец способностей
var entity_data: EntityData                  # Данные владельца
var mana_component: ResourceComponent        # Для траты маны
var stamina_component: ResourceComponent     # Для траты выносливости
var health_component: HealthComponent        # Для траты здоровья

# ==================== ВНУТРЕННИЕ МАССИВЫ ====================
var slots: Array[AbilityResource] = []       # AbilityResource в слотах
var slot_assignments: Array[String] = []     # ID способностей в слотах
var cooldowns: Dictionary = {}               # Кулдауны по индексам {0: 2.5, 1: 0.0, ...}

# ==================== ССЫЛКИ НА МЕНЕДЖЕРЫ ====================
@onready var ability_manager = AbilityManager  # остаётся глобальным

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func _ready():
	# Не инициализируем ничего без entity
	pass

func setup(owner_entity: Entity) -> void:
	"""Настройка компонента для конкретного владельца"""
	entity = owner_entity
	
	# Находим компоненты у владельца
	_find_components()
	
	# Инициализируем слоты
	_initialize_slots()
	
	print("AbilityComponent: инициализировано для ", entity.name)

func _find_components() -> void:
	if not entity:
		return
	
	entity_data = entity.get("entity_data")  # Может быть PlayerData или ActorData
	
	# Ищем компоненты ресурсов
	for child in entity.get_children():
		if child is ResourceComponent:
			var res_comp = child as ResourceComponent
			match res_comp.resource_type:
				ResourceComponent.ResourceType.MANA:
					mana_component = res_comp
				ResourceComponent.ResourceType.STAMINA:
					stamina_component = res_comp
	
	health_component = entity.health_component

func _initialize_slots() -> void:
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
	
	# Сохраняем в данные, если есть метод
	if entity_data and entity_data.has_method("set_ability_slot_assignment"):
		entity_data.set_ability_slot_assignment(slot_index, ability_id)
	
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
	if not has_resources(slot_index):
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
	spend_resources(slot_index)
	
	start_cooldown(slot_index)
	
	# Сигнал о начале каста
	EventBus.Combat.ability.cast_started.emit(ability)
	
	# Анимация каста (если есть)
	if ability.cast_animation != "" and entity:
		EventBus.Animation.requested.emit(entity, ability.cast_animation, ability.cast_time)
	
	# Применение эффекта
	_apply_ability_effect(ability, target_position)
	
	# Сигнал о завершении
	EventBus.Combat.ability.cast_completed.emit()
	
	return true

# ==================== РЕСУРСЫ ====================
func spend_resources(slot_index: int) -> bool:
	"""Тратит ресурсы способности, возвращает успех"""
	var ability = get_ability_in_slot(slot_index)
	if not ability:
		return false
	
	var success = true
	
	if ability.mana_cost > 0 and mana_component:
		success = success and mana_component.use(ability.mana_cost)
	
	if ability.stamina_cost > 0 and stamina_component:
		success = success and stamina_component.use(ability.stamina_cost)
	
	if ability.health_cost > 0 and health_component:
		# Для здоровья используем специальный метод
		var current = health_component.get_current_health()
		if current > ability.health_cost:
			health_component.take_damage(ability.health_cost, 2, entity, false)  # 2 = TRUE damage
		else:
			success = false
	
	return success

func has_resources(slot_index: int) -> bool:
	"""Проверяет, хватает ли ресурсов без их траты"""
	var ability = get_ability_in_slot(slot_index)
	if not ability:
		return false
	
	if ability.mana_cost > 0 and mana_component:
		if mana_component.get_current() < ability.mana_cost:
			return false
	
	if ability.stamina_cost > 0 and stamina_component:
		if stamina_component.get_current() < ability.stamina_cost:
			return false
	
	if ability.health_cost > 0 and health_component:
		if health_component.get_current_health() <= ability.health_cost:
			return false
	
	return true

# ==================== ЭФФЕКТЫ ====================
func _apply_ability_effect(ability: AbilityResource, target_position: Vector2):
	"""Применяет эффект способности"""
	match ability.ability_type:
		AbilityResource.AbilityType.INSTANT:
			_apply_instant_effect(ability, target_position)
		
		AbilityResource.AbilityType.PROJECTILE:
			_spawn_projectile(ability, target_position)
		
		AbilityResource.AbilityType.AREA:
			_create_area_effect(ability, target_position)
		
		AbilityResource.AbilityType.SELF_TARGET:
			_apply_self_effect(ability)

func _apply_instant_effect(ability: AbilityResource, target_position: Vector2):
	"""Мгновенный эффект (урон по области)"""
	var damage_data = ability.get_damage_data()
	if not damage_data:
		return
	
	# Используем HitboxComponent если есть
	var hitbox_comp = entity.get_node_or_null("HitboxComponent") as HitboxComponent
	if hitbox_comp:
		# Создаём хитбокс в целевой позиции
		hitbox_comp.spawn_area_hitbox(
			target_position,
			ability.effect_radius,
			damage_data.amount,
			damage_data.damage_type,
			0.1  # короткое время жизни
		)
	else:
		# Временное решение: ищем врагов через группу
		_find_enemies_in_area(target_position, ability.effect_radius, damage_data)

func _spawn_projectile(ability: AbilityResource, target_position: Vector2):
	"""Создаёт снаряд"""
	var projectile_scene = ability.projectile_scene
	if not projectile_scene and ability.projectile_scene_path:
		projectile_scene = load(ability.projectile_scene_path)
	
	if not projectile_scene:
		print("AbilityComponent: нет сцены снаряда для ", ability.ability_name)
		return
	
	var projectile = projectile_scene.instantiate()
	
	if projectile.has_method("setup"):
		# Направление от владельца к цели
		var direction = (target_position - entity.global_position).normalized()
		
		projectile.setup({
			"caster": entity,
			"damage_data": ability.get_damage_data(),
			"start_position": entity.global_position,
			"target_position": target_position,
			"direction": direction,
			"speed": ability.projectile_speed,
			"max_distance": ability.max_cast_range
		})
		
		get_tree().current_scene.add_child(projectile)
	else:
		projectile.queue_free()

func _create_area_effect(ability: AbilityResource, target_position: Vector2):
	"""Создаёт зону поражения"""
	var area_scene = ability.area_effect_scene
	if not area_scene and ability.area_effect_scene_path:
		area_scene = load(ability.area_effect_scene_path)
	
	if not area_scene:
		print("AbilityComponent: нет сцены области для ", ability.ability_name)
		return
	
	var area_effect = area_scene.instantiate()
	
	if area_effect.has_method("setup"):
		get_tree().current_scene.add_child(area_effect)
		area_effect.global_position = target_position
		
		area_effect.setup({
			"caster": entity,
			"damage_data": ability.get_damage_data(),
			"radius": ability.effect_radius,
			"duration": ability.effect_duration
		})
	else:
		area_effect.queue_free()

func _apply_self_effect(ability: AbilityResource):
	"""Эффект на себя (лечение/бафф)"""
	if ability.heal_amount > 0 and health_component:
		health_component.heal(ability.heal_amount)
		print("AbilityComponent: вылечено ", ability.heal_amount, " HP")
	
	# TODO: Баффы через ProgressionComponent

# ==================== ВРЕМЕННЫЙ ПОИСК ВРАГОВ (ЗАГЛУШКА) ====================
func _find_enemies_in_area(center: Vector2, radius: float, damage_data: DamageData):
	"""Временный метод для поиска врагов в области"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	
	for enemy in enemies:
		var distance = enemy.global_position.distance_to(center)
		if distance <= radius:
			if enemy.has_method("apply_combat_damage_data"):
				enemy.apply_combat_damage_data(damage_data, entity)
				hit_count += 1
	
	print("AbilityComponent: поражено врагов: ", hit_count)

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
	var ability = slots[slot_index] if slot_index < slots.size() else null
	EventBus.UI.hud_update_required.emit({
		"type": "ability_cooldown",
		"slot_index": slot_index,
		"percentage": get_cooldown_percentage(slot_index),
		"on_cooldown": is_on_cooldown(slot_index),
		"ability_name": ability.ability_name if ability != null else ""
	})

# ==================== СОХРАНЕНИЕ ====================
func save_assignments() -> Array[String]:
	return slot_assignments.duplicate()

func load_assignments(saved_assignments: Array[String]):
	if saved_assignments.size() == slot_assignments.size():
		slot_assignments = saved_assignments.duplicate()
		_initialize_slots()
