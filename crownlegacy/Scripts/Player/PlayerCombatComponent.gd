# PlayerCombatComponent.gd
class_name PlayerCombatComponent extends Node

@export_category("Параметры боя")
@export var attack_combo_damage: Array[float] = [1.0, 1.2, 1.5, 2.0]
@export var attack_combo_window: float = 3.0
@export var attack_duration: float = 2.0
@export var cancel_window_start: float = 0.1
@export var dodge_distance: float = 80.0
@export var dodge_duration: float = 0.3
@export var dodge_collider_radius: float = 15.0
@export var attack_idle_inside_duration: float = 3.0
var current_target_position: Vector2 = Vector2.ZERO

@onready var player_body: CharacterBody2D = get_parent()
@onready var player_data: PlayerData = PlayerManager.player_data
@onready var fsm: PlayerCombatFSM = $PlayerCombatFSM
@onready var ability_component: AbilityComponent = $AbilityComponent

func _ready():
	print("=== COMBAT SYSTEM INIT ===")
	print("FSM: ", fsm != null)
	print("AbilityComponent: ", ability_component != null)
	print("Initial state: ", fsm.get_current_state_name())
	fsm.setup(player_body, player_data, self)
	_setup_event_bus_connections()

func get_attack_params() -> Dictionary:
	return {
		"combo_damage": attack_combo_damage,
		"combo_window": attack_combo_window,
		"attack_duration": attack_duration,
		"cancel_window_start": cancel_window_start,
		"base_damage": player_data.base_attack_damage
	}

func get_dodge_params() -> Dictionary:
	return {
		"distance": dodge_distance,
		"duration": dodge_duration,
		"collider_radius": dodge_collider_radius,
		"stamina_cost": player_data.dodge_stamina_cost
	}

func _setup_event_bus_connections():
	# Сигналы от PlayerController
	EventBus.Combat.basic_attack_requested.connect(_on_attack)
	EventBus.Combat.dodge_requested.connect(_on_dodge)
	EventBus.Combat.block_started.connect(_on_block_start)
	EventBus.Combat.block_ended.connect(_on_block_end)
	
	# Способности
	EventBus.Combat.ability_slot_pressed.connect(_on_ability_slot_pressed)
	EventBus.Combat.ability_target_confirmed.connect(_on_ability_target_confirmed)
	EventBus.Combat.ability_target_cancelled.connect(_on_ability_target_cancelled)

func _on_attack():
	fsm.send_command("attack")

func _on_dodge(direction: Vector2):
	fsm.last_dodge_direction = direction
	fsm.send_command("dodge", {"direction": direction})

func _on_block_start():
	var current_state = fsm.get_current_state_name()
	
	# Если в AimingState - отмена прицеливания
	if current_state == "Aiming":
		fsm.send_command("block_start")  # Будет обработано как отмена
	else:
		# Обычный блок
		fsm.send_command("block_start")

func _on_block_end():
	var current_state = fsm.get_current_state_name()
	print("_on_block_end: текущее состояние = ", current_state)
	
	if current_state == "Block":
		fsm.send_command("block_end")
	else:
		print("Block ended but not in BlockState, состояние = ", current_state)

func _on_ability_slot_pressed(slot_index: int):
	print("=== ABILITY SLOT PRESSED ===")
	print("Слот: ", slot_index)
	
	var ability = ability_component.get_ability_in_slot(slot_index)
	if not ability:
		print("  -> Способность не найдена в слоте")
		return
	
	fsm.current_ability = ability
	
	print("  -> Способность: ", ability.ability_name)
	print("  -> Можно использовать: ", ability_component.can_cast_ability(slot_index))
	print("  -> На кулдауне: ", ability_component.is_on_cooldown(slot_index))
	
	# Отправляем команду в FSM в зависимости от состояния
	var state = fsm.get_current_state_name()
	
	
	match state:
		"Idle", "Aiming":
			fsm.send_command("ability_selected", {"ability": ability})
			fsm.send_command("aim_start")
		
		"Dodge":
			# Во время уворота можно выбрать способность для каста после
			fsm.send_command("ability_selected", {"ability": ability})
			# Остаёмся в DodgeState
		
		_:
			print("Нельзя выбрать способность в состоянии: ", state)

func cast_current_ability(target_position: Vector2):
	var slot_index = ability_component.find_slot_index(fsm.current_ability)
	if slot_index != -1:
		ability_component.cast_ability(slot_index, target_position)

func _on_ability_target_confirmed(target_position: Vector2):
	print("Подтверждена цель: ", target_position)
	fsm.cast_target_position = target_position  # СОХРАНЯЕМ В FSM
	fsm.send_command("cast") 

func _on_ability_target_cancelled():
	fsm.send_command("aim_cancel")

# Для прицеливания и каста нужны дополнительные методы
func confirm_cast(target_position: Vector2):
	fsm.send_command("cast", {"target": target_position})

func cancel_aiming():
	fsm.send_command("aim_cancel")

func _process(delta: float):
	fsm._process(delta)

func _physics_process(delta: float):
	fsm._physics_process(delta)
	
