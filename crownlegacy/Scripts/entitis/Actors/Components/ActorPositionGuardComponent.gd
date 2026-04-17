# ActorPositionGuardComponent.gd
extends Node
class_name ActorPositionGuardComponent

## Компонент "пасхалки" — защищает Actor от выталкивания игроком.
## Если игрок выталкивает Actor за пределы patrol_radius,
## Actor отталкивает игрока, произносит фразу и возвращается на место.

# ==================== ЭКСПОРТ ====================
@export_category("Настройки защиты позиции")
@export var patrol_radius: float = 50.0  # Радиус, в котором Actor может ходить
@export var push_distance: float = 70.0  # На сколько отталкивается игрок
@export var push_cooldown: float = 10.0  # Кулдаун между фразами (секунды)
@export var return_speed: float = 50.0  # Скорость возврата на позицию
@export var player_control_lock_duration: float = 3.0  # Блокировка управления игрока после толчка

# ==================== ФРАЗЫ ПРИ ТОЛКАНИИ ====================
var push_phrases: Array[String] = [
	"Эй, ты что делаешь?",
	"Не толкайся!",
	"Аккуратнее!",
	"Чего толкаешься?",
	"Эй, полегче!",
	"Ты чего?! Я тут стою!"
]

# ==================== ПЕРЕМЕННЫЕ СОСТОЯНИЯ ====================
var _actor: Actor
var _initial_position: Vector2 = Vector2.ZERO
var _is_pushed_away: bool = false
var _returning_to_position: bool = false
var _last_push_time: float = -1000.0  # Время последнего толкания

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func setup(actor: Actor) -> void:
	"""Инициализирует компонент, сохраняя ссылку на Actor"""
	_actor = actor
	_initial_position = actor.global_position
	print_debug("ActorPositionGuardComponent: начальная позиция сохранена: ", _initial_position)

# ==================== ОБНОВЛЕНИЕ (вызывается из Actor._physics_process) ====================
func process_physics(_delta: float) -> void:
	"""Вызывается каждый кадр из Actor._physics_process()"""
	if _returning_to_position:
		_check_return_to_position()
	else:
		_check_if_pushed_away()

# ==================== ПРОВЕРКА ТОЛКАНИЯ ====================
func _check_if_pushed_away() -> void:
	"""Проверяет, вытолкнул ли игрок Actor за пределы патрульного радиуса"""
	if _actor.current_mode != Actor.MODE_WORLD:
		return  # В бою не проверяем
	
	var distance = _actor.global_position.distance_to(_initial_position)
	if distance > patrol_radius:
		_is_pushed_away = true
		_handle_pushed_away()

func _handle_pushed_away() -> void:
	"""Actor реагирует на то, что его вытолкнули"""
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_push_time < push_cooldown:
		return  # Кулдаун, не повторяем слишком часто
	
	_last_push_time = now
	
	# Находим игрока и отталкиваем его
	var player = _get_player_nearby()
	if player:
		# Отталкиваем игрока
		var push_direction = (player.global_position - _actor.global_position).normalized()
		player.global_position += push_direction * push_distance
		
		# Блокируем управление игрока
		_lock_player_control(player)
		
		# Actor поворачивается к игроку
		_face_toward_player(player.global_position)
		
		# Воспроизводим фразу
		_play_push_dialogue()
	
	# Начинаем возвращение на место
	_returning_to_position = true
	_is_pushed_away = false
	print_debug("ActorPositionGuardComponent: Actor вытолкнут! Возвращаюсь на позицию...")

func _get_player_nearby() -> Node:
	"""Находит игрока поблизости"""
	for body in _actor.get_tree().get_nodes_in_group("player"):
		if body.global_position.distance_to(_actor.global_position) < patrol_radius * 3:
			return body
	return null

func _face_toward_player(player_pos: Vector2) -> void:
	"""Actor поворачивается в сторону игрока"""
	var direction = (player_pos - _actor.global_position).normalized()
	if abs(direction.x) > abs(direction.y):
		_actor.last_facing_direction = "left" if direction.x < 0 else "right"
	else:
		_actor.last_facing_direction = "down" if direction.y > 0 else "up"

func _play_push_dialogue() -> void:
	"""Воспроизводит случайную фразу при толкании"""
	# Выбираем случайную фразу
	var phrase = push_phrases[randi() % push_phrases.size()]
	
	# Выводим в консоль
	print_debug("ActorPositionGuardComponent: ", _actor.actor_id, " — ", phrase)
	
	# TODO: Если хотите вызвать настоящий диалог, раскомментируйте:
	# EventBus.Game.dialogue_requested.emit("actor_pushed_" + _actor.actor_id)

func _lock_player_control(player: Node) -> void:
	"""Блокирует управление игрока на player_control_lock_duration секунд"""
	if player.has_method("lock_controls"):
		player.lock_controls(player_control_lock_duration)
		print_debug("ActorPositionGuardComponent: управление игрока заблокировано на ", player_control_lock_duration, "с")

# ==================== ВОЗВРАТ НА ПОЗИЦИЮ ====================
func _check_return_to_position() -> void:
	"""Actor возвращается на начальную позицию"""
	var distance = _actor.global_position.distance_to(_initial_position)
	
	# Если уже на месте - останавливаемся
	if distance < 5.0:
		_actor.global_position = _initial_position
		_actor.velocity = Vector2.ZERO
		_actor.last_movement_direction = Vector2.DOWN
		
		# Сбрасываем анимацию на idle_down
		if _actor.has_method("_play_animation"):
			_actor._play_animation("idle_down")
		
		_returning_to_position = false
		print_debug("ActorPositionGuardComponent: Actor вернулся на начальную позицию")
		return
	
	# Двигаемся к начальной позиции
	var direction = (_initial_position - _actor.global_position).normalized()
	_actor.velocity = direction * return_speed
	
	# Обновляем направление для анимации
	_actor.last_movement_direction = direction
	_actor._update_facing_direction()

# ==================== СБРОС ====================
func reset() -> void:
	"""Сбрасывает компонент (например, после боя)"""
	_returning_to_position = false
	_is_pushed_away = false
	_last_push_time = -1000.0
	_initial_position = _actor.global_position
	print_debug("ActorPositionGuardComponent: компонент сброшен, новая позиция: ", _initial_position)
