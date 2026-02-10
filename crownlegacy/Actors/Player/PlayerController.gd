# PlayerController.gd
extends CharacterBody2D

@export_category("Настройки движения")
@export var move_speed: float = 200.0
@export var sprint_speed: float = 350.0
@export var acceleration: float = 15.0
@export var friction: float = 20.0

# ==================== КОНСТАНТЫ СОСТОЯНИЙ ====================
# Согласовано с GameStateManager.gd (enum GameState)
const STATE_WORLD = 0       # Свободное перемещение по миру
const STATE_DIALOGUE = 1    # Активен диалог
const STATE_BATTLE = 2      # Бой в реальном времени
const STATE_MENU = 3        # Открыто любое меню
const STATE_CUTSCENE = 4    # Катсцена
const STATE_GAME_OVER = 5   # Конец игры

# ==================== ССЫЛКИ ====================
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D

# ==================== ПЕРЕМЕННЫЕ ====================
var current_animation: String = "idle_down"
var last_movement_direction: Vector2 = Vector2.DOWN
var _can_move: bool = true  # Флаг разрешения движения
var _can_interact: bool = true  # Флаг разрешения взаимодействия
var _in_combat_mode: bool = false # Флаг режима боя. Изначально False, в состоянии BATTLE меняется на True.
var _movement_allowed: bool = true

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func _ready() -> void:
	add_to_group("player")
	
	# Подписываемся на события EventBus
	EventBus.Game.state_changed.connect(_on_game_state_changed)
	EventBus.Game.paused.connect(_on_game_paused)
	print_debug("PlayerController: готов")

# ==================== ФИЗИКА (ДВИЖЕНИЕ) ====================
func _physics_process(delta: float) -> void:
	# Если нельзя двигаться - останавливаемся
	if not _can_move or not _movement_allowed:
		velocity = Vector2.ZERO
		_play_idle_animation()
		return
	
	# Получаем ввод
	var input_vector = _get_input_vector()
	
	# Обрабатываем движение
	if input_vector != Vector2.ZERO:
		_handle_movement(input_vector, delta)
		last_movement_direction = input_vector
	else:
		_handle_stop_movement(delta)
	
	# Применяем движение
	move_and_slide()

# ==================== ОБРАБОТКА ВВОДА ====================
func _input(event: InputEvent) -> void:
	# ВЗАИМОДЕЙСТВИЕ (E) - доступно в WORLD
	if event.is_action_pressed("interact") and _can_interact:
		_handle_interaction()
		get_viewport().set_input_as_handled()
		return
	
	# МЕНЮ (ESC) - можно открыть из WORLD и BATTLE
	if event.is_action_pressed("ui_cancel"):
		if _can_open_menu():
			EventBus.Game.transition_to_menu_requested.emit()
		get_viewport().set_input_as_handled()
		return
	
	# БОЕВОЙ ВВОД - ТОЛЬКО в BATTLE режиме
	if _in_combat_mode:
		# ПОДТВЕРЖДЕНИЕ КАСТА (ЛКМ во время прицеливания)
		if event.is_action_pressed("basic_attack"):
			# Сначала проверяем прицеливание
			if has_node("PlayerCombatComponent"):
				var combat_comp = $PlayerCombatComponent
				if combat_comp.fsm.get_current_state_name() == "Aiming":
					# ЛКМ во время прицеливания = подтверждение каста
					var mouse_pos = get_viewport().get_mouse_position()
					var camera = get_viewport().get_camera_2d()
					var global_mouse_pos = camera.global_position + (mouse_pos - get_viewport().size * 0.5) / camera.zoom
					
					EventBus.Combat.ability_target_confirmed.emit(global_mouse_pos)
					get_viewport().set_input_as_handled()
					return
			
			# Обычная атака
			EventBus.Combat.basic_attack_requested.emit()
			get_viewport().set_input_as_handled()
			return
		
		# Уворот (Shift/Space)
		if event.is_action_pressed("dodge"):
			var dodge_dir = _get_input_vector()
			print("Dodge направление: ", dodge_dir)
			if dodge_dir == Vector2.ZERO:
				dodge_dir = last_movement_direction
			EventBus.Combat.dodge_requested.emit(dodge_dir)
			get_viewport().set_input_as_handled()
			return
		
		# Блок (ПКМ) - начало
		if event.is_action_pressed("block"):
			# Сначала проверяем прицеливание
			if has_node("PlayerCombatComponent"):
				var combat_comp = $PlayerCombatComponent
				if combat_comp.fsm.get_current_state_name() == "Aiming":
					# Отмена прицеливания
					EventBus.Combat.ability_target_cancelled.emit()
					get_viewport().set_input_as_handled()
					return
			
			# Обычный блок
			EventBus.Combat.block_started.emit()
			get_viewport().set_input_as_handled()
			return
		
		# Блок (ПКМ) - окончание
		if event.is_action_released("block"):
			EventBus.Combat.block_ended.emit()
			get_viewport().set_input_as_handled()
			return
		
		# Способности 1-4 (динамическая проверка)
		for i in range(1, 5):
			if event.is_action_pressed("ability_" + str(i)):
				EventBus.Combat.ability_slot_pressed.emit(i-1)
				get_viewport().set_input_as_handled()
				return
