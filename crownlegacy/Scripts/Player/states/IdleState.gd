# IdleState.gd
class_name IdleState extends CombatState

func enter():
	print("IdleState: можно двигаться, атаковать, блокировать, уворачиваться, прицеливаться")

func handle_command(command: String, data: Dictionary = {}):
	match command:
		"attack":
			transition_requested.emit("Attack")
		"dodge":
			transition_requested.emit("Dodge")
		"block_start":
			transition_requested.emit("Block")
		"aim_start":
			transition_requested.emit("Aiming")
		"ability_selected":
			fsm.current_ability = data.get("ability")
			print("Выбрана способность: ", fsm.current_ability.ability_name)
		"aim_start":
			transition_requested.emit("Aiming")
		# Способности обрабатываются в компоненте

func get_allowed_transitions() -> Array[StringName]:
	return ["Attack", "Dodge", "Block", "Aiming"]
