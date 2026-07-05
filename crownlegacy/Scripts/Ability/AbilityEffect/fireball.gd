extends Projectile
class_name FireballProjectile

@export var flying_animation: String = "fly"
@export var hit_animation: String = "explode"
@export var hit_scene: PackedScene  # опционально: отдельная сцена взрыва
@export var audio_hit: AudioStream  # звук попадания

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var audio_player: AudioStreamPlayer2D = null

func setup(params: Dictionary) -> void:
	super.setup(params)  # вызываем родительский setup (настройка урона, скорости и т.д.)
	
	# Проверяем наличие audio_player (опционально)
	audio_player = get_node_or_null("AudioStreamPlayer2D")
	
	# Запускаем анимацию полёта
	if animated_sprite and flying_animation:
		animated_sprite.play(flying_animation)
	
	# Поворачиваем спрайт в направлении полёта
	if animated_sprite:
		animated_sprite.rotation = direction.angle()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)  # двигаемся как обычный снаряд
	
	# Опционально: вращаем спрайт, если нужно
	# animated_sprite.rotation = direction.angle()

func _on_hit() -> void:
	# Проигрываем анимацию попадания
	if animated_sprite and hit_animation:
		animated_sprite.play(hit_animation)
		animated_sprite.animation_finished.connect(_cleanup, CONNECT_ONE_SHOT)
	else:
		_cleanup()

func _cleanup() -> void:
	# Воспроизводим звук попадания
	if audio_player and audio_hit:
		audio_player.stream = audio_hit
		audio_player.play()

	# Создаём отдельную сцену взрыва
	if hit_scene:
		var explosion = hit_scene.instantiate()
		explosion.global_position = global_position
		get_tree().current_scene.add_child(explosion)

	queue_free()
