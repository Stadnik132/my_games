extends Entity
class_name Actor

# ==================== РЕЖИМЫ ====================
const MODE_WORLD = "world"
const MODE_BATTLE = "battle"

# ==================== СИГНАЛЫ ====================
signal mode_changed(new_mode: String, old_mode: String)  # Добавляем
signal interaction_started(actor: Actor)                  # Добавляем

# ==================== ЭКСПОРТ ====================
@export_category("Данные актёра")
@export var actor_data: ActorData

@export_category("Компоненты (опционально)")
@export var interaction_component_path: NodePath
@export var combat_component_path: NodePath
@export var ai_component_path: NodePath

# ==================== ССЫЛКИ ====================
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var interaction_component = get_node_or_null(interaction_component_path) as ActorInteractionComponent
@onready var actor_combat_component = get_node_or_null(combat_component_path) as ActorCombatComponent
@onready var ai_component = get_node_or_null(ai_component_path)

# ==================== ПЕРЕМЕННЫЕ СОСТОЯНИЯ ====================
var current_mode: String
var is_interactive: bool = true  # Добавляем (берём из actor_data, но для доступа)
var _player_in_range: bool = false
var _is_in_dialogue: bool = false

# Направление для анимаций и атак
var facing_direction: String = "down"
var last_facing_direction: String = "down"

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func _ready() -> void:
	super._ready()
	
	if not actor_data:
		push_warning("Actor: actor_data не назначен для ", name)
		return
	
	is_interactive = actor_data.is_interactive
	current_mode = actor_data.initial_mode
	
	_setup_components()
	_setup_connections()
	
	add_to_group("actors")
	
	_apply_mode()
	
	print_debug("Actor создан: ", actor_data.display_name, " (режим: ", current_mode, ")")

func _setup_components() -> void:
	if interaction_component:
		interaction_component.setup(self)
	
	if actor_combat_component:
		actor_combat_component.setup(self, actor_data)
	
	if ai_component and ai_component.has_method("setup"):
		ai_component.setup(self)

func _setup_connections() -> void:
	EventBus.Actors.interaction_requested.connect(_on_interaction_requested)
	EventBus.Dialogue.started.connect(_on_dialogue_started)
	EventBus.Dialogue.ended.connect(_on_dialogue_ended)

# ==================== ФИЗИКА И АНИМАЦИИ ====================
func _physics_process(delta: float) -> void:
	move_and_slide()
	
	_update_facing_direction()
	_update_animation()

func _update_facing_direction() -> void:
	if velocity.length() > 10:
		var dir = velocity.normalized()
		var angle = rad_to_deg(dir.angle())
		if angle < 0:
			angle += 360
		
		if angle >= 337.5 or angle < 22.5:
			facing_direction = "right"
		elif angle >= 22.5 and angle < 67.5:
			facing_direction = "down_right"
		elif angle >= 67.5 and angle < 112.5:
			facing_direction = "down"
		elif angle >= 112.5 and angle < 157.5:
			facing_direction = "down_left"
		elif angle >= 157.5 and angle < 202.5:
			facing_direction = "left"
		elif angle >= 202.5 and angle < 247.5:
			facing_direction = "up_left"
		elif angle >= 247.5 and angle < 292.5:
			facing_direction = "up"
		elif angle >= 292.5 and angle < 337.5:
			facing_direction = "up_right"
		
		last_facing_direction = facing_direction

func _get_cardinal_direction() -> String:
	var dir = get_facing_direction()
	match dir:
		"up", "up_left", "up_right":
			return "up"
		"down", "down_left", "down_right":
			return "down"
		"left":
			return "left"
		"right":
			return "right"
		_:
			return "down"

func _update_animation() -> void:
	if not animation_player:
		return
	
	if velocity.length() > 5:
		_play_walk_animation()
	else:
		_play_idle_animation()

func _play_walk_animation() -> void:
	var anim_name = "walk_" + _get_cardinal_direction()
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)

func _play_idle_animation() -> void:
	var anim_name = "idle_" + _get_cardinal_direction()
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)

func get_facing_direction() -> String:
	if velocity.length() > 10:
		return facing_direction
	return last_facing_direction

