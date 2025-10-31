# PlayerWorld.gd
extends CharacterBody2D
# ================== STATE MACHINE ==================
# Система состояний Клауса - определяет что он может делать в каждый момент

# enum - перечисление возможных состояний
enum PlayerState { WORLD, DIALOGUE, MENU, CUTSCENE }

# Текущее состояние игрока (current_state - текущее состояние)
var current_state: PlayerState = PlayerState.WORLD

# Функция для смены состояния
func change_state(new_state: PlayerState) -> void:
	# Меняем текущее состояние на новое
	current_state = new_state
	# Выводим для отладки
	print("Состояние изменено: ", get_state_name(new_state))
	
	# При переходе в WORLD сбрасываем скорость
	if new_state == PlayerState.WORLD:
		velocity = Vector2.ZERO
		
# Функция для получения названия состояния
func get_state_name(state: PlayerState) -> String:
	match state:
		PlayerState.WORLD: return "WORLD"
		PlayerState.DIALOGUE: return "DIALOGUE"
		PlayerState.MENU: return "MENU"
		PlayerState.CUTSCENE: return "CUTSCENE"
		_: return "UNKNOWN"

# Сцена Клауса для перемещения по карте мира
# CharacterBody2D - замена KinematicBody2D в Godot 4

# @onready - переменная инициализируется, когда нода готова
@onready var sprite = $Sprite2D # Ссылка на ноду Sprite (Дочерняя)
@onready var animation_player = $AnimationPlayer # Ссылка на AnimationPlayer

# export - делает переменную видимой в редакторе(Можно редактировать)
@export var speed: int = 200 # Скорость движения пикселей в секунду

# В Godot 4 velocity УЖЕ есть в CharacterBody2D, не нужно объявлять заново!
# CharacterBody2D уже имеет встроенную переменную velocity

# _ready() вызывается, когда объект появляется на сцене
func _ready() -> void:
	print("PlayerWorld загружен на карту")

# _physics_process(delta) вместо _process для физики в Godot 4
func _physics_process(delta: float) -> void:
	# Проверка можно ли двигаться в текущем состоянии
	match current_state:
		PlayerState.WORLD:
			handle_world_state()
		PlayerState.DIALOGUE:
			handle_dialogue_state()
		PlayerState.MENU:
			handle_menu_state()
		PlayerState.CUTSCENE:
			handle_cutscene_state()
	
	# Обработка состояния WORLD (Свободное перемещение)
func handle_world_state() -> void:	
		# Вызываем функцию обработки ввода
	get_input()
		# Вызываем функцию движения
	move_and_slide()  # В Godot 4 вызываем без параметров, используем встроенную velocity
		# Вызываем функцию обновления анимации
	update_animation()
	
	# Обработка состояния DIALOGUE	
func handle_dialogue_state() -> void:
	# В диалоге нельзя двигаться
	velocity = Vector2.ZERO
	update_animation()
	# ДОБАВИТЬ ОБРАБОТКУ ДИАЛОГОВЫХ КЛАВИШ

	# Обработка состояния MENU
	
	# Обработка состояния MENU
func handle_menu_state() -> void:
	velocity = Vector2.ZERO
	update_animation()

	# Обработка состояния CUTSCENE
func handle_cutscene_state() -> void:
	velocity = Vector2.ZERO
	update_animation()

	# Функция обработки ввода с клавиатуры
func get_input() -> void:
	# Обнуляем скорость в начале каждого кадра
	velocity = Vector2.ZERO
	
	# Проверяем нажатые клавиши и устанавливаем скорость
	if Input.is_action_pressed("ui_right"): # Если нажата стрелка вправо
		velocity.x += 1 # Двигаемся вправо
	if Input.is_action_pressed("ui_left"): # Если нажата стрелка влево
		velocity.x -= 1 # Двигаемся влево
	if Input.is_action_pressed("ui_down"): # Если нажата стрелка вверх
		velocity.y += 1 # Двигаемся вверх
	if Input.is_action_pressed("ui_up"): # Если нажата стрелка вниз
		velocity.y -= 1 # Двигаемся вниз
		
	# Нормализуем вектор, чтобы диагональное движение не было быстрее
	if velocity.length() > 0:
		velocity = velocity.normalized() * speed
		
	# Функция обновления анимации
func update_animation() -> void:
	if velocity == Vector2.ZERO: # Если стоим на месте
		animation_player.play("idle") # Проигрываем анимацию покоя
	else: # Если двигаемся
		animation_player.play("walk")
		
		# Поворачиваем спрайт в сторону движениявы
		if velocity.x != 0:
			# sign() возвращает -1, если отрицательное, 1, если положительное
			sprite.flip_h = velocity.x < 0 # Отражаем спрайт, если идем влево
			
	# ВРЕМЕННАЯ ФУНКЦИЯ ДЛЯ ТЕСТИРОВАНИЯ СВЯЗИ С PlayerData
func _input(event: InputEvent) -> void:
	# Тестовые клавиши для проверки состояния
	if event.is_action_pressed("ui_accept"): # Пробел
		if current_state == PlayerState.WORLD:
		# В мире пробел начинает диалог
			change_state(PlayerState.DIALOGUE)
			print("Начало диалога...")
		elif current_state == PlayerState.DIALOGUE:
			change_state(PlayerState.WORLD)
			print("Конец диалога")

	if event.is_action_pressed("ui_cancel"): # Escape
		if current_state == PlayerState.WORLD:
		# В мире Escape открывает меню
			change_state(PlayerState.MENU)
			print("Меню открыто")
		elif current_state == PlayerState.MENU:
			change_state(PlayerState.WORLD)
			print("Меню закрыто")
		
	# Тест связи с PlayerData (только в состоянии WORLD)
	if event.is_action_pressed("ui_select") and current_state == PlayerState.WORLD:  # Ctrl
		if has_node("/root/PlayerData"):
			get_node("/root/PlayerData").change_health(-10)
			print("Здоровье Клауса: ", get_node("/root/PlayerData").health)
