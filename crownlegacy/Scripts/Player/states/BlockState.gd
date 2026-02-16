class_name BlockState extends CombatState

# Блок: вход по ПКМ (block_start), выход только по отжатию ПКМ (block_end).
# Стамина тратится за полученный урон, урон понижается.

func enter() -> void:
	set_battle_velocity(Vector2.ZERO)
	EventBus.Combat.block_active.emit()

func physics_process(_delta: float) -> void:
	set_battle_velocity(Vector2.ZERO)
	apply_movement()

func handle_command(command: String, data: Dictionary = {}) -> void:
	super.handle_command(command, data)
	if command == "block_end":
		transition_requested.emit("Idle")

func get_allowed_transitions() -> Array[String]:
	return ["Idle", "Stun"]
