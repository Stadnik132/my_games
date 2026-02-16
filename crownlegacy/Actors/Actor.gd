extends CharacterBody2D
class_name Actor

# ==================== НАСТРОЙКИ ====================
@export_category("Основные настройки")
@export var display_name: String = "NPC"
@export var actor_id: String = "unnamed_actor"
@export var dialogue_timeline: String = ""
@onready var sprite: Sprite2D = $Sprite2D

@export_category("Состояние")
@export var max_health: int = 100
@export var initial_mode: String = "peaceful"  # peaceful/hostile
@export var is_interactive: bool = true

const MODE_PEACEFUL = "peaceful"
const MODE_HOSTILE = "hostile" 

@export_category("Компоненты (опционально)")
@export var interaction_component_path: NodePath
@export var combat_component_path: NodePath
@export var ai_component_path: NodePath
@export var ai_vision_path: NodePath
@export var ai_brain_path: NodePath
@export var ai_move_path: NodePath

# ==================== СИГНАЛЫ ====================
signal health_changed(current: int, max: int)
signal mode_changed(new_mode: String, old_mode: String)
signal interaction_started(actor: Actor)
signal actor_died(actor: Actor)

# ==================== ПЕРЕМЕННЫЕ ====================
var current_health: int
var current_mode: String
var _player_in_range: bool = false
var _is_in_dialogue: bool = false

# Компоненты
@onready var interaction_component = get_node_or_null(interaction_component_path)
@onready var combat_component = get_node_or_null(combat_component_path)
@onready var ai_component = get_node_or_null(ai_component_path)
@onready var ai_vision = get_node_or_null(ai_vision_path)
@onready var ai_brain = get_node_or_null(ai_brain_path)
@onready var ai_move = get_node_or_null(ai_move_path)

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func _ready() -> void:
	
	current_health = max_health
	current_mode = initial_mode
	
	_setup_components()
	_setup_connections()
	
	add_to_group("actors")
	print_debug("Actor создан: ", display_name, " (режим: ", current_mode, ")")


func _setup_components() -> void:
	if interaction_component:
		interaction_component.setup(self)
	
	if combat_component:
		combat_component.setup(self)
		if combat_component.has_signal("health_changed"):
			combat_component.health_changed.connect(_on_combat_health_changed)
		if combat_component.has_signal("died"):
			combat_component.died.connect(_on_combat_death)
	
	if ai_component:
		ai_component.setup(self)
	if ai_vision and ai_vision.has_method("set_active"):
		ai_vision.set_active(false)
	if ai_brain and ai_brain.has_method("set_active"):
		ai_brain.set_active(false)
	if ai_move and ai_move.has_method("set_active"):
		ai_move.set_active(false)


func _setup_connections() -> void:
	EventBus.Actors.interaction_requested.connect(_on_interaction_requested)
	EventBus.Dialogue.started.connect(_on_dialogue_started)
	EventBus.Game.world_requested.connect(_on_dialogue_ended)
	EventBus.Game.state_changed.connect(_on_game_state_changed)


func _physics_process(delta):
	if velocity.length() > 5 and sprite:
		var direction = velocity.normalized()
		sprite.rotation = lerp_angle(sprite.rotation, direction.angle(), 10.0 * delta)
	elif sprite:
		sprite.rotation = lerp_angle(sprite.rotation, 0, 5.0 * delta)


# ==================== ВЗАИМОДЕЙСТВИЕ ====================
func _on_interaction_requested() -> void:
	if _can_interact():
		start_interaction()


func _can_interact() -> bool:
	return (is_interactive and 
			_player_in_range and 
			not _is_in_dialogue and
			is_alive() and
			current_mode == MODE_PEACEFUL)


func start_interaction() -> void:
	"""Начало взаимодействия с актёром"""
	if not _can_interact():
		return
	
	_is_in_dialogue = true
	
	print_debug(display_name, ": начало взаимодействия")
	
	interaction_started.emit(self)
	EventBus.Actors.interaction_started.emit(self)
	
	if dialogue_timeline != "":
		EventBus.Game.dialogue_requested.emit(dialogue_timeline)
	else:
		print_debug("У актёра ", display_name, " нет диалога")
		_is_in_dialogue = false
	
	_play_interaction_feedback()


func _play_interaction_feedback() -> void:
	var interaction_comp = get_node_or_null(interaction_component_path)
	if interaction_comp and interaction_comp.has_method("play_feedback"):
		interaction_comp.play_feedback()


# ==================== БОЙ ====================
func apply_combat_damage_data(damage_data: DamageData, source: Node = null) -> void:
	if combat_component and combat_component.has_method("take_damage"):
		combat_component.take_damage(damage_data, source)
	else:
		push_warning("CombatComponent не найден или не поддерживает DamageData")


func _on_combat_health_changed(current: int, max: int) -> void:
	current_health = current
	max_health = max
	health_changed.emit(current, max)


