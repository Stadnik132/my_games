extends CombatComponent
class_name PlayerCombatComponent

func _setup_connections() -> void:
	super._setup_connections()
	
	print("PlayerCombatComponent: connecting signals...")
	
	EventBus.Combat.attack.basic_requested.connect(_on_attack_requested)
	EventBus.Combat.dodge.requested.connect(_on_dodge_requested)
	EventBus.Combat.block.started.connect(_on_block_started)
	EventBus.Combat.block.ended.connect(_on_block_ended)
	
	# Подключаемся к хертбоксу для получения урона
	var hurtbox = owner_entity.get_node_or_null("Hurtbox")
	if hurtbox:
		if not hurtbox.damage_taken.is_connected(_on_hurtbox_damage):
			hurtbox.damage_taken.connect(_on_hurtbox_damage)
			print("  ✅ hurtbox.damage_taken connected")
	
	# Проверка подключения способностей
	var connected = EventBus.Combat.ability.slot_pressed.connect(_on_ability_slot_pressed)
	if connected == OK:
		print("  ✅ slot_pressed connected")
	else:
		print("  ❌ slot_pressed connection failed: ", connected)

# ==================== ОБРАБОТКА УРОНА ====================
func _on_hurtbox_damage(damage_data: DamageData, source: Node) -> void:
	super._on_hurtbox_damage(damage_data, source)

# ==================== МЕТОД ДЛЯ FSM ====================
func get_move_vector() -> Vector2:
	"""Возвращает вектор движения от игрока"""
	var input = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	return input.normalized() if input.length() > 0 else Vector2.ZERO
