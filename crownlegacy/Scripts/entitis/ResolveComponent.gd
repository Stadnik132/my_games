class_name ResolveComponent extends Node

signal resolve_changed(new_value: int, old_value: int, max_value: int)
signal surrendered

@export var max_resolve: int = 100
@export var current_resolve: int = 100
@export var regen_per_second: float = 0.0
@export var surrender_threshold: float = 0.0

var _entity: Entity
var _regen_accum: float = 0.0
var _resisted: bool = false

func _ready() -> void:
	_entity = get_parent() as Entity
	add_to_group("resolve_components")

func take_resolve_damage(amount: int) -> void:
	var old = current_resolve
	current_resolve = clampi(current_resolve - amount, 0, max_resolve)
	if current_resolve != old:
		resolve_changed.emit(current_resolve, old, max_resolve)
		if current_resolve <= max_resolve * surrender_threshold:
			_resisted = true
			surrendered.emit()

func _process(delta: float) -> void:
	if regen_per_second <= 0 or current_resolve >= max_resolve:
		return
	if _resisted and current_resolve <= max_resolve * (surrender_threshold + 0.1):
		return
	_regen_accum += regen_per_second * delta
	var gain = int(_regen_accum)
	if gain > 0:
		var old = current_resolve
		current_resolve = clampi(current_resolve + gain, 0, max_resolve)
		if current_resolve != old:
			resolve_changed.emit(current_resolve, old, max_resolve)
		_regen_accum -= gain

func is_surrendered() -> bool:
	return _resisted and current_resolve <= max_resolve * surrender_threshold

func reset() -> void:
	current_resolve = max_resolve
	_resisted = false
