class_name BlockState extends CombatState

var block_released: bool = false
var is_broken: bool = false
var stamina_drain_timer: float = 0.0
var stamina_drain_interval: float = 0.2
var stamina_cost_per_second: int = 20

func enter():
	print("BlockState: блок активен")
	block_released = false
	is_broken = false
	stamina_drain_timer = 0.0
	
	# ПРЯМОЙ ВЫЗОВ - КАК В АТАКЕ
	if player.has_method("set_movement_allowed"):
		player.set_movement_allowed(false)
	
	EventBus.Combat.block_active.emit()

func process(delta: float):
	stamina_drain_timer += delta
	
	if stamina_drain_timer >= stamina_drain_interval:
		stamina_drain_timer = 0.0
		
		var stamina_cost = int(stamina_cost_per_second * stamina_drain_interval)
		if not player_data.use_stamina(stamina_cost):
			is_broken = true
			EventBus.Combat.block_broken.emit()
			transition_requested.emit("Idle")

func physics_process(delta: float):
	player.velocity = Vector2.ZERO

func handle_command(command: String, data: Dictionary = {}):
	if command == "block_end":
		block_released = true
		transition_requested.emit("Idle")

func can_exit() -> bool:
	return block_released or is_broken

func exit():
	# ПРЯМОЙ ВЫЗОВ - КАК В АТАКЕ
	if player.has_method("set_movement_allowed"):
		player.set_movement_allowed(true)
	
	block_released = false
	is_broken = false

func get_allowed_transitions() -> Array[StringName]:
	return ["Idle"]
