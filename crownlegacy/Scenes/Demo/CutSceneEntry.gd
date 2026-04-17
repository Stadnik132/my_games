# CutsceneEntry.gd
extends Node
class_name CutsceneEntry

## Узел кат-сцены при входе в локацию.
## Управляет движением игрока, камерой и запуском диалога.

@export var player: Player
@export var start_position: Marker2D
@export var target_position: Marker2D
@export var dialogue_timeline: String = "CutSceneEntry"
@export var walk_duration: float = 8.0

@onready var player_camera: Camera2D = player.get_node("Camera2D")
@onready var cutscene_camera: Camera2D = get_parent().get_node("CutsceneCamera")

signal finished

func _exit_tree() -> void:
	# Отписываемся от сигнала при удалении узла
	if EventBus.Dialogue.ended.is_connected(_on_dialogue_ended):
		EventBus.Dialogue.ended.disconnect(_on_dialogue_ended)


func _ready() -> void:

	# Подписываемся на окончание диалога
	EventBus.Dialogue.ended.connect(_on_dialogue_ended)

	
	# Ставим игрока на стартовую позицию
	player.global_position = start_position.global_position

	# Блокируем управление игроком
	player.movement_locked = true
	player.interaction_locked = true

	# Запускаем кат-сцену
	_start()

func _start() -> void:

	# Переключаем камеры
	_enable_cutscene_camera()

	# Сообщаем о начале кат-сцены
	EventBus.Game.cutscene_requested.emit("entry")

	# Пауза перед началом
	await get_tree().create_timer(0.5).timeout

	# Двигаем игрока к целевой позиции
	await _move_player_to(target_position.global_position, walk_duration)

	# Запускаем диалог

	EventBus.Game.dialogue_requested.emit(dialogue_timeline)

func _on_dialogue_ended() -> void:
	"""Вызывается при завершении диалога"""
	# Завершаем кат-сцену
	_finish()

func _move_player_to(target: Vector2, duration: float) -> void:
	"""Перемещает игрока к целевой позиции с анимацией ходьбы"""
	# Устанавливаем направление движения вверх
	player.last_movement_direction = Vector2.UP
	
	# Отладка: проверяем speed_scale перед запуском
	print_debug("CutSceneEntry: ПЕРЕД запуском анимации, speed_scale = ", player.animation_player.speed_scale)
	print_debug("CutSceneEntry: walk_duration = ", duration)

	# Запускаем анимацию ходьбы БЕЗ duration, чтобы НЕ менять speed_scale
	EventBus.Animations.requested.emit(player, "walk_up", 0.0)
	
	# Отладка: проверяем speed_scale после запуска
	print_debug("CutSceneEntry: ПОСЛЕ запуска анимации, speed_scale = ", player.animation_player.speed_scale)

	# Запускаем движение
	var tween = create_tween()
	tween.tween_property(player, "global_position", target, duration)

	# Ждём завершения движения
	await tween.finished
	
	# Переключаемся на idle_down (персонаж смотрит вниз после кат-сцены)
	player.last_movement_direction = Vector2.DOWN
	player._play_animation("idle_down")
	player._current_animation = "idle_down"
	
	print_debug("CutSceneEntry: После idle, speed_scale = ", player.animation_player.speed_scale)


func _finish() -> void:
	"""Завершает кат-сцену и возвращает управление игроку"""

	
	# Переключаем камеры обратно
	_enable_player_camera()


	# Разблокируем управление
	player.movement_locked = false
	player.interaction_locked = false


	# Сообщаем о возвращении в мир
	EventBus.Game.world_requested.emit()


	# Эмитим сигнал завершения и удаляем узел
	finished.emit()

	queue_free()

func _enable_cutscene_camera() -> void:
	"""Включает камеру кат-сцены"""
	player_camera.enabled = false
	cutscene_camera.enabled = true
	cutscene_camera.make_current()

func _enable_player_camera() -> void:
	"""Включает камеру игрока"""
	cutscene_camera.enabled = false
	player_camera.enabled = true
	player_camera.make_current()
