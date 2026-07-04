@tool
extends StaticBody2D
class_name Barrier

enum Direction { LEFT, RIGHT, UP, DOWN }

@export var texture: Texture2D:
	set(value):
		texture = value
		if is_inside_tree() and $Sprite2D:
			$Sprite2D.texture = value

@export var direction: Direction = Direction.DOWN:
	set(value):
		direction = value
		if is_inside_tree():
			_update_preview()
@export var auto_close_delay: float = 3.0
@export var close_when_off_screen: bool = true

@export var interaction_offset: Vector2 = Vector2.ZERO:
	set(value):
		interaction_offset = value
		if is_inside_tree() and interaction:
			interaction.position = value

@export var interaction_radius: float = 30.0:
	set(value):
		interaction_radius = value
		if is_inside_tree() and interaction:
			interaction.interaction_radius = value
			interaction._setup_collision()

@export var start_open: bool = false:
	set(value):
		start_open = value
		if is_inside_tree():
			if start_open:
				is_open = false
				_apply_open_immediate()
			else:
				is_open = true
				_apply_closed_immediate()

@export_group("Texture Regions")
## closed LEFT, RIGHT, UP, DOWN, open LEFT, RIGHT, UP, DOWN
@export var texture_regions: Array[Rect2] = [
	Rect2(10, 0, 64, 106),
	Rect2(153, 0, 64, 106),
	Rect2(505, 0, 105, 106),
	Rect2(281, 0, 105, 106),
	Rect2(73, 0, 64, 106),
	Rect2(217, 0, 64, 106),
	Rect2(617, 0, 105, 106),
	Rect2(393, 0, 105, 106),
]

@export_group("Sprite Offset")
@export var closed_offset: Array[Vector2] = [
	Vector2(-23.2, -20),
	Vector2(23.8, -20),
	Vector2(0, -24),
	Vector2(0, 0),
]
@export var open_offset: Array[Vector2] = [
	Vector2(-23.2, -20),
	Vector2(23.8, -20),
	Vector2(0, -20),
	Vector2(0, 0),
]

@onready var interaction: InteractableComponent = $InteractableComponent
@onready var editor_collisions: Node = $EditorCollisions
@onready var collision_a: CollisionShape2D = $CollisionShape2D
@onready var collision_b: CollisionShape2D = $CollisionShape2D2

var is_open: bool = false
var is_player_nearby: bool = false
var auto_close_timer: float = 0.0


