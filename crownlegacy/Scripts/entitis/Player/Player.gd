extends Entity
class_name Player

# ==================== ЭКСПОРТ ====================
@export_category("Настройки движения")
@export var move_speed: float = 200.0
@export var sprint_speed: float = 350.0
@export var acceleration: float = 15.0
@export var friction: float = 20.0
var last_horizontal_direction: Vector2 = Vector2.RIGHT

# ==================== КОНСТАНТЫ СОСТОЯНИЙ ====================
const STATE_WORLD = 0
const STATE_DIALOGUE = 1
const STATE_BATTLE = 2
const STATE_MENU = 3
const STATE_CUTSCENE = 4
const STATE_GAME_OVER = 5

# ==================== ССЫЛКИ ====================
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var controller: PlayerController = $PlayerController
@onready var combat_component: PlayerCombatComponent = $PlayerCombatComponent
@export var player_data: PlayerData

# Совместимость для кода, который ожидает свойство `entity_data` у Entity.
# (например `AbilityComponent` делает `entity.get("entity_data")`)
var entity_data: EntityData:
	get:
		return player_data
	set(value):
		player_data = value as PlayerData

# ==================== ПЕРЕМЕННЫЕ СОСТОЯНИЯ ====================
var current_animation: String = "idle_down"
var last_movement_direction: Vector2 = Vector2.DOWN
var _can_move_in_world: bool = true
var _in_combat_mode: bool = false

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func _ready() -> void:
	super._ready()  # вызываем Entity._ready()
	add_to_group("player")
	
	# Настраиваем Hurtbox
	if hurtbox:
		hurtbox.update_layer_from_owner()
	
	# Подключаем сигналы компонентов (специфичные для игрока)
	if not progression_component.level_up.is_connected(_on_level_up):
		progression_component.level_up.connect(_on_level_up)

	if not progression_component.experience_gained.is_connected(_on_experience_gained):
		progression_component.experience_gained.connect(_on_experience_gained)
	
	# Подключаемся к глобальным состояниям
	EventBus.Game.state_changed.connect(_on_game_state_changed)
	EventBus.Animations.requested.connect(_on_animation_requested)
	
	print_debug("Player: готов")

# ==================== ДВИЖЕНИЕ ====================
func _physics_process(delta: float) -> void:
	# В бою движение через FSM
	if _in_combat_mode:
		return
	
	# В мире — обычное движение
	if not _can_move_in_world or movement_locked:
		velocity = Vector2.ZERO
		_play_idle_animation()
		move_and_slide()
		return
	
	var input_vector = _get_input_vector()
	if input_vector != Vector2.ZERO:
		_handle_movement(input_vector, delta)
		last_movement_direction = input_vector
	else:
		_handle_stop_movement(delta)
	
	move_and_slide()

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
	
	if abs(input_vector.x) > 0:
		last_horizontal_direction = Vector2(sign(input_vector.x), 0)
	
	var anim_direction = _get_animation_direction(input_vector)
	_play_walk_animation(anim_direction)
	current_animation = "walk_" + anim_direction

func get_horizontal_facing_direction() -> Vector2:
	"""Возвращает последнее горизонтальное направление игрока"""
	# Если есть движение, используем его
	if abs(velocity.x) > 10:
		return Vector2(sign(velocity.x), 0)
	
	# Иначе возвращаем последнее сохранённое
	return last_horizontal_direction

func _handle_stop_movement(delta: float) -> void:
	velocity = velocity.lerp(Vector2.ZERO, friction * delta)
	_play_idle_animation()

# ==================== АНИМАЦИИ ====================
func _on_animation_requested(target: Node, animation_name: String, duration: float) -> void:
	"""Проигрывает анимацию по запросу из EventBus"""
	if target != self:
		return  # анимация не для нас
	
	if not animation_player:
		return
	
	if animation_player.has_animation(animation_name):
		animation_player.play(animation_name)
		if duration > 0:
			# Если указана длительность, можно синхронизировать
			animation_player.speed_scale = animation_player.current_animation_length / duration
	else:
		print_debug("Player: анимация не найдена: ", animation_name)

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

# ==================== ОБРАБОТЧИКИ СОСТОЯНИЙ ====================
func _on_game_state_changed(new_state: int, _old_state: int) -> void:
	# Сбрасываем флаги
	_can_move_in_world = false
	_in_combat_mode = false
	interaction_locked = true
	
	match new_state:
		STATE_WORLD:
			_can_move_in_world = true
			interaction_locked = false
			_in_combat_mode = false
			print_debug("Player: WORLD")
		
		STATE_DIALOGUE:
			print_debug("Player: DIALOGUE - всё заблокировано")
		
		STATE_BATTLE:
			_in_combat_mode = true
			print_debug("Player: BATTLE")
		
		STATE_MENU, STATE_CUTSCENE, STATE_GAME_OVER:
			print_debug("Player: UI-состояние")
		
		_:
			push_warning("Player: неизвестное состояние ", new_state)
			_can_move_in_world = true

# ==================== СПЕЦИФИЧНЫЕ ДЛЯ ИГРОКА СИГНАЛЫ ====================
func _on_level_up(new_level: int, stat_increases: Dictionary) -> void:
	EventBus.Player.level_up.emit(new_level, stat_increases)

func _on_experience_gained(amount: int, new_total: int, _next_level: int) -> void:
	EventBus.Player.experience_gained.emit(amount, new_total)

# ==================== ПУБЛИЧНЫЕ МЕТОДЫ ====================
func force_stop() -> void:
	"""Принудительная остановка (катсцены, события)"""
	velocity = Vector2.ZERO
	_play_idle_animation()
	movement_locked = true
	interaction_locked = true

func teleport(new_position: Vector2, _fade_effect: bool = true) -> void:
	print_debug("Player: телепортация в ", new_position)
	global_position = new_position
	velocity = Vector2.ZERO
	_play_idle_animation()

func set_last_horizontal_direction(dir: Vector2) -> void:
	last_horizontal_direction = dir

# ==================== СОХРАНЕНИЕ ====================
func get_save_data() -> Dictionary:
	var data = super.get_save_data()
	data.merge({
		"position": {
			"x": global_position.x,
			"y": global_position.y
		},
		"direction": {
			"x": last_movement_direction.x,
			"y": last_movement_direction.y
		},
		"current_animation": current_animation
	})
	return data
