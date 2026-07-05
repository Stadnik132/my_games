extends Entity
class_name Player

# ==================== ЭКСПОРТ ====================
@export_category("Настройки движения")
@export var move_speed: float = 200.0
@export var sprint_speed: float = 350.0
@export var acceleration: float = 15.0
@export var friction: float = 20.0
var last_horizontal_direction: Vector2 = Vector2.RIGHT

# ==================== ССЫЛКИ ====================
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var controller: PlayerController = $PlayerController
@onready var combat_component: PlayerCombatComponent = $PlayerCombatComponent
@onready var inventory_component: InventoryComponent = $InventoryComponent
var _player_data: PlayerData

@export var player_data: PlayerData:
	get:
		return _player_data
	set(value):
		_player_data = value
		entity_data = value

# ==================== ПЕРЕМЕННЫЕ СОСТОЯНИЯ ====================
var _current_animation: String = "idle_down"
var last_movement_direction: Vector2 = Vector2.DOWN
var _can_move_in_world: bool = true
var _in_combat_mode: bool = false

# ==================== МИГАНИЕ ====================
var _blink_timer: float = 0.0
var _blink_phase: int = 0
var _blink_interval: float = 0.0

# ==================== ОТЛАДКА ====================
var _debug_timer: float = 0.0

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func _ready():
	super._ready()
	add_to_group("player")
	
	# Настраиваем Hurtbox
	if hurtbox:
		hurtbox.set_entity_owner(self)
		hurtbox.update_layer_from_owner()
	
	# Подключаем сигналы компонентов
	if progression_component:
		progression_component.level_up.connect(_on_level_up)
		progression_component.experience_gained.connect(_on_experience_gained)
	
	# Подключаемся к глобальным состояниям
	EventBus.Game.state_changed.connect(_on_game_state_changed)
	EventBus.Animations.requested.connect(_on_animation_requested)
	
	# ИНИЦИАЛИЗАЦИЯ ИНВЕНТАРЯ (с ожиданием загрузки реестра)
	_init_inventory()
	
	# Мигание — стартовый таймер
	_blink_timer = randf_range(3.0, 6.0)

func _init_inventory() -> void:
	if ItemRegistry.get_item_count() == 0:
		ItemRegistry.registry_updated.connect(_on_item_registry_ready)
	else:
		_add_startup_items()

func _on_item_registry_ready(item_count: int) -> void:
	ItemRegistry.registry_updated.disconnect(_on_item_registry_ready)
	_add_startup_items()

func _add_startup_items() -> void:
	if not inventory_component:
		return
	
	var is_empty = true
	for i in range(inventory_component.max_slots):
		if inventory_component.get_item_at_slot(i):
			is_empty = false
			break
	
	if not is_empty:
		return
	
	var potion = ItemRegistry.get_item("health_potion")
	if potion:
		inventory_component.add_item(potion, 3)
	
	var sword = ItemRegistry.get_item("steel_sword")
	if sword:
		inventory_component.add_item(sword, 1)

# ==================== ДВИЖЕНИЕ ====================
func _physics_process(delta: float) -> void:
	# В бою движение через FSM
	if _in_combat_mode:
		return
	
	# В мире — обычное движение
	if not _can_move_in_world or movement_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		# Показываем idle на основе последнего направления движения
		if not animation_player.is_playing():
			var idle_anim = _get_idle_animation()
			if _current_animation != idle_anim:
				_play_animation(idle_anim)
		return
	
	var input_vector = _get_input_vector()
	if input_vector != Vector2.ZERO:
		_handle_movement(input_vector, delta)
		last_movement_direction = input_vector
	else:
		_handle_stop_movement(delta)
	
	move_and_slide()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_debug_timer += delta
	if _debug_timer >= 1.0:
		_debug_timer = 0.0
		print_debug("[DEBUG] anim='", _current_animation, "' | region_rect=", sprite.region_rect, " | blink_phase=", _blink_phase)

func _update_blink(delta: float) -> void:
	if _blink_phase > 0:
		_blink_timer -= delta
		if _blink_timer <= 0:
			if _blink_phase == 1:
				var dir = _get_idle_direction()
				var blink_anim = "blink_" + dir
				if animation_player.has_animation(blink_anim):
					_play_animation(blink_anim)
					_blink_timer = 0.3
					_blink_phase = 2
				else:
					_blink_phase = 0
					_blink_timer = randf_range(3.0, 6.0)
			elif _blink_phase == 2:
				_play_animation(_get_idle_animation())
				_current_animation = _get_idle_animation()
				_blink_phase = 0
				_blink_timer = randf_range(3.0, 6.0)
	else:
		_blink_timer -= delta
		if _blink_timer <= 0:
			_blink_phase = 1
			_blink_timer = 0.0

func _reset_blink() -> void:
	_blink_phase = 0
	_blink_timer = randf_range(3.0, 6.0)

func _get_idle_direction() -> String:
	if last_movement_direction.y > 0:
		return "down"
	elif last_movement_direction.y < 0:
		return "up"
	elif last_movement_direction.x < 0:
		return "left"
	elif last_movement_direction.x > 0:
		return "right"
	return "down"

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
	
	# Обновляем анимацию
	_update_movement_animation(input_vector)

func _update_movement_animation(input_vector: Vector2) -> void:
	"""Обновляет анимацию движения без перезапуска"""
	var anim_direction = _get_animation_direction(input_vector)
	var target_animation = "walk_" + anim_direction
	
	# Если анимация не изменилась — ничего не делаем
	if target_animation == _current_animation:
		return
	
	# Переключаем анимацию
	if animation_player.has_animation(target_animation):
		_reset_blink()
		_play_animation(target_animation)
		_current_animation = target_animation

