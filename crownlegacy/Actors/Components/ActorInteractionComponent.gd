# ActorInteractionComponent.gd
extends Area2D
class_name ActorInteractionComponent

# ==================== НАСТРОЙКИ ====================
@export var interaction_radius: float = 40.0
@export var show_icon: bool = true

# ==================== ПЕРЕМЕННЫЕ ====================
var _actor: Actor = null
@onready var interaction_icon = $InteractionIcon

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func _ready() -> void:
	if interaction_icon and show_icon:
		interaction_icon.hide()
	
	# Настраиваем форму коллизии
	var shape = $CollisionShape2D
	if shape and shape.shape is CircleShape2D:
		shape.shape.radius = interaction_radius
	
	# Подключаем сигналы
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func setup(actor: Actor) -> void:
	"""Настройка компонента для работы с актёром"""
	_actor = actor
	print_debug("InteractionComponent настроен для: ", actor.display_name)

# ==================== ОБРАБОТКА КОЛЛИЗИЙ ====================
func _on_body_entered(body: Node) -> void:
	print_debug("ActorInteractionComponent: тело вошло - ", body.name)
	
	if body.is_in_group("player") and _actor:
		print_debug("Игрок вошёл в зону актёра: ", _actor.display_name)
		_actor.set_player_in_range(true)
		update_visibility()

func _on_body_exited(body: Node) -> void:
	print_debug("ActorInteractionComponent: тело вышло - ", body.name)
	if body.is_in_group("player") and _actor:
		_actor.set_player_in_range(false)
		update_visibility()

# ==================== УПРАВЛЕНИЕ ВИДИМОСТЬЮ ====================
func update_visibility() -> void:
	"""Обновление видимости иконки взаимодействия"""
	if not interaction_icon or not show_icon:
		return
	
	if not _actor:
		interaction_icon.hide()
		return
	
	# Показываем иконку если:
	# 1. Игрок в зоне
	# 2. Актёр интерактивен
	# 3. Актёр жив
	# 4. Актёр в мирном режиме
	if (_actor._player_in_range and 
		_actor.is_interactive and 
		_actor.is_alive() and
		_actor.current_mode == "peaceful"):
		interaction_icon.show()
	else:
		interaction_icon.hide()

func play_feedback() -> void:
	"""Анимация иконки при взаимодействии"""
	if interaction_icon:
		var tween = create_tween()
		tween.tween_property(interaction_icon, "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(interaction_icon, "scale", Vector2.ONE, 0.1)

# ==================== ПУБЛИЧНЫЕ МЕТОДЫ ====================
func set_active(value: bool) -> void:
	"""Включение/выключение компонента"""
	set_process(value)
	set_physics_process(value)
	monitoring = value
	monitorable = value
	
	if not value and interaction_icon:
		interaction_icon.hide()

func get_interaction_radius() -> float:
	"""Получить радиус взаимодействия"""
	return interaction_radius

func set_interaction_radius(radius: float) -> void:
	"""Установить радиус взаимодействия"""
	interaction_radius = radius
	var shape = $CollisionShape2D
	if shape and shape.shape is CircleShape2D:
		shape.shape.radius = radius

func set_interactive(value: bool) -> void:
	"""Включить/выключить возможность взаимодействия"""
	if _actor:
		_actor.is_interactive = value
	update_visibility()

func get_actor_info() -> Dictionary:
	"""Информация об актёре"""
	if _actor and _actor.has_method("get_actor_info"):
		return _actor.get_actor_info()
	return {}