func _ready() -> void:
	add_to_group("barriers")

	$Sprite2D.region_enabled = true
	if texture:
		$Sprite2D.texture = texture

	$VisibleOnScreenNotifier2D.screen_entered.connect(_on_screen_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(_on_screen_exited)

	if interaction:
		interaction.position = interaction_offset
		interaction.interaction_radius = interaction_radius
		interaction.interacted.connect(toggle)
		interaction.player_entered_range.connect(_on_player_entered_range)
		interaction.player_exited_range.connect(_on_player_exited_range)

	_update_editor_visibility()

	if start_open:
		is_open = false
		_apply_open_immediate()
	else:
		is_open = false
		_apply_closed_immediate()


func _process(delta: float) -> void:
	if is_open and not is_player_nearby and auto_close_delay > 0:
		auto_close_timer += delta
		if auto_close_timer >= auto_close_delay:
			close()


func _update_preview() -> void:
	if not $Sprite2D:
		return

	$Sprite2D.region_enabled = true
	if start_open:
		$Sprite2D.region_rect = texture_regions[direction + 4]
		$Sprite2D.offset = open_offset[direction]
	else:
		$Sprite2D.region_rect = texture_regions[direction]
		$Sprite2D.offset = closed_offset[direction]
	if interaction:
		interaction.position = interaction_offset
	_update_editor_visibility()
	_setup_collision()


func _setup_collision() -> void:
	if start_open:
		var data1 = _read_collision_data(direction, true, 0)
		var data2 = _read_collision_data(direction, true, 1)
		if data1.is_empty() or data2.is_empty():
			return
		var shape1 = RectangleShape2D.new()
		shape1.size = data1.size
		collision_a.position = data1.position
		collision_a.shape = shape1
		collision_a.disabled = false
		var shape2 = RectangleShape2D.new()
		shape2.size = data2.size
		collision_b.position = data2.position
		collision_b.shape = shape2
		collision_b.disabled = false
	else:
		var data = _read_collision_data(direction, false, 0)
		if data.is_empty():
			return
		var shape = RectangleShape2D.new()
		shape.size = data.size
		collision_a.position = data.position
		collision_a.shape = shape
		collision_a.disabled = false
		collision_b.disabled = true


func _collision_node_name(dir: int, open: bool, idx: int = 0) -> String:
	var dir_names = ["Left", "Right", "Up", "Down"]
	var name = "Open" if open else "Closed"
	name += dir_names[dir]
	if open and idx > 0:
		name += str(idx + 1)
	return name


func _read_collision_data(dir: int, open: bool, idx: int = 0) -> Dictionary:
	if not editor_collisions:
		return {}
	var node_name = _collision_node_name(dir, open, idx)
	if not editor_collisions.has_node(node_name):
		return {}
	var node = editor_collisions.get_node(node_name) as CollisionShape2D
	if not node or not node.shape:
		return {}
	return {"position": node.position, "size": node.shape.size}


func _update_editor_visibility() -> void:
	if not Engine.is_editor_hint():
		return
	if not editor_collisions:
		return
	var show_closed = _collision_node_name(direction, false, 0)
	var show_open1 = _collision_node_name(direction, true, 0)
	var show_open2 = _collision_node_name(direction, true, 1)
	for child in editor_collisions.get_children():
		if child is CollisionShape2D:
			if start_open:
				child.visible = child.name == show_open1 or child.name == show_open2
			else:
				child.visible = child.name == show_closed


func _dir_name() -> String:
	match direction:
		Direction.LEFT: return "left"
		Direction.RIGHT: return "right"
		Direction.UP: return "up"
	return "down"


func open() -> void:
	if is_open:
		return
	is_open = true
	$AnimationPlayer.play("open_" + _dir_name())
	_apply_open_immediate()
	auto_close_timer = 0.0


func close() -> void:
	if not is_open:
		return
	is_open = false
	_apply_closed_immediate()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func _apply_open_immediate() -> void:
	var data1 = _read_collision_data(direction, true, 0)
	var data2 = _read_collision_data(direction, true, 1)
	if data1.is_empty() or data2.is_empty():
		return
	$Sprite2D.region_rect = texture_regions[direction + 4]
	$Sprite2D.offset = open_offset[direction]
	var shape1 = RectangleShape2D.new()
	shape1.size = data1.size
	collision_a.position = data1.position
	collision_a.shape = shape1
	collision_a.disabled = false
	var shape2 = RectangleShape2D.new()
	shape2.size = data2.size
	collision_b.position = data2.position
	collision_b.shape = shape2
	collision_b.disabled = false
	_update_editor_visibility()


func _apply_closed_immediate() -> void:
	var data = _read_collision_data(direction, false, 0)
	if data.is_empty():
		return
	$Sprite2D.region_rect = texture_regions[direction]
	$Sprite2D.offset = closed_offset[direction]
	var shape = RectangleShape2D.new()
	shape.size = data.size
	collision_a.position = data.position
	collision_a.shape = shape
	collision_a.disabled = false
	collision_b.disabled = true
	_update_editor_visibility()


func _on_player_entered_range() -> void:
	is_player_nearby = true
	auto_close_timer = 0.0


func _on_player_exited_range() -> void:
	is_player_nearby = false


func _on_screen_entered() -> void:
	pass


func _on_screen_exited() -> void:
	if close_when_off_screen and is_open:
		close()
