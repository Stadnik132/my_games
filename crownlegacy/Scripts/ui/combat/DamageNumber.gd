extends Node2D
class_name DamageNumber

var label: Label
var _tween: Tween

var damage_amount: int = 0
var is_critical_hit: bool = false


func _ready() -> void:
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = str(damage_amount)
	add_child(label)

	if is_critical_hit:
		label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.1))
		label.add_theme_font_size_override("font_size", 28)
	else:
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_font_size_override("font_size", 18)

	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "position:y", position.y - 40.0, 0.8).set_ease(Tween.EASE_OUT)
	_tween.tween_property(label, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	_tween.finished.connect(queue_free)
