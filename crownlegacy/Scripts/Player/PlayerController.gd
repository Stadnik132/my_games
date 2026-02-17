# PlayerController
extends CharacterBody2D

@export_category("Настройки движения")
@export var move_speed: float = 200.0
@export var sprint_speed: float = 350.0
@export var acceleration: float = 15.0
@export var friction: float = 20.0

# ==================== КОНСТАНТЫ СОСТОЯНИЙ ====================
# Синхронизировано с GameStateManager.gd (enum GameState)
const STATE_WORLD = 0       # Свободное перемещение по миру
const STATE_DIALOGUE = 1    # Активен диалог
const STATE_BATTLE = 2      # Бой в реальном времени
const STATE_MENU = 3        # Открыто любое меню
const STATE_CUTSCENE = 4    # Катсцена
const STATE_GAME_OVER = 5   # Конец игры

# ==================== ССЫЛКИ ====================
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var hurtbox: Hurtbox = $Hurtbox

# ==================== ПЕРЕМЕННЫЕ СОСТОЯНИЯ ====================
var current_animation: String = "idle_down"
var last_movement_direction: Vector2 = Vector2.DOWN
var _movement_locked: bool = false

# Флаги управления (обновляются из GameState)
# _can_move = true только в WORLD. В BATTLE движение управляется FSM (Idle/Walk/Dodge).
var _can_move: bool = true
var _can_interact: bool = true      # Только WORLD
var _in_combat_mode: bool = false   # BATTLE: боевой ввод и движение через состояния

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func _ready() -> void:
	add_to_group("player")
	
	EventBus.Game.state_changed.connect(_on_game_state_changed)
	print_debug("PlayerController: готов")

# ==================== ФИЗИКА (ДВИЖЕНИЕ) ====================
func _physics_process(delta: float) -> void:
	# BATTLE: FSM сама двигает
	if _in_combat_mode:
		return  # Ничего не делаем, move_and_slide() вызовет состояние
	
	# WORLD: обычное движение
	if not _can_move:
		velocity = Vector2.ZERO
		_play_idle_animation()
		return
	
	var input_vector = _get_input_vector()
	if input_vector != Vector2.ZERO:
		_handle_movement(input_vector, delta)
		last_movement_direction = input_vector
	else:
		_handle_stop_movement(delta)
	
	move_and_slide()

# ==================== ОБРАБОТКА ВВОДА ====================
func _input(event: InputEvent) -> void:
	if _handle_global_input(event):
		return
	if _in_combat_mode:
		_handle_combat_input(event)

func _handle_global_input(event: InputEvent) -> bool:
	# Взаимодействие
	if event.is_action_pressed("interact") and _can_interact:
		_handle_interaction()
		get_viewport().set_input_as_handled()
		return true
	
	# Меню
	if event.is_action_pressed("ui_cancel") and _can_open_menu():
		EventBus.Game.menu_requested.emit()
		get_viewport().set_input_as_handled()
		return true
	
	return false

func _handle_combat_input(event: InputEvent) -> void:
	var combat_comp = $PlayerCombatComponent if has_node("PlayerCombatComponent") else null
	if not combat_comp:
		return
	if combat_comp.fsm.get_current_state_name() == "Stun":
		return
	var is_aiming = combat_comp.fsm.get_current_state_name() == "Aiming"
	
	# ЛКМ
	if event.is_action_pressed("basic_attack"):
		if is_aiming:
			_confirm_ability_cast()
		else:
			EventBus.Combat.basic_attack_requested.emit()
		get_viewport().set_input_as_handled()
		return
	
	if event.is_action_pressed("block"):
		if _in_combat_mode:
			EventBus.Combat.block_started.emit()
			get_viewport().set_input_as_handled()
			return

	if event.is_action_released("block"):
		if _in_combat_mode:
			EventBus.Combat.block_ended.emit()
			get_viewport().set_input_as_handled()
			return
	
	# Уворот
	if event.is_action_pressed("dodge"):
		var dodge_dir = _get_input_vector()
		if dodge_dir == Vector2.ZERO:
			dodge_dir = last_movement_direction
		EventBus.Combat.dodge_requested.emit(dodge_dir)
		get_viewport().set_input_as_handled()
		return
	
	# Способности 1-4
	for i in range(1, 5):
		if event.is_action_pressed("ability_" + str(i)):
			EventBus.Combat.ability_slot_pressed.emit(i-1)
			get_viewport().set_input_as_handled()
			return

