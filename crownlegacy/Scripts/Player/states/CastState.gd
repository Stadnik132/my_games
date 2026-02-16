class_name CastState extends CombatState

# Cast: только из Aim (ЛКМ). Длительность = время анимации прокаста. Выход только в Idle по окончании.

var cast_timer: float = 0.0
var ability: AbilityResource = null
var target_position: Vector2 = Vector2.ZERO

func enter() -> void:
	ability = fsm.current_ability
	target_position = fsm.cast_target_position
	if not ability:
		transition_requested.emit("Idle")
		return
	cast_timer = ability.cast_time
	if ability.cast_animation != "":
		EventBus.Player.animation_requested.emit(ability.cast_animation, ability.cast_time)
		EventBus.Combat.ability_animation_started.emit(ability.cast_animation, ability.cast_time)

func process(delta: float) -> void:
	cast_timer -= delta
	if cast_timer <= 0.0:
		_finish_cast()

func _finish_cast() -> void:
	if combat_component and combat_component.has_method("apply_ability_effect"):
		combat_component.apply_ability_effect(fsm.current_slot_index, target_position)
	transition_requested.emit("Idle")

func physics_process(_delta: float) -> void:
	set_battle_velocity(Vector2.ZERO)
	apply_movement()

func can_exit() -> bool:
	return cast_timer <= 0.0

func get_allowed_transitions() -> Array[String]:
	return ["Idle"]
