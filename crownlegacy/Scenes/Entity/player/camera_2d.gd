extends Camera2D
class_name AdvancedSmoothCamera2D

var target: Node2D
var camera_offset: Vector2 = Vector2.ZERO
var _offset_tween: Tween

@export var smooth_speed: float = 5.0

func _ready():
	if get_parent():
		target = get_parent()
		top_level = true

func _process(delta):
	if not target:
		return
	global_position = global_position.lerp(target.global_position, smooth_speed * delta)
	offset = camera_offset

func set_temporary_offset(new_offset: Vector2, return_speed: float = 2.0):
	camera_offset = new_offset
	if _offset_tween and _offset_tween.is_valid():
		_offset_tween.kill()
	_offset_tween = create_tween()
	_offset_tween.tween_property(self, "camera_offset", Vector2.ZERO, return_speed)
