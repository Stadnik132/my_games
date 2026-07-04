extends Node

const SHADER = preload("res://Scripts/shaders/vignette_grain.gdshader")

var _canvas_layer: CanvasLayer
var _color_rect: ColorRect
var _material: ShaderMaterial

@export var enabled: bool = true:
	set(v):
		enabled = v
		if _canvas_layer:
			_canvas_layer.visible = enabled

@export var vignette_intensity: float = 0.4:
	set(v):
		vignette_intensity = v
		if _material:
			_material.set_shader_parameter("vignette_intensity", v)

@export var vignette_radius: float = 0.6:
	set(v):
		vignette_radius = v
		if _material:
			_material.set_shader_parameter("vignette_radius", v)

@export var vignette_smoothness: float = 0.3:
	set(v):
		vignette_smoothness = v
		if _material:
			_material.set_shader_parameter("vignette_smoothness", v)

@export var watercolor_amount: float = 0.0:
	set(v):
		watercolor_amount = v
		if _material:
			_material.set_shader_parameter("watercolor_amount", v)

@export var paper_roughness: float = 0.08:
	set(v):
		paper_roughness = v
		if _material:
			_material.set_shader_parameter("paper_roughness", v)

@export var color_wash_intensity: float = 0.15:
	set(v):
		color_wash_intensity = v
		if _material:
			_material.set_shader_parameter("color_wash_intensity", v)

@export var color_wash_tint: Color = Color(0.95, 0.9, 0.85)


func _ready() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 128
	_canvas_layer.visible = enabled
	add_child(_canvas_layer)

	_color_rect = ColorRect.new()
	_color_rect.color = Color.TRANSPARENT
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas_layer.add_child(_color_rect)

	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_color_rect.material = _material

	_apply_all()
	call_deferred("_update_size")


func _apply_all() -> void:
	_material.set_shader_parameter("vignette_intensity", vignette_intensity)
	_material.set_shader_parameter("vignette_radius", vignette_radius)
	_material.set_shader_parameter("vignette_smoothness", vignette_smoothness)
	_material.set_shader_parameter("watercolor_amount", watercolor_amount)
	_material.set_shader_parameter("paper_roughness", paper_roughness)
	_material.set_shader_parameter("color_wash_intensity", color_wash_intensity)
	_material.set_shader_parameter("color_wash_tint", color_wash_tint)


func _update_size() -> void:
	if not _color_rect or not get_viewport():
		call_deferred("_update_size")
		return
	_color_rect.size = get_viewport().get_visible_rect().size

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_update_size()