func _handle_stop_movement(delta: float) -> void:
	velocity = velocity.lerp(Vector2.ZERO, friction * delta)
	
	# Возвращаемся в idle на основе последнего направления
	var idle_anim = _get_idle_animation()
	
	if idle_anim != _current_animation and _blink_phase == 0:
		_play_animation(idle_anim)
		_current_animation = idle_anim
	
	_update_blink(delta)

func _get_idle_animation() -> String:
	"""Возвращает idle-анимацию на основе last_movement_direction"""
	if last_movement_direction.y > 0:
		return "idle_down"
	elif last_movement_direction.y < 0:
		return "idle_up"
	elif last_movement_direction.x < 0:
		return "idle_left"
	elif last_movement_direction.x > 0:
		return "idle_right"
	
	# Fallback
	return "idle_down"

func get_horizontal_facing_direction() -> Vector2:
	"""Возвращает последнее горизонтальное направление игрока"""
	if abs(velocity.x) > 10:
		return Vector2(sign(velocity.x), 0)
	return last_horizontal_direction

# ==================== АНИМАЦИИ ====================
func _play_animation(anim_name: String) -> void:
	"""Безопасный запуск анимации без перезапуска"""
	if not animation_player.has_animation(anim_name):
		push_warning("Player: анимация не найдена: ", anim_name)
		return

	# Не перезапускаем ту же анимацию
	if animation_player.current_animation == anim_name and animation_player.is_playing():
		return

	# Сбрасываем speed_scale для walk/idle (защита от бага после боя/атаки)
	if anim_name.begins_with("walk") or anim_name.begins_with("idle"):
		animation_player.speed_scale = 1.0

	animation_player.play(anim_name)
	print_debug("Player ANIM: '", anim_name, "' | frame: ", sprite.region_rect)

func _on_animation_requested(target: Node, animation_name: String, duration: float) -> void:
	if target != self:
		return

	if not animation_player.has_animation(animation_name):
		return

	var anim = animation_player.get_animation(animation_name)

	if not animation_name.begins_with("walk") and not animation_name.begins_with("idle"):
		anim.loop_mode = Animation.LOOP_NONE

	_play_animation(animation_name)
	_reset_blink()

	if duration > 0:
		animation_player.speed_scale = animation_player.current_animation_length / duration

		await get_tree().create_timer(duration).timeout
		animation_player.speed_scale = 1.0

func _get_animation_direction(input_vector: Vector2) -> String:
	if abs(input_vector.x) > abs(input_vector.y):
		return "right" if input_vector.x > 0 else "left"
	else:
		return "down" if input_vector.y > 0 else "up"

# ==================== ОБРАБОТЧИКИ СОСТОЯНИЙ ====================
func _on_game_state_changed(new_state: int, _old_state: int) -> void:
	_can_move_in_world = false
	_in_combat_mode = false
	interaction_locked = true
	
	match new_state:
		GameStateManager.GameState.WORLD:
			_can_move_in_world = true
			interaction_locked = false
			_in_combat_mode = false
			movement_locked = false
			var idle_anim = _get_idle_animation()
			_play_animation(idle_anim)
			_current_animation = idle_anim
		
		GameStateManager.GameState.DIALOGUE:
			pass
		
		GameStateManager.GameState.BATTLE:
			_in_combat_mode = true
			var dir = "right" if last_movement_direction.x >= 0 else "left"
			_play_animation("idle_battle_" + dir)
		
		GameStateManager.GameState.MENU, GameStateManager.GameState.CUTSCENE, GameStateManager.GameState.GAME_OVER:
			pass
		
		_:
			push_warning("Player: неизвестное состояние ", new_state)
			_can_move_in_world = true

# ==================== СПЕЦИФИЧНЫЕ ДЛЯ ИГРОКА СИГНАЛЫ ====================
func _on_level_up(new_level: int, stat_increases: Dictionary) -> void:
	EventBus.Player.level_up.emit(new_level, stat_increases)

func _on_experience_gained(amount: int, new_total: int, _next_level: int) -> void:
	EventBus.Player.experience_gained.emit(amount, new_total)

# ==================== ПУБЛИЧНЫЕ МЕТОДЫ ====================
func lock_controls(duration: float) -> void:
	movement_locked = true
	interaction_locked = true
	
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(func():
		movement_locked = false
		interaction_locked = false
	)

func force_stop() -> void:
	velocity = Vector2.ZERO
	movement_locked = true
	interaction_locked = true
	var idle_anim = _get_idle_animation()
	_play_animation(idle_anim)
	_current_animation = idle_anim

func teleport(new_position: Vector2, _fade_effect: bool = true) -> void:
	global_position = new_position
	velocity = Vector2.ZERO
	var idle_anim = _get_idle_animation()
	_play_animation(idle_anim)
	_current_animation = idle_anim

func set_last_horizontal_direction(dir: Vector2) -> void:
	last_horizontal_direction = dir

func get_sprite() -> Sprite2D:
	return sprite

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
		"current_animation": _current_animation
	})
	return data

func load_save_data(data: Dictionary) -> void:
	super.load_save_data(data)
	if data.has("position"):
		global_position = Vector2(data["position"]["x"], data["position"]["y"])
	if data.has("direction"):
		last_movement_direction = Vector2(data["direction"]["x"], data["direction"]["y"])
