class_name EnemyStatusBar extends Control

@onready var hp_bar: ProgressBar = $VBoxContainer/HPBar
@onready var resolve_bar: ProgressBar = $VBoxContainer/ResolveBar
@onready var name_label: Label = $VBoxContainer/NameLabel

var target: Node
var _health: HealthComponent
var _resolve: Node

func setup(entity: Node) -> void:
	target = entity
	_health = entity.get_node_or_null("HealthComponent") as HealthComponent
	_resolve = entity.get_node_or_null("ResolveComponent")

	if _health:
		_health.health_changed.connect(_update_hp)
		_update_hp(_health.get_current_health(), 0, _health.get_max_health())

	var entity_name = "Enemy"
	if "entity_data" in entity:
		var ed = entity.entity_data
		if ed and "entity_name" in ed:
			entity_name = ed.entity_name
	elif "actor_data" in entity:
		var ad = entity.actor_data
		if ad and "display_name" in ad:
			entity_name = ad.display_name
	name_label.text = entity_name

	if _resolve:
		_resolve.resolve_changed.connect(_update_resolve)
		_update_resolve(_resolve.current_resolve, 0, _resolve.max_resolve)
	else:
		resolve_bar.hide()

	visibility_changed.connect(_update_position)

func _update_hp(new_val: int, _old: int, max_val: int) -> void:
	hp_bar.max_value = max_val
	hp_bar.value = new_val

func _update_resolve(new_val: int, _old: int, max_val: int) -> void:
	resolve_bar.max_value = max_val
	resolve_bar.value = new_val

func _process(_delta: float) -> void:
	_update_position()

func _update_position() -> void:
	if not target or not is_instance_valid(target):
		queue_free()
		return
	if not visible:
		return
	var cam = get_viewport().get_camera_2d()
	if not cam:
		return
	global_position = cam.get_canvas_transform() * target.global_position - Vector2(0, 40)