func _confirm_ability_cast():
	var mouse_pos = get_viewport().get_mouse_position()
	var camera = get_viewport().get_camera_2d()
	var global_mouse_pos = camera.global_position + (mouse_pos - get_viewport().size * 0.5) / camera.zoom
	EventBus.Combat.ability_target_confirmed.emit(global_mouse_pos)

# ==================== ДВИЖЕНИЕ ====================
func _get_input_vector() -> Vector2:
	var input = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	return input.normalized() if input.length() > 0 else Vector2.ZERO

func _handle_movement(input_vector: Vector2, delta: float) -> void:
	var target_speed = sprint_speed if Input.is_action_pressed("sprint") else move_speed
	var target_velocity = input_vector * target_speed
	velocity = velocity.lerp(target_velocity, acceleration * delta)
	
	var anim_direction = _get_animation_direction(input_vector)
	_play_walk_animation(anim_direction)
	current_animation = "walk_" + anim_direction

func _handle_stop_movement(delta: float) -> void:
	velocity = velocity.lerp(Vector2.ZERO, friction * delta)
	_play_idle_animation()

# ==================== АНИМАЦИИ ====================
func _get_animation_direction(input_vector: Vector2) -> String:
	if abs(input_vector.x) > abs(input_vector.y):
		return "right" if input_vector.x > 0 else "left"
	else:
		return "down" if input_vector.y > 0 else "up"

func _play_walk_animation(direction: String) -> void:
	var anim_name = "walk_" + direction
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
		current_animation = anim_name

func _play_idle_animation() -> void:
	var idle_name = current_animation.replace("walk_", "idle_")
	if not animation_player.has_animation(idle_name):
		idle_name = "idle_down"
	
	if animation_player.has_animation(idle_name):
		animation_player.play(idle_name)

# ==================== ВЗАИМОДЕЙСТВИЕ ====================
func _handle_interaction() -> void:
	print_debug("Player: запрос взаимодействия (E)")
	EventBus.Actors.interaction_requested.emit()

# ==================== ОБРАБОТЧИКИ СОСТОЯНИЙ ====================
func _on_game_state_changed(new_state: int, old_state: int) -> void:
	# Сбрасываем все флаги
	_can_move = false
	_can_interact = false
	_in_combat_mode = false
	
	match new_state:
		STATE_WORLD:
			_can_move = true
			_can_interact = true
			_in_combat_mode = false
			print_debug("Player: WORLD - движение + взаимодействие")
		
		STATE_DIALOGUE:
			# Полная блокировка
			_can_move = false
			_can_interact = false
			print_debug("Player: DIALOGUE - всё заблокировано")
		
		STATE_BATTLE:
			_can_move = false     # Движение только через FSM (Idle/Walk/Dodge)
			_can_interact = false
			_in_combat_mode = true
			print_debug("Player: BATTLE - движение через состояния боя")
		
		STATE_MENU, STATE_CUTSCENE, STATE_GAME_OVER:
			# Полная блокировка
			_can_move = false
			_can_interact = false
			print_debug("Player: UI-состояние - всё заблокировано")
		
		_:
			push_warning("PlayerController: неизвестное состояние ", new_state)
			_can_move = true
			_can_interact = true

func _can_open_menu() -> bool:
	"""Меню доступно в WORLD и в BATTLE"""
	return _can_move or _in_combat_mode

# ==================== ПУБЛИЧНЫЕ МЕТОДЫ ====================
func force_stop() -> void:
	"""Принудительная остановка (катсцены, события)"""
	velocity = Vector2.ZERO
	_play_idle_animation()
	_can_move = false
	_can_interact = false

# ==================== СОХРАНЕНИЕ ====================
func get_save_data() -> Dictionary:
	return {
		"position": {
			"x": global_position.x,
			"y": global_position.y
		},
		"direction": {
			"x": last_movement_direction.x,
			"y": last_movement_direction.y
		},
		"current_animation": current_animation
	}

func teleport(new_position: Vector2, fade_effect: bool = true) -> void:
	print_debug("Player: телепортация в ", new_position)
	global_position = new_position
	velocity = Vector2.ZERO
	_play_idle_animation()
