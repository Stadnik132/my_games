# player_combat_fsm/states/cast_state.gd
class_name CastState extends CombatState

var ability: AbilityResource
var slot_index: int
var target_data: Dictionary
var cast_timer: float
var is_channeling: bool = false

func enter() -> void:
	super.enter()
	
	print("=== CAST STATE ENTER ===")
	print("command_data = ", command_data)
	
	# Приоритет 1: данные из command_data
	if command_data.has("ability"):
		ability = command_data.get("ability")
		slot_index = command_data.get("slot_index", -1)
		target_data = command_data.get("target_data", {})
	else:
		# Приоритет 2: данные из FSM
		ability = fsm.current_ability
		slot_index = fsm.current_slot_index
		target_data = fsm.cast_target_data
	
	print("CastState: ability = ", ability.ability_name if ability else "null")
	print("CastState: slot_index = ", slot_index)
	print("CastState: target_data = ", target_data)
	
	if not ability:
		print("CastState: нет способности!")
		fsm.change_state("Idle")
		return
	
	if not _can_cast():
		print("CastState: нельзя использовать способность (ресурсы изменились)")
		fsm.change_state("Idle")
		return
	
	cast_timer = ability.cast_time
	is_channeling = ability.channeled
	
	_spend_resources()
	
	if ability.cast_animation:
		EventBus.Player.animation_requested.emit(ability.cast_animation, ability.cast_time)
	
	print("CastState: начат каст ", ability.ability_name, " на ", ability.cast_time, " сек")

func process(delta: float) -> void:
	cast_timer -= delta
	
	# Завершение каста
	if cast_timer <= 0:
		_finish_cast()

func _finish_cast() -> void:
	print("=== CAST FINISH ===")
	
	# ВРЕМЕННО отключаем финальную проверку
	# if not is_channeling and not _can_cast():
	# 	print("CastState: нельзя применить эффект (ресурсов не хватает)")
	# 	fsm.change_state("Idle")
	# 	return
	
	_spawn_effect()
	combat_component.ability_component.start_cooldown(slot_index)
	EventBus.Combat.ability_cast_completed.emit()
	fsm.change_state("Idle")

func _spawn_effect() -> void:
	"""Создаёт физический эффект способности"""
	print("CastState: спавн эффекта для типа ", ability.ability_type)
	
	match ability.ability_type:
		AbilityResource.AbilityType.PROJECTILE:
			_spawn_projectile()
		AbilityResource.AbilityType.AREA:
			_spawn_area_effect()
		AbilityResource.AbilityType.INSTANT:
			_perform_instant_effect()
		AbilityResource.AbilityType.SELF_TARGET:
			_apply_self_effect()
		_:
			print("CastState: неизвестный тип способности")

func _spawn_projectile() -> void:
	"""Создаёт снаряд"""
	print("CastState: создаю снаряд")
	
	var projectile_scene = ability.projectile_scene  # вместо ability.get_projectile_scene()
	if not projectile_scene:
	 	# Если не загружена, можно попробовать загрузить
		if ability.projectile_scene_path:
			projectile_scene = load(ability.projectile_scene_path)
	
	var projectile = projectile_scene.instantiate()
	
	# Настраиваем снаряд
	if projectile.has_method("setup"):
		projectile.setup({
			"caster": player,
			"damage_data": ability.get_damage_data(),
			"direction": target_data.get("direction", Vector2.RIGHT),
			"target_position": target_data.get("position", player.global_position),
			"speed": ability.projectile_speed,
			"max_distance": ability.max_cast_range
		})
	else:
		print("CastState: снаряд не имеет метода setup!")
		projectile.queue_free()
		return
	
	# Позиционируем
	projectile.global_position = player.global_position
	
	# Добавляем на сцену
	get_tree().current_scene.add_child(projectile)
	
	print("CastState: создан снаряд ", ability.ability_name)

func _spawn_area_effect() -> void:
	"""Создаёт зону поражения"""
	print("CastState: создаю область")
	
	var area_scene = ability.area_effect_scene
	if not area_scene:
		if ability.area_effect_scene_path:
			area_scene = load(ability.area_effect_scene_path)
		else:
			area_scene = load("res://Scenes/abilities/effect/area_effect.tscn")
	
	var area_effect = area_scene.instantiate()
	var target_pos = target_data.get("position", player.global_position)
	
	# ВАЖНО: СНАЧАЛА добавляем в дерево, ПОТОМ задаём global_position.
	# Иначе позиция задаётся как локальная и после add_child получается смещение из-за родителя.
	get_tree().current_scene.add_child(area_effect)
	area_effect.global_position = target_pos
	
	if area_effect.has_method("setup"):
		area_effect.setup({
			"caster": player,
			"damage_data": ability.get_damage_data(),
			"radius": ability.effect_radius,
			"duration": ability.effect_duration
		})
	else:
		print("CastState: область не имеет метода setup!")
		area_effect.queue_free()
		return
	
	print("CastState: создана область ", ability.ability_name, " в ", area_effect.global_position)

func _perform_instant_effect() -> void:
	"""Мгновенный эффект (обычно ближняя атака)"""
	print("CastState: мгновенный эффект")
	
	var damage_data = ability.get_damage_data()
	if not damage_data:
		print("CastState: нет damage_data для ", ability.ability_name)
		return
	
	# Активируем хитбокс игрока с данными способности
	var hitbox = _get_player_hitbox()
	if hitbox:
		hitbox.set_damage_data(damage_data)
		hitbox.monitoring = true
		print("CastState: хитбокс активирован")
		
		# Автоматически выключится через анимацию или таймер
		await get_tree().create_timer(0.2).timeout
		hitbox.monitoring = false
	else:
		print("CastState: не найден хитбокс игрока!")

func _apply_self_effect() -> void:
	"""Эффект на себя (лечение/бафф)"""
	print("CastState: self-эффект")
	
	var player_data = PlayerManager.player_data
	
	# Лечение
	if ability.heal_amount > 0:
		player_data.set_current_hp(player_data.current_hp + ability.heal_amount)
		EventBus.Player.healed.emit(ability.heal_amount, player_data.current_hp)
		print("CastState: вылечено ", ability.heal_amount, " HP")
	
	# TODO: Баффы
	if ability.buff_duration > 0:
		print("CastState: баффы пока не реализованы")

func _can_cast() -> bool:
	"""Проверяет, можно ли использовать способность"""
	var ability_comp = combat_component.ability_component
	
	if ability_comp.is_on_cooldown(slot_index):
		print("CastState: способность на кулдауне")
		return false
	
	# Используем новый метод has_resources
	return ability_comp.has_resources(slot_index)

func _spend_resources() -> void:
	"""Тратит ресурсы на способность"""
	var ability_comp = combat_component.ability_component
	ability_comp.spend_resources(slot_index)

func _get_player_hitbox() -> Hitbox:
	"""Возвращает текущий хитбокс игрока"""
	for child in player.get_children():
		if child is Hitbox:
			return child
	return null

func exit() -> void:
	"""Выход из состояния каста"""
	print("CastState: exit")
	EventBus.Player.animation_requested.emit("idle", 0.1)
	super.exit()

func get_allowed_transitions() -> Array[String]:
	return ["Idle", "Stun"]
