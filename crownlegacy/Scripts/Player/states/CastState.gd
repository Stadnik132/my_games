class_name CastState extends CombatState

var cast_timer: float = 0.0
var ability: AbilityResource = null
var target_position: Vector2 = Vector2.ZERO

func enter():
	print("CastState: каст способности")
	
	ability = fsm.current_ability
	if not ability:
		print("Ошибка: нет способности для каста")
		transition_requested.emit("Idle")
		return
	
	# ПОЛУЧАЕМ ЦЕЛЬ ИЗ FSM
	target_position = fsm.cast_target_position
	print("Цель каста: ", target_position)
	
	cast_timer = ability.cast_time
	
	# Блокировка движения
	if player.has_method("set_movement_allowed"):
		player.set_movement_allowed(false)
	
	# Проверка ресурсов
	if not ability.can_afford(player_data):
		print("Недостаточно ресурсов для каста")
		transition_requested.emit("Idle")
		return
	
	# Расход ресурсов сразу
	if ability.mana_cost > 0:
		player_data.set_current_mp(player_data.current_mp - ability.mana_cost)
	if ability.stamina_cost > 0:
		player_data.set_current_stamina(player_data.current_stamina - ability.stamina_cost)
	if ability.health_cost > 0:
		player_data.set_current_hp(player_data.current_hp - ability.health_cost)
	
	# Анимация каста
	if ability.cast_animation != "":
		EventBus.Player.animation_requested.emit(ability.cast_animation, ability.cast_time)
	
	EventBus.Combat.ability_cast_started.emit(ability)
func process(delta: float):
	cast_timer -= delta
	
	if cast_timer <= 0:
		_finish_cast()

func _finish_cast():
	# Применяем эффект способности
	if fsm.combat_component and fsm.combat_component.has_method("cast_current_ability"):
		fsm.combat_component.cast_current_ability(target_position)
	
	# Запускаем кулдаун
	var slot_index = fsm.combat_component.ability_component.find_slot_index(ability)
	if slot_index != -1:
		fsm.combat_component.ability_component.start_cooldown(slot_index)
	
	EventBus.Combat.ability_cast_completed.emit()
	transition_requested.emit("Idle")

func physics_process(delta: float):
	# Полная остановка во время каста
	player.velocity = Vector2.ZERO

func exit():
	# Восстанавливаем управление
	if player.has_method("set_movement_allowed"):
		player.set_movement_allowed(true)

func can_exit() -> bool:
	return true

func get_allowed_transitions() -> Array[StringName]:
	return ["Idle"]
