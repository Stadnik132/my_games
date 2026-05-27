extends Camera2D
class_name AdvancedSmoothCamera2D

var target: Node2D
var camera_offset: Vector2 = Vector2.ZERO

func _ready():
	if get_parent():
		target = get_parent()
		top_level = true

func _process(_delta):
	if not target:
		return
	global_position = target.global_position
	offset = camera_offset

func set_temporary_offset(new_offset: Vector2, return_speed: float = 2.0):
	camera_offset = new_offset
	var tween = create_tween()
	tween.tween_property(self, "camera_offset", Vector2.ZERO, return_speed)
