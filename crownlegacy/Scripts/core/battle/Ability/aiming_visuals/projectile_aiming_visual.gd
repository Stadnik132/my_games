# aiming_visuals/projectile_aiming_visual.gd
class_name ProjectileAimingVisual extends BaseAimingVisual

var max_range: float = 500.0
var line_color: Color = Color.YELLOW

@onready var line: Line2D = $Line2D
@onready var target_marker: Sprite2D = $TargetMarker
@onready var blocker: Sprite2D = $Blocker  # NEW! препятствие на конце линии

func _ready_setup() -> void:
	if ability:
		max_range = ability.max_cast_range
		line_color = ability.targeting_color
	
	if line:
		line.default_color = line_color
		line.width = 2
	
	if target_marker:
		target_marker.modulate = line_color
	
	if blocker:
		blocker.visible = false  # пока не показываем

func _process(delta: float) -> void:
	# Визуал следует за игроком (если игрок двигается во время прицеливания)
	global_position = caster.global_position
	
	var mouse_pos = get_global_mouse_position()
	var direction = (mouse_pos - caster.global_position).normalized()
	var distance = caster.global_position.distance_to(mouse_pos)
	
	# Ограничиваем расстояние
	var target_pos: Vector2
	var is_blocked: bool = false
	
	if distance <= max_range:
		target_pos = mouse_pos
		is_blocked = false
	else:
		target_pos = caster.global_position + direction * max_range
		is_blocked = true
	
	# Обновляем линию (от локального (0,0) до цели в локальных координатах)
	if line:
		line.points = [Vector2.ZERO, to_local(target_pos)]
		line.default_color = Color.RED if is_blocked else line_color
	
	# Обновляем маркер цели
	if target_marker:
		target_marker.global_position = target_pos
		target_marker.modulate = Color.RED if is_blocked else line_color
	
	# Показываем блокер
	if blocker:
		blocker.visible = is_blocked
		if is_blocked:
			blocker.global_position = target_pos

func _get_target_data() -> Dictionary:
	var mouse_pos = get_global_mouse_position()
	var direction = (mouse_pos - caster.global_position).normalized()
	var distance = min(caster.global_position.distance_to(mouse_pos), max_range)
	var target_pos = caster.global_position + direction * distance
	
	return {
		"position": target_pos,
		"direction": direction,
		"distance": distance,
		"type": "projectile"
	}
