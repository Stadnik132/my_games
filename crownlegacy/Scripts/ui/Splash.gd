extends CanvasLayer

@export var next_scene: String = "res://Scenes/UI/MainMenu.tscn"
@export var fade_in_time: float = 2.0
@export var display_time: float = 2.0
@export var fade_out_time: float = 2.0

@onready var texture_rect: TextureRect = $ColorRect/TextureRect

var _skip_requested: bool = false
var _current_tween: Tween

func _ready() -> void:
	# Подгоняем размер логотипа под экран
	_resize_logo()
	
	# Запускаем анимацию заставки
	_start_splash_sequence()

func _input(event: InputEvent) -> void:
	# Любое нажатие пропускает заставку
	if event.is_pressed() and not event.is_echo():
		_skip_splash()

func _start_splash_sequence() -> void:
	# Начинаем с прозрачного
	texture_rect.modulate.a = 0.0
	
	# Плавное появление
	_current_tween = create_tween()
	_current_tween.tween_property(texture_rect, "modulate:a", 1.0, fade_in_time)
	
	await _current_tween.finished
	if _skip_requested:
		_finish_and_exit()
		return
	
	# Ждем время показа
	await _wait_with_skip(display_time)
	if _skip_requested:
		_finish_and_exit()
		return
	
	# Плавное исчезновение
	_current_tween = create_tween()
	_current_tween.tween_property(texture_rect, "modulate:a", 0.0, fade_out_time)
	
	await _current_tween.finished
	_finish_and_exit()

func _wait_with_skip(time: float) -> void:
	var elapsed: float = 0.0
	while elapsed < time and not _skip_requested:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

func _skip_splash() -> void:
	if _skip_requested:
		return
	_skip_requested = true
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	_finish_and_exit()

func _finish_and_exit() -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	get_tree().change_scene_to_file(next_scene)

func _resize_logo() -> void:
	if not texture_rect.texture:
		return
	
	var screen_size = DisplayServer.window_get_size()
	var texture_size = texture_rect.texture.get_size()
	
	var screen_size_f = Vector2(screen_size.x, screen_size.y)
	
	var scale_factor = min(
		screen_size_f.x * 0.8 / texture_size.x,
		screen_size_f.y * 0.8 / texture_size.y
	)
	
	texture_rect.scale = Vector2(scale_factor, scale_factor)
	texture_rect.position = (screen_size_f - texture_size * scale_factor) / 2
