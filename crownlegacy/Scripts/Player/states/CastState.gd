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
	print("command_data = ", command_data)  # Посмотрим что здесь
	
	# БЕРЁМ ДАННЫЕ ИЗ command_data (а не из fsm)
	ability = command_data.get("ability")
	slot_index = command_data.get("slot_index", -1)
	target_data = command_data.get("target_data", {})
	
	print("CastState: ability = ", ability.ability_name if ability else "null")
	print("CastState: slot_index = ", slot_index)
	print("CastState: target_data = ", target_data)
	
	if not ability:
		print("CastState: нет способности в command_data!")
		fsm.change_state("Idle")
		return
	
	# Проверяем, можно ли всё ещё использовать способность
	if not _can_cast():
		print("CastState: нельзя использовать способность (ресурсы изменились)")
		fsm.change_state("Idle")
		return
	
	# Настраиваем таймер каста
	cast_timer = ability.cast_time
	is_channeling = ability.channeled
	
	# Тратим ресурсы (для channeled - только начальные)
	_spend_resources()
	
	# Запускаем анимацию
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
	
	var projectile_scene = ability.get_projectile_scene()
	if not projectile_scene:
		print("CastState: нет сцены снаряда для ", ability.ability_name)
		return
	
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
	
	var area_scene = ability.get_area_effect_scene()
	if not area_scene:
		# Если нет кастомной сцены, создаём стандартную
		area_scene = load("res://combat/area_effect.tscn")
		print("CastState: использую стандартную сцену области")
	
	var area_effect = area_scene.instantiate()
	
	# Настраиваем
	if area_effect.has_method("setup"):
		area_effect.setup({
			"caster": player,
			"damage_data": ability.get_damage_data(),
			"position": target_data.get("position", player.global_position),
			"radius": ability.effect_radius,
			"duration": ability.effect_duration
		})
	else:
		print("CastState: область не имеет метода setup!")
		area_effect.queue_free()
		return
	
	# Позиционируем
	area_effect.global_position = target_data.get("position", player.global_position)
	
	# Добавляем на сцену
	get_tree().current_scene.add_child(area_effect)
	
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
	
	# Проверяем кулдаун
	if ability_comp.is_on_cooldown(slot_index):
		print("CastState: способность на кулдауне")
		return false
	
	# Проверяем ресурсы
	return ability_comp.can_cast_ability(slot_index)

func _spend_resources() -> void:
	"""Тратит ресурсы на способность"""
	var pd = PlayerManager.player_data
	
	if ability.mana_cost > 0:
		pd.set_current_mp(pd.current_mp - ability.mana_cost)
		print("CastState: потрачено маны ", ability.mana_cost)
	
	if ability.stamina_cost > 0:
		pd.set_current_stamina(pd.current_stamina - ability.stamina_cost)
		print("CastState: потрачено стамины ", ability.stamina_cost)
	
	if ability.health_cost > 0:
		pd.set_current_hp(pd.current_hp - ability.health_cost)
		print("CastState: потрачено здоровья ", ability.health_cost)

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
