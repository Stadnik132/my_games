extends CombatComponent
class_name PlayerCombatComponent

func _setup_connections() -> void:
	super._setup_connections()
	
	print("PlayerCombatComponent: connecting signals...")
	
	EventBus.Combat.attack.basic_requested.connect(_on_attack_requested)
	EventBus.Combat.dodge.requested.connect(_on_dodge_requested)
	EventBus.Combat.block.started.connect(_on_block_started)
	EventBus.Combat.block.ended.connect(_on_block_ended)
	
	# Проверка подключения способностей
	var connected = EventBus.Combat.ability.slot_pressed.connect(_on_ability_slot_pressed)
	if connected == OK:
		print("  ✅ slot_pressed connected")
	else:
		print("  ❌ slot_pressed connection failed: ", connected)
