class_name BerserkEffect extends Node2D

var caster: Node
var duration: float = 10.0
var original_scale: Vector2
var _buff_tween: Tween

func setup(params: Dictionary) -> void:
	caster = params.get("caster")
	duration = params.get("duration", 10.0)
	
	if caster.has_method("get_sprite"):
		var caster_sprite = caster.get_sprite()
		if caster_sprite:
			original_scale = caster_sprite.scale
			_apply_buff_visual(caster_sprite)
	
	if caster.has_method("set_modulate_override"):
		caster.set_modulate_override(Color(1.5, 0.7, 0.2))
	
	call_deferred("_queue_after_duration")

func _apply_buff_visual(sprite: Sprite2D) -> void:
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
	if caster.has_method("clear_modulate_override"):
		caster.clear_modulate_override()
	
	if caster and caster.has_method("get_sprite"):
		var caster_sprite = caster.get_sprite()
		if caster_sprite:
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(caster_sprite, "modulate", Color.WHITE, 0.3)
			tween.tween_property(caster_sprite, "scale", original_scale, 0.3)
			await tween.finished
	
	queue_free()
