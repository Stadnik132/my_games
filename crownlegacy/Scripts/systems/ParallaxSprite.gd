extends Sprite2D

@export var motion_scale: Vector2 = Vector2(0.05, 1.0)

var _anchor: Vector2
var _camera_start: Vector2
var _camera_ready: bool = false

func _ready():
	_anchor = global_position

func _process(_delta):
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	if not _camera_ready:
		_camera_start = camera.global_position
		_camera_ready = true

	var camera_delta = camera.global_position - _camera_start
	global_position = _anchor + camera_delta * motion_scale