# ==================== _can_move ДВИЖЕНИЕ ====================
func _get_input_vector() -> Vector2:
	"""Получает вектор направления от клавиш WASD/Стрелок"""
	var input = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	return input.normalized() if input.length() > 0 else Vector2.ZERO

func _handle_movement(input_vector: Vector2, delta: float) -> void:
	# Рассчёт скорости (ходьба/бег)
	var target_speed = sprint_speed if Input.is_action_pressed("sprint") else move_speed
	var target_velocity = input_vector * target_speed
	
	# Плавное ускорение
	velocity = velocity.lerp(target_velocity, acceleration * delta)
	
	# Анимация
	var anim_direction = _get_animation_direction(input_vector)
	_play_walk_animation(anim_direction)
	current_animation = "walk_" + anim_direction

func _handle_stop_movement(delta: float) -> void:
	# Плавная остановка
	velocity = velocity.lerp(Vector2.ZERO, friction * delta)
	_play_idle_animation()

# ==================== АНИМАЦИИ ====================
func _get_animation_direction(input_vector: Vector2) -> String:
	"""Определяет направление для анимации (4 направления)"""
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

func set_movement_allowed(allowed: bool):
	print("PlayerController: set_movement_allowed(", allowed, ")")
	_movement_allowed = allowed
	
	# ДЕБАГ
	if not allowed:
		velocity = Vector2.ZERO

# ==================== ВЗАИМОДЕЙСТВИЕ ====================
func _handle_interaction() -> void:
	"""Запрос взаимодействия с ближайшим объектом"""
	print_debug("Player: запрос взаимодействия (E)")
	EventBus.Actors.interaction_requested.emit()

# ==================== ОБРАБОТЧИКИ СОСТОЯНИЙ ====================
func _on_game_state_changed(new_state: int, old_state: int) -> void:
	_can_move = false
	_can_interact = false
	_in_combat_mode = false
	
	match new_state:
		STATE_WORLD:
			_can_move = true
			_can_interact = true
			print_debug("Player: режим WORLD - всё доступно")
		
		STATE_DIALOGUE:
			_can_move = false
			_can_interact = false
			print_debug("Player: диалог - всё заблокировано")
		
		STATE_BATTLE:
			_can_move = true
			_can_interact = false
			_in_combat_mode = true
			print_debug("Player: режим боя - только движение")
		
		STATE_MENU:
			_can_move = false
			_can_interact = false
			print_debug("Player: меню - всё заблокировано")
		
		STATE_CUTSCENE:
			_can_move = false
			_can_interact = false
			print_debug("Player: катсцена - всё заблокировано")
		
		STATE_GAME_OVER:
			_can_move = false
			_can_interact = false
			print_debug("Player: конец игры - всё заблокировано")
		
		_:
			push_warning("PlayerController: неизвестное состояние: ", new_state)
			_can_move = true
			_can_interact = true

func _can_open_menu() -> bool:
	"""Проверяет, можно ли открыть меню из текущего состояния"""
	# Нужно получить текущее состояние из GameStateManager
	# Но у нас нет прямой зависимости, поэтому мы должны знать текущий режим
	# Вместо этого проверяем по текущим флагам _can_move и _can_interact
	
	# Меню можно открыть если:
	# 1. Мы можем двигаться (_can_move = true) - это WORLD или BATTLE
	# 2. И мы НЕ в диалоге (можно уточнить, если нужно)
	return _can_move

# ==================== ПУБЛИЧНЫЕ МЕТОДЫ ====================
func force_stop() -> void:
	"""Принудительная остановка (для катсцен)"""
	velocity = Vector2.ZERO
	_play_idle_animation()
	_can_move = false
	_can_interact = false

func restore_control() -> void:
	"""Восстановление контроля"""
	_can_move = true
	_can_interact = true

func _on_game_paused(is_paused: bool) -> void:
	"""Реакция на паузу игры"""
	if is_paused:
		# При паузе можно замедлить/остановить анимации
		if animation_player:
			animation_player.speed_scale = 0.0
	else:
		# Снять паузу с анимаций
		if animation_player:
			animation_player.speed_scale = 1.0

func get_save_data() -> Dictionary:
	"""Возвращает данные для сохранения"""
	return {
		"position": {
			"x": global_position.x,
			"y": global_position.y
		},
		"direction": {
			"x": last_movement_direction.x,
			"y": last_movement_direction.y
		},
		"current_animation": current_animation,
		"can_move": _can_move,
		"can_interact": _can_interact
	}

func teleport(new_position: Vector2, fade_effect: bool = true) -> void:
	"""Телепортация в новую позицию"""
	print_debug("Player: телепортация в ", new_position)
	
	if fade_effect:
		# TODO: эффект затемнения/появления
		pass
	
	global_position = new_position
	velocity = Vector2.ZERO
	_play_idle_animation()