func _on_combat_death(killer: Node = null) -> void:
	"""Смерть в бою"""
	print_debug(display_name, ": смерть в бою")
	
	is_interactive = false
	_player_in_range = false
	
	if interaction_component:
		interaction_component.set_active(false)
	
	if combat_component:
		combat_component.set_active(false)
	
	if ai_component:
		ai_component.set_active(false)
	
	_play_death_effect(killer)
	
	actor_died.emit(self)
	EventBus.Actors.died.emit(self)


func _play_death_effect(killer: Node = null) -> void:
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(0.3, 0.3, 0.3, 0.5), 0.5)
		tween.tween_callback(_finalize_death)


func _finalize_death() -> void:
	hide()
	set_process(false)
	set_physics_process(false)
	queue_free()


# ==================== РЕЖИМЫ ====================
func change_mode(new_mode: String) -> void:
	if new_mode == current_mode:
		return
	
	var old_mode = current_mode
	current_mode = new_mode
	
	print_debug(display_name, ": смена режима ", old_mode, " → ", new_mode)
	
	match new_mode:
		MODE_HOSTILE:
			_on_become_hostile()
			if not is_in_group("enemies"):
				add_to_group("enemies")
		
		MODE_PEACEFUL:
			_on_become_peaceful()
			if is_in_group("enemies"):
				remove_from_group("enemies")
	
	mode_changed.emit(new_mode, old_mode)
	EventBus.Actors.mode_changed.emit(self, new_mode, old_mode)
func _on_become_hostile() -> void:
	print_debug("!!! _on_become_hostile ВЫЗВАН для ", display_name)
	is_interactive = false
	
	if combat_component:
		combat_component.set_active(true)
	
	if ai_component:
		ai_component.set_active(true)
	if ai_vision and ai_vision.has_method("set_active"):
		ai_vision.set_active(true)
	if ai_brain and ai_brain.has_method("set_active"):
		ai_brain.set_active(true)
	if ai_move and ai_move.has_method("set_active"):
		ai_move.set_active(true)


func _on_become_peaceful() -> void:
	is_interactive = true
	
	if combat_component:
		combat_component.set_active(false)
	
	if ai_component:
		ai_component.set_active(false)
	
	if ai_vision and ai_vision.has_method("set_active"):
		ai_vision.set_active(false)
	if ai_brain and ai_brain.has_method("set_active"):
		ai_brain.set_active(false)
	if ai_move and ai_move.has_method("set_active"):
		ai_move.set_active(false)


func become_enemy(combat_manager: Node = null) -> void:
	print_debug(display_name, ": становлюсь врагом!")
	change_mode(MODE_HOSTILE)  # ← УЖЕ ЭМИТИТ
	
	if combat_component:
		if combat_manager:
			combat_component.setup_combat(combat_manager)
		else:
			var cm = get_tree().get_first_node_in_group("combat_manager")
			if cm:
				combat_component.setup_combat(cm)


func _apply_hostile_appearance() -> void:
	if sprite:
		print_debug(display_name, ": внешний вид изменён на враждебный")


# ==================== ДИАЛОГИ ====================
func _on_dialogue_started(timeline_name: String) -> void:
	if timeline_name == dialogue_timeline:
		_is_in_dialogue = true


func _on_dialogue_ended() -> void:
	_is_in_dialogue = false


# ==================== УТИЛИТЫ ====================
func set_player_in_range(value: bool) -> void:
	_player_in_range = value
	if interaction_component:
		interaction_component.update_visibility()


func is_alive() -> bool:
	return current_health > 0


func get_health_percentage() -> float:
	return float(current_health) / max_health if max_health > 0 else 0.0


func get_actor_info() -> Dictionary:
	return {
		"actor_id": actor_id,
		"display_name": display_name,
		"current_health": current_health,
		"max_health": max_health,
		"current_mode": current_mode,
		"is_interactive": is_interactive,
		"dialogue_timeline": dialogue_timeline
	}


func _on_game_state_changed(new_state: int, old_state: int) -> void:
	# Только для обратной совместимости, может быть удалён позже
	pass


func get_actor_id() -> String:
	return actor_id


# ==================== ПУБЛИЧНЫЕ МЕТОДЫ ====================
func enter_combat(combat_manager: Node) -> void:
	print_debug(display_name, ": вступает в бой")
	
	if combat_component and combat_component.has_method("setup_combat"):
		combat_component.setup_combat(combat_manager)
	
	change_mode(MODE_HOSTILE)


func check_decision_triggers() -> Dictionary:
	if combat_component and combat_component.has_method("check_decision_triggers"):
		return combat_component.check_decision_triggers()
	return {}


func mark_trigger_used(trigger_type: String) -> void:
	if combat_component and combat_component.has_method("mark_trigger_used"):
		combat_component.mark_trigger_used(trigger_type)
