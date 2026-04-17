# Village.gd
extends Node2D

## Управляет fade-in эффектом при входе в сцену и нарастанием музыки.

@export var fade_duration: float = 8.0  # Общая длительность появления экрана
@export var music_start_ratio: float = 0.5  # С какой доли fade-in начинать музыку (0.5 = середина)

@onready var cutscene_entry: CutsceneEntry = $CutsceneEntry
@onready var music_village: AudioStreamPlayer = $MusicVillage
@onready var black_overlay: ColorRect = $CanvasLayer/BlackOverlay

func _ready() -> void:
	# Начинаем с полностью чёрного экрана
	if black_overlay:
		black_overlay.modulate = Color(1, 1, 1, 1.0)

	# Отключаем автоплей музыки если он включён
	if music_village:
		music_village.stop()
		music_village.volume_db = -80.0  # Полная тишина

	# Запускаем fade-in
	_start_fade_in()

	# Кат-сцена запустится автоматически через _ready() в CutsceneEntry

func _start_fade_in() -> void:
	if not black_overlay:
		return

	# Рассчитываем тайминги
	var music_delay = fade_duration * music_start_ratio  # Когда начать музыку
	var music_fade_duration = fade_duration - music_delay  # Длительность нарастания музыки

	# Анимация исчезновения чёрного экрана
	var fade_tween = create_tween()
	fade_tween.tween_property(black_overlay, "modulate:a", 0.0, fade_duration)
	fade_tween.set_trans(Tween.TRANS_LINEAR)
	fade_tween.set_ease(Tween.EASE_IN)

	# Запуск музыки с середины fade-in
	await get_tree().create_timer(music_delay).timeout

	if music_village and not music_village.playing:
		music_village.play()
		# Плавное нарастание громкости
		var volume_tween = create_tween()
		volume_tween.tween_method(_set_volume, -20.0, 0.0, music_fade_duration)

func _set_volume(value: float) -> void:
	if music_village:
		music_village.volume_db = value
