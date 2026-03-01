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
	_actor = actor
	print_debug("InteractionComponent настроен для: ", actor.display_name)

# ==================== ОБРАБОТКА КОЛЛИЗИЙ ====================
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and _actor:
		_actor.set_player_in_range(true)
		update_visibility()

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player") and _actor:
		_actor.set_player_in_range(false)
		update_visibility()

# ==================== УПРАВЛЕНИЕ ВИДИМОСТЬЮ ====================
func update_visibility() -> void:
	if not interaction_icon or not show_icon:
		return
	
	if not _actor:
		interaction_icon.hide()
		return
	
	# Показываем иконку если выполняются условия
	if (_actor._player_in_range and 
		_actor.is_interactive and 
		_actor.is_alive() and
		_actor.current_mode == Actor.MODE_WORLD and
		not _actor._is_in_dialogue):
		interaction_icon.show()
	else:
		interaction_icon.hide()

func play_feedback() -> void:
	if interaction_icon:
		var tween = create_tween()
		tween.tween_property(interaction_icon, "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(interaction_icon, "scale", Vector2.ONE, 0.1)

# ==================== ПУБЛИЧНЫЕ МЕТОДЫ ====================
func set_active(value: bool) -> void:
	set_process(value)
	set_physics_process(value)
	monitoring = value
	monitorable = value
	
	if not value and interaction_icon:
		interaction_icon.hide()

func get_interaction_radius() -> float:
	return interaction_radius

func set_interaction_radius(radius: float) -> void:
	interaction_radius = radius
	var shape = $CollisionShape2D
	if shape and shape.shape is CircleShape2D:
		shape.shape.radius = radius

func set_interactive(value: bool) -> void:
	if _actor:
		_actor.is_interactive = value
	update_visibility()
