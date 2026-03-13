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
	
	# Ресурсы тратятся в cast_ability, здесь не нужно
	
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
	
	# Получаем позицию цели
	var target_pos = target_data.get("position", entity.global_position)
	
	# ВЫЗЫВАЕМ cast_ability из AbilityComponent
	var ability_comp = combat_component.ability_component
	if ability_comp:
		ability_comp.cast_ability(slot_index, target_pos)
	
	# Кулдаун уже запускается в cast_ability
	EventBus.Combat.ability.cast_completed.emit()
	fsm.change_state("Idle")

func _can_cast() -> bool:
	var ability_comp = combat_component.ability_component
	if not ability_comp:
		return false
	
	if ability_comp.is_on_cooldown(slot_index):
		return false
	
	return ability_comp.has_resources(slot_index)

func exit() -> void:
	EventBus.Animations.requested.emit(entity, "idle", 0.1)
	super.exit()

func get_allowed_transitions() -> Array[String]:
	return ["Idle", "Stun"]
