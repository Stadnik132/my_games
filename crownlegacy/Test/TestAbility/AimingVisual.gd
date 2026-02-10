extends Node2D
class_name AimingVisual

@onready var aiming_line: Line2D = $AimingLine
@onready var aiming_circle: Sprite2D = $AimingCircle

func _ready():
	hide_all()

func show_line():
	aiming_line.visible = true
	aiming_circle.visible = false

func show_circle(radius: float):
	aiming_circle.visible = true
	aiming_line.visible = false
	# Масштабируем под радиус
	aiming_circle.scale = Vector2(radius / 32.0, radius / 32.0)

func hide_all():
	aiming_line.visible = false
	aiming_circle.visible = false

func update_line(start_pos: Vector2, end_pos: Vector2):
	# Переводим в локальные координаты
	aiming_line.points = [to_local(start_pos), to_local(end_pos)]

func update_circle(center_pos: Vector2):
	global_position = center_pos

# Опционально: настройки цвета
func set_line_color(color: Color):
	aiming_line.default_color = color

func set_circle_color(color: Color):
	aiming_circle.modulate = color
