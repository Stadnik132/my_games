class_name PlayerCastState extends CombatState

var ability: AbilityResource
var slot_index: int
var target_data: Dictionary
var cast_timer: float
var is_channeling: bool = false

func enter() -> void:
	super.enter()
	
	print("=== PLAYER CAST STATE ENTER ===")
	
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
	
	if not ability:
		print("PlayerCastState: нет способности!")
		fsm.change_state("Idle")
		return
	
	if not _can_cast():
		print("PlayerCastState: нельзя использовать способность")
		fsm.change_state("Idle")
		return
	
	cast_timer = ability.cast_time
	is_channeling = ability.channeled
	
	_spend_resources()
	
	if ability.cast_animation:
		EventBus.Animations.requested.emit(entity, ability.cast_animation, ability.cast_time)
	
	EventBus.Combat.ability.cast_started.emit(ability)
	print("PlayerCastState: начат каст ", ability.ability_name)

func process(delta: float) -> void:
	cast_timer -= delta
	if cast_timer <= 0:
		_finish_cast()

func _finish_cast() -> void:
	print("=== PLAYER CAST FINISH ===")
	_spawn_effect()
	
	var ability_comp = combat_component.ability_component
	if ability_comp:
		ability_comp.start_cooldown(slot_index)
	
	EventBus.Combat.ability.cast_completed.emit()
	fsm.change_state("Idle")

func _spawn_effect() -> void:
	match ability.ability_type:
		AbilityResource.AbilityType.PROJECTILE:
			_spawn_projectile()
		AbilityResource.AbilityType.AREA:
			_spawn_area_effect()
		AbilityResource.AbilityType.INSTANT:
			_perform_instant_effect()
		AbilityResource.AbilityType.SELF_TARGET:
			_apply_self_effect()

func _spawn_projectile() -> void:
	print("PlayerCastState: создаю снаряд")
	
	var projectile_scene = ability.projectile_scene
	if not projectile_scene and ability.projectile_scene_path:
		projectile_scene = load(ability.projectile_scene_path)
	
	if not projectile_scene:
		print("PlayerCastState: нет сцены снаряда!")
		return
	
	var projectile = projectile_scene.instantiate()
	
	if projectile.has_method("setup"):
		# Получаем целевую позицию из прицеливания
		var target_pos = target_data.get("position", entity.global_position)
		var aim_direction = target_data.get("direction", Vector2.RIGHT)
		
		# ВАЖНО: Передаём стартовую позицию явно
		projectile.setup({
			"caster": entity,
			"damage_data": ability.get_damage_data(),
			"start_position": entity.global_position,  # НОВОЕ
			"target_position": target_pos,
			"direction": aim_direction,
			"speed": ability.projectile_speed,
			"max_distance": ability.max_cast_range
		})
	else:
		projectile.queue_free()
		return
	
	# ВАЖНО: НЕ меняем позицию после setup!
	# Снаряд сам установит себе позицию из start_position
	get_tree().current_scene.add_child(projectile)
	print("PlayerCastState: создан снаряд")

func _spawn_area_effect() -> void:
	print("PlayerCastState: создаю область")
	
	var area_scene = ability.area_effect_scene
	if not area_scene and ability.area_effect_scene_path:
		area_scene = load(ability.area_effect_scene_path)
	
	if not area_scene:
		area_scene = load("res://Scenes/abilities/effect/area_effect.tscn")
	
	var area_effect = area_scene.instantiate()
	var target_pos = target_data.get("position", entity.global_position)
	
	get_tree().current_scene.add_child(area_effect)
	area_effect.global_position = target_pos
	
	if area_effect.has_method("setup"):
		area_effect.setup({
			"caster": entity,
			"damage_data": ability.get_damage_data(),
			"radius": ability.effect_radius,
			"duration": ability.effect_duration
		})

func _perform_instant_effect() -> void:
	print("PlayerCastState: мгновенный эффект")
	
	var damage_data = ability.get_damage_data()
	if not damage_data:
		return
	
	var hitbox = _get_player_hitbox()
	if hitbox:
		hitbox.set_damage_data(damage_data)
		hitbox.monitoring = true
		await get_tree().create_timer(0.2).timeout
		hitbox.monitoring = false

func _apply_self_effect() -> void:
	print("PlayerCastState: self-эффект")
	
	if ability.heal_amount > 0:
		var health = entity.health_component
		if health:
			health.heal(ability.heal_amount)

func _can_cast() -> bool:
	var ability_comp = combat_component.ability_component
	if not ability_comp:
		return false
	
	if ability_comp.is_on_cooldown(slot_index):
		return false
	
	return ability_comp.has_resources(slot_index)

func _spend_resources() -> void:
	var ability_comp = combat_component.ability_component
	if ability_comp:
		ability_comp.spend_resources(slot_index)

func _get_player_hitbox() -> Hitbox:
	for child in entity.get_children():
		if child is Hitbox:
			return child
	return null

func exit() -> void:
	EventBus.Animations.requested.emit(entity, "idle", 0.1)
	super.exit()

func get_allowed_transitions() -> Array[String]:
	return ["Idle", "Stun"]
