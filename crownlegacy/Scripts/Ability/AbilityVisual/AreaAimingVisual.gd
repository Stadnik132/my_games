# aiming_visuals/area_aiming_visual.gd
class_name AreaAimingVisual extends BaseAimingVisual

var radius: float = 100.0
var max_range: float = 500.0
var color: Color = Color(1, 0, 0, 0.3)

@onready var circle_sprite: Sprite2D = $CircleSprite
@onready var blocker: Sprite2D = $Blocker

func _ready_setup() -> void:
	if ability:
		radius = ability.effect_radius
		max_range = ability.max_cast_range
		color = ability.targeting_color
	
	# Настраиваем круг
	if circle_sprite:
		var scale_factor = radius / 50.0  # если базовый спрайт 50px
		circle_sprite.scale = Vector2(scale_factor, scale_factor)
		circle_sprite.modulate = color
	
	if blocker:
		blocker.visible = false

func _process(delta: float) -> void:
	# Визуал следует за игроком
	global_position = caster.global_position
	
	var mouse_pos = get_global_mouse_position()
	var distance_from_caster = caster.global_position.distance_to(mouse_pos)
	
	# Ограничиваем позицию круга
	var target_pos: Vector2
	var is_blocked: bool = false
	
	if distance_from_caster <= max_range:
		target_pos = mouse_pos
		is_blocked = false
	else:
		var direction = (mouse_pos - caster.global_position).normalized()
		target_pos = caster.global_position + direction * max_range
		is_blocked = true
	
	# Позиционируем круг (локально относительно визуала, но визуал сам на игроке)
	$CircleSprite.position = to_local(target_pos)
	
	# Меняем цвет
	if circle_sprite:
		circle_sprite.modulate = Color(1, 0, 0, 0.5) if is_blocked else color
	
	# Показываем блокер
	if blocker:
		blocker.visible = is_blocked
		if is_blocked:
			blocker.global_position = target_pos
	
	# Показываем блокер
	if blocker:
		blocker.visible = is_blocked
		if is_blocked:
			blocker.global_position = target_pos

func _get_target_data() -> Dictionary:
	return {
		"position": global_position,
		"radius": radius,
		"type": "area"
	}
