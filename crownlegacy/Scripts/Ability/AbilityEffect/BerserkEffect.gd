class_name BerserkEffect extends Node2D

var caster: Node
var duration: float = 10.0
var original_modulate: Color
var original_scale: Vector2
var _buff_tween: Tween  # отдельный твин для баффа

@onready var particles: GPUParticles2D = $GPUParticles2D

func setup(params: Dictionary) -> void:
	caster = params.get("caster")
	duration = params.get("duration", 10.0)
	
	global_position = caster.global_position
	
	if caster.has_method("get_sprite"):
		var caster_sprite = caster.get_sprite()
		if caster_sprite:
			original_modulate = caster_sprite.modulate
			original_scale = caster_sprite.scale
			_apply_buff_visual(caster_sprite)
	
	if particles:
		particles.emitting = true
	
	call_deferred("_queue_after_duration")

func _apply_buff_visual(sprite: Sprite2D) -> void:
	print("Применяю бафф: original = ", original_modulate)
	# Убиваем предыдущий твин если был
	if _buff_tween and _buff_tween.is_running():
		_buff_tween.kill()
	
	_buff_tween = create_tween()
	_buff_tween.set_parallel(true)
	_buff_tween.tween_property(sprite, "modulate", Color(1.5, 0.7, 0.2), 0.3)
	_buff_tween.tween_property(sprite, "scale", original_scale * 1.3, 0.3)

func _queue_after_duration() -> void:
	await get_tree().create_timer(duration).timeout
	_cleanup()

func _cleanup() -> void:
	print("Снимаю бафф: original = ", original_modulate)
	if caster and caster.has_method("get_sprite"):
		var caster_sprite = caster.get_sprite()
		if caster_sprite:
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(caster_sprite, "modulate", original_modulate, 0.3)
			tween.tween_property(caster_sprite, "scale", original_scale, 0.3)
			await tween.finished
	
	queue_free()
