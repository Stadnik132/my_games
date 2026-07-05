extends CombatComponent
class_name PlayerCombatComponent

var _combo_window_active: bool = false
var _attack_request_pending: bool = false

func _setup_connections() -> void:
	super._setup_connections()
	
	EventBus.Combat.attack.basic_requested.connect(_on_attack_requested)
	EventBus.Combat.dodge.requested.connect(_on_dodge_requested)
	EventBus.Combat.block.started.connect(_on_block_started)
	EventBus.Combat.block.ended.connect(_on_block_ended)
	
	# Подключаемся к окну комбо
	EventBus.Combat.attack.combo_window_opened.connect(_on_combo_window_opened)
	EventBus.Combat.attack.combo_window_closed.connect(_on_combo_window_closed)
	
	# Подключаемся к хертбоксу для получения урона
	var hurtbox = owner_entity.get_node_or_null("Hurtbox")
	if hurtbox:
		if not hurtbox.damage_taken.is_connected(_on_hurtbox_damage):
			hurtbox.damage_taken.connect(_on_hurtbox_damage)
	
	# Проверка подключения способностей
	EventBus.Combat.ability.slot_pressed.connect(_on_ability_slot_pressed)

func _on_combo_window_opened() -> void:
	_combo_window_active = true

func _on_combo_window_closed() -> void:
	_combo_window_active = false

func _on_attack_requested() -> void:
	# Защита от спама
	if _attack_request_pending:
		return
	
	_attack_request_pending = true
	
	var current_state = fsm.get_current_state_name() if fsm else ""
	
	if current_state in ["Idle", "Walk"]:
		# Используем send_command вместо прямого вызова
		fsm.send_command("attack")
	elif current_state == "Attack":
		# В AttackState отправляем сигнал ТОЛЬКО если окно комбо активно
		if _combo_window_active:
			fsm.send_command("attack")
			# После отправки закрываем окно, чтобы лишние сигналы не проходили
			_combo_window_active = false
	
	# Сбрасываем блокировку в следующем кадре
	await get_tree().process_frame
	_attack_request_pending = false

func _on_dodge_requested(direction: Vector2) -> void:
	if not fsm or direction == Vector2.ZERO:
		return
	if stamina_component and not stamina_component.use(combat_config.dodge_stamina_cost):
		return
	fsm.send_command("dodge", {"direction": direction})

func _on_block_started() -> void:
	if fsm:
		fsm.send_command("block_start")

func _on_block_ended() -> void:
	if fsm:
		fsm.send_command("block_end")

# ==================== ОБРАБОТКА УРОНА ====================
func _on_hurtbox_damage(damage_data: DamageData, source: Node) -> void:
	super._on_hurtbox_damage(damage_data, source)

func _apply_defense(damage: int, damage_data: DamageData) -> int:
	if damage_data.is_true_damage() or not entity_data:
		return damage

	var defense = 0
	match damage_data.damage_type:
		DamageData.DamageType.PHYSICAL:
			defense = entity_data.get_physical_defense()
		DamageData.DamageType.MAGICAL:
			defense = entity_data.get_magical_defense()
		_:
			return damage

	var effective_defense = defense * (1.0 - damage_data.penetration)
	return max(1, damage - int(effective_defense))

# ==================== МЕТОД ДЛЯ FSM ====================
func get_move_vector() -> Vector2:
	"""Возвращает вектор движения от игрока"""
	var input = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	return input.normalized() if input.length() > 0 else Vector2.ZERO
