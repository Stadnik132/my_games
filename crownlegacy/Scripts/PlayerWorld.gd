# PlayerWorld.gd
extends CharacterBody2D

# Ссылки на ноды
@onready var sprite = $Sprite2D
@onready var animation_player = $AnimationPlayer

# Настройки движения
@export var speed: int = 200  # Скорость движения в пикселях в секунду

func _ready() -> void:
	print("PlayerWorld загружен на карту")
	add_to_group("player")  # Добавляем в группу для легкого доступа

func _physics_process(delta: float) -> void:
	# Теперь управление состоянием через GameStateManager
	if GameStateManager.can_player_move():
		handle_world_state()
	else:
		velocity = Vector2.ZERO
		update_animation()

# Обработчик состояния свободного перемещения
func handle_world_state() -> void:
	get_input()        # Получаем ввод от игрока
	move_and_slide()   # Двигаем персонажа с учетом физики
	update_animation() # Обновляем анимации

# Обработчик состояния диалога
func handle_dialogue_state() -> void:
	velocity = Vector2.ZERO  # Блокируем движение
	update_animation()       # Обновляем анимации

# Обработчик состояния меню
func handle_menu_state() -> void:
	velocity = Vector2.ZERO  # Блокируем движение
	update_animation()       # Обновляем анимации

# Обработчик состояния катсцены
func handle_cutscene_state() -> void:
	velocity = Vector2.ZERO  # Блокируем движение
	update_animation()       # Обновляем анимации

# Обрабатывает ввод с клавиатуры
func get_input() -> void:
	velocity = Vector2.ZERO  # Сбрасываем скорость
	
	# Проверяем нажатые клавиши движения
	if Input.is_action_pressed("ui_right"):
		velocity.x += 1
	if Input.is_action_pressed("ui_left"):
		velocity.x -= 1
	if Input.is_action_pressed("ui_down"):
		velocity.y += 1
	if Input.is_action_pressed("ui_up"):
		velocity.y -= 1
		
	# Нормализуем вектор для диагонального движения
	if velocity.length() > 0:
		velocity = velocity.normalized() * speed

# Обновляет анимации в зависимости от движения
func update_animation() -> void:
	if velocity == Vector2.ZERO:
		animation_player.play("idle")  # Анимация покоя
	else:
		animation_player.play("walk")  # Анимация ходьбы
		
		# Поворачиваем спрайт в сторону движения
		if velocity.x != 0:
			sprite.flip_h = velocity.x < 0  # Отражаем если движемся влево

# Функция отпрыгивания для боевой позиции
func jump_back() -> void:
	print("Клаус отпрыгивает в боевую позицию!")
	# Простая анимация отпрыгивания
	var tween = create_tween()
	tween.tween_property(self, "position", position + Vector2(-50, 0), 0.3)
