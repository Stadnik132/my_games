# VillageBorderArea.gd
extends Area2D

## Область-граница деревни. Не даёт игроку выйти за пределы.
## Когда игрок входит — отталкивает назад и показывает сообщение.

# ==================== ЭКСПОРТ ====================
@export_category("Сообщения при выходе")
@export var border_phrases: Array[String] = [
	"У нас здесь ещё есть дела.",
	"Лучше не уходить сейчас.",
	"Ещё не время уходить.",
	"Нам нужно закончить дела здесь.",
	"Подождите, тут ещё есть что сделать."
]

@export var push_back_distance: float = 30.0
@export var player_lock_duration: float = 1.5

# ==================== ПЕРЕМЕННЫЕ ====================
var _player_in_area: bool = false
var _last_push_time: float = -1000.0
var _push_cooldown: float = 0.0

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

# ==================== ОБРАБОТЧИКИ ====================
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not _player_in_area:
		_player_in_area = true
		_handle_player_entered(body)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_area = false

func _handle_player_entered(player: Node) -> void:
	"""Обрабатывает вход игрока в пограничную зону"""
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_push_time < _push_cooldown:
		return  # Кулдаун
	
	_last_push_time = now
	
	# Отталкиваем игрока обратно в деревню
	_push_player_back(player)
	
	# Блокируем управление
	_lock_player_control(player)
	
	# Показываем сообщение
	_show_border_message()
	
	print_debug("VillageBorderArea: игрок попытался уйти, оттолкнут назад")

func _push_player_back(player: Node) -> void:
	"""Отталкивает игрока обратно к центру деревни"""
	# Направляем игрока к центру области
	var center = global_position
	var push_direction = (center - player.global_position).normalized()
	player.global_position += push_direction * push_back_distance

func _lock_player_control(player: Node) -> void:
	"""Блокирует управление игрока"""
	if player.has_method("lock_controls"):
		player.lock_controls(player_lock_duration)

func _show_border_message() -> void:
	"""Показывает случайное сообщение о том, что не стоит уходить"""
	if border_phrases.is_empty():
		return
	
	var message = border_phrases[randi() % border_phrases.size()]
	
	# Пока выводим в консоль, потом можно заменить на UI
	print_debug("VillageBorderArea: ", message)
	
	# TODO: Если есть система уведомлений, вызвать её:
	# EventBus.UI.notification.emit(message, 3.0)