# ==================== РЕЖИМЫ ====================
func change_mode(new_mode: String) -> void:
	if new_mode == current_mode:
		return
	
	var old_mode = current_mode
	current_mode = new_mode
	
	print_debug(actor_data.display_name, ": смена режима ", old_mode, " → ", new_mode)
	
	_apply_mode()
	
	mode_changed.emit(new_mode, old_mode)
	EventBus.Actors.mode_changed.emit(self, new_mode, old_mode)

func _apply_mode() -> void:
	match current_mode:
		MODE_BATTLE:
			is_interactive = false
			lock_interaction(true)
			if not is_in_group("enemies"):
				add_to_group("enemies")
			if actor_combat_component:
				actor_combat_component.set_active(true)
			if ai_component:
				ai_component.set_active(true)
		
		MODE_WORLD:
			is_interactive = true
			lock_interaction(false)
			if is_in_group("enemies"):
				remove_from_group("enemies")
			if actor_combat_component:
				actor_combat_component.set_active(false)
			if ai_component:
				ai_component.set_active(false)
	
	if hurtbox:
		hurtbox.update_layer_from_owner()
	
	var hitbox = get_node_or_null("Hitbox") as Hitbox
	if hitbox:
		hitbox.update_layer_from_owner()

func become_enemy(combat_manager: Node = null) -> void:
	print_debug(actor_data.display_name, ": становлюсь врагом!")
	change_mode(MODE_BATTLE)
	
	if actor_combat_component and combat_manager:
		actor_combat_component.setup_combat(combat_manager)

# ==================== ВЗАИМОДЕЙСТВИЕ ====================
func _on_interaction_requested() -> void:
	if _can_interact():
		start_interaction()

func _can_interact() -> bool:
	return (is_interactive and 
			_player_in_range and 
			not _is_in_dialogue and
			is_alive() and
			current_mode == MODE_WORLD and
			not interaction_locked)

func start_interaction() -> void:
	if not _can_interact():
		return
	
	_is_in_dialogue = true
	print_debug(actor_data.display_name, ": начало взаимодействия")
	
	interaction_started.emit(self)
	EventBus.Actors.interaction_started.emit(self)
	
	if actor_data.dialogue_timeline != "":
		EventBus.Game.dialogue_requested.emit(actor_data.dialogue_timeline)
	else:
		print_debug("У актёра ", actor_data.display_name, " нет диалога")
		_is_in_dialogue = false
	
	if interaction_component:
		interaction_component.play_feedback()

# ==================== ДИАЛОГИ ====================
func _on_dialogue_started(timeline_name: String) -> void:
	if timeline_name == actor_data.dialogue_timeline:
		_is_in_dialogue = true
		if interaction_component:
			interaction_component.update_visibility()

func _on_dialogue_ended() -> void:
	_is_in_dialogue = false
	if interaction_component:
		interaction_component.update_visibility()

# ==================== СМЕРТЬ ====================
func _on_died() -> void:
	super._on_died()
	
	print_debug(actor_data.display_name, ": смерть")
	
	is_interactive = false
	_player_in_range = false
	
	if interaction_component:
		interaction_component.set_active(false)
	
	if actor_combat_component:
		actor_combat_component.set_active(false)
	
	if ai_component:
		ai_component.set_active(false)
	
	_play_death_effect()

func _play_death_effect() -> void:
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(0.3, 0.3, 0.3, 0.5), 0.5)
		tween.tween_callback(_finalize_death)

func _finalize_death() -> void:
	hide()

# ==================== УТИЛИТЫ ====================
func set_player_in_range(value: bool) -> void:
	_player_in_range = value
	if interaction_component:
		interaction_component.update_visibility()

func get_actor_info() -> Dictionary:
	if actor_data:
		return actor_data.get_actor_info()
	return {}

func get_actor_id() -> String:
	return actor_data.actor_id if actor_data else ""

# ==================== ПУБЛИЧНЫЕ МЕТОДЫ ====================
func enter_combat(combat_manager: Node) -> void:
	print_debug(actor_data.display_name, ": вступает в бой")
	if actor_combat_component:
		actor_combat_component.setup_combat(combat_manager)
	change_mode(MODE_BATTLE)

func check_decision_triggers() -> Dictionary:
	if actor_combat_component:
		return actor_combat_component.check_decision_triggers()
	return {}

func mark_trigger_used(trigger_type: String, trigger_value: Variant) -> void:
	if actor_combat_component:
		actor_combat_component.mark_trigger_used(trigger_type, trigger_value)
