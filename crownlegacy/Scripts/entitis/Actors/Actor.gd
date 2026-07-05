extends Entity
class_name Actor

# ==================== РЕЖИМЫ ====================
enum Mode { WORLD, BATTLE }

# ==================== ЭКСПОРТ ====================
@export_category("Данные актёра")
@export var entity_id: String = "Actor"
@export var initial_mode: int = Mode.WORLD
@export var detect_range: float = 0.0

# ==================== ССЫЛКИ ====================
@export_category("Ссылки")
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var combat_component: ActorCombatComponent = $ActorCombatComponent
@onready var ai_controller: AIController = $AIController
@onready var brain_component: AIBrain = $AIBrain
@onready var patrol_component: EnemyPatrolComponent = get_node_or_null("EnemyPatrolComponent") as EnemyPatrolComponent
@onready var resolve_component: ResolveComponent = get_node_or_null("ResolveComponent") as ResolveComponent

var _actor_data: ActorData

@export var actor_data: ActorData:
	get:
		return _actor_data
	set(value):
		_actor_data = value
		entity_data = value

# ==================== ПЕРЕМЕННЫЕ СОСТОЯНИЯ ====================
var current_mode: int = Mode.WORLD
var _in_combat_mode: bool = false
var last_facing_direction: String = "down"
var _is_in_dialogue: bool = false

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func _ready() -> void:
	super._ready()

	if actor_data and actor_data is Resource:
		var new_data = actor_data.duplicate(true)
		actor_data = new_data
		_update_component_data(new_data)

	current_mode = initial_mode
	add_to_group("actors")
	add_to_group("interactable")

	if hurtbox:
		hurtbox.set_entity_owner(self)
		hurtbox.update_layer_from_owner()

	if combat_component:
		combat_component.setup(self, actor_data)

	if ability_component and actor_data:
		var has_real = false
		for id in actor_data.ability_slot_assignments:
			if id != "":
				has_real = true
				break
		if has_real:
			ability_component.initial_slot_assignments = actor_data.ability_slot_assignments
		ability_component.setup(self)

	if ai_controller:
		ai_controller.setup(self)

	if combat_component and combat_component.get_fsm():
		_register_surrender_state()

	if resolve_component:
		resolve_component.surrendered.connect(_on_resolve_depleted)

	if patrol_component:
		patrol_component.setup(self)

	EventBus.Dialogue.started.connect(_on_dialogue_started)
	EventBus.Dialogue.ended.connect(_on_dialogue_ended)
	EventBus.Combat.started.connect(_on_combat_started)
	EventBus.Combat.ended.connect(_on_combat_ended)
	EventBus.Animations.requested.connect(_on_animation_requested)

	_play_idle_animation()
	_apply_mode()

# ==================== ФИЗИКА ====================
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if detect_range > 0 and current_mode == Mode.WORLD:
		var player = get_tree().get_first_node_in_group("player")
		if player and global_position.distance_to(player.global_position) <= detect_range:
			EventBus.Combat.start_combat_requested.emit([self])

	if _in_combat_mode:
		if velocity.length() > 10:
			sprite.flip_h = velocity.x < 0
			last_facing_direction = "right" if velocity.x >= 0 else "left"
		return

	if patrol_component:
		patrol_component.update(delta)
		move_and_slide()

	_update_animation()

# ==================== АНИМАЦИИ ====================
func _play_animation(anim_name: String) -> void:
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)

func _update_animation() -> void:
	if velocity.length() > 10:
		_update_facing_direction()
		_play_walk_animation()
	else:
		_play_idle_animation()

func _update_facing_direction() -> void:
	var angle = rad_to_deg(velocity.angle())
	if angle < 0:
		angle += 360

	if angle >= 337.5 or angle < 22.5:
		last_facing_direction = "right"
	elif angle >= 22.5 and angle < 67.5:
		last_facing_direction = "down_right"
	elif angle >= 67.5 and angle < 112.5:
		last_facing_direction = "down"
	elif angle >= 112.5 and angle < 157.5:
		last_facing_direction = "down_left"
	elif angle >= 157.5 and angle < 202.5:
		last_facing_direction = "left"
	elif angle >= 202.5 and angle < 247.5:
		last_facing_direction = "up_left"
	elif angle >= 247.5 and angle < 292.5:
		last_facing_direction = "up"
	elif angle >= 292.5 and angle < 337.5:
		last_facing_direction = "up_right"

func get_cardinal_direction() -> String:
	match last_facing_direction:
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

func _play_walk_animation() -> void:
	var dir = get_cardinal_direction()
	var anim_name = "walk_" + dir
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)

func _play_idle_animation() -> void:
	if _in_combat_mode:
		var dir = "right" if get_horizontal_facing_direction() == Vector2.RIGHT else "left"
		var anim_name = "idle_battle_" + dir
		if animation_player.has_animation(anim_name):
			animation_player.play(anim_name)
		return

	var dir = get_cardinal_direction()
	var anim_name = "idle_" + dir
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)

# ==================== РЕЖИМЫ ====================
func change_mode(new_mode: int) -> void:
	if new_mode == current_mode:
		return

	var old_mode = current_mode
	current_mode = new_mode

	_apply_mode()

	EventBus.Actors.mode_changed.emit(self, new_mode, old_mode)

func stop_ai() -> void:
	if ai_controller:
		ai_controller.set_active(false)
	velocity = Vector2.ZERO
	move_and_slide()
	_play_idle_animation()

func _apply_mode() -> void:
	match current_mode:
		Mode.BATTLE:
			if not is_in_group("enemies"):
				add_to_group("enemies")
			if ai_controller:
				ai_controller.set_active(true)
			_in_combat_mode = true
			if combat_component:
				combat_component.enter_combat()

		Mode.WORLD:
			if is_in_group("enemies"):
				remove_from_group("enemies")
			if ai_controller:
				ai_controller.set_active(false)
			_in_combat_mode = false
			velocity = Vector2.ZERO
			if combat_component:
				combat_component.exit_combat()

	if hurtbox:
		hurtbox.update_layer_from_owner()

# ==================== ВЗАИМОДЕЙСТВИЕ ====================
func interact() -> void:
	if _is_in_dialogue or current_mode != Mode.WORLD or interaction_locked:
		return

	_is_in_dialogue = true
	EventBus.Actors.interaction_started.emit(self)

	if not actor_data:
		_is_in_dialogue = false
		return

	var timeline_to_play = actor_data.timeline_name
	if actor_data.dialogue_used and actor_data.repeat_timeline_name != "":
		timeline_to_play = actor_data.repeat_timeline_name

	if timeline_to_play != "":
		EventBus.Game.dialogue_requested.emit(timeline_to_play)
		actor_data.dialogue_used = true
	else:
		_is_in_dialogue = false

# ==================== ДИАЛОГИ ====================
func _on_dialogue_started(timeline_name: String) -> void:
	if actor_data and timeline_name == actor_data.timeline_name:
		_is_in_dialogue = true

func _on_dialogue_ended() -> void:
	_is_in_dialogue = false

func reset_after_spare() -> void:
	_is_in_dialogue = false

	if current_mode != Mode.WORLD:
		change_mode(Mode.WORLD)

	interaction_locked = false

	if ai_controller:
		ai_controller.set_active(false)

# ==================== БОЙ ====================
func enter_combat(combat_manager: Node = null) -> void:
	change_mode(Mode.BATTLE)
	if combat_component:
		combat_component.enter_combat()

func _on_combat_started(enemies: Array) -> void:
	if self in enemies:
		change_mode(Mode.BATTLE)
		if combat_component:
			combat_component.enter_combat()
		var dir = "right" if get_horizontal_facing_direction() == Vector2.RIGHT else "left"
		_play_animation("idle_battle_" + dir)

func _on_combat_ended(_victory: bool) -> void:
	if is_alive():
		change_mode(Mode.WORLD)

func _on_animation_requested(target: Node, animation_name: String, duration: float) -> void:
	if target != self:
		return

	if not animation_player.has_animation(animation_name):
		return

	var anim = animation_player.get_animation(animation_name)

	if not animation_name.begins_with("walk") and not animation_name.begins_with("idle"):
		anim.loop_mode = Animation.LOOP_NONE

	_play_animation(animation_name)

	if duration > 0:
		animation_player.speed_scale = animation_player.current_animation_length / duration

		await get_tree().create_timer(duration).timeout
		animation_player.speed_scale = 1.0

# ==================== ЗДОРОВЬЕ И СМЕРТЬ ====================
func _on_health_changed(_new_value: int, _old_value: int, _max_value: int) -> void:
	pass

func _on_died() -> void:
	is_dead = true
	EventBus.Entity.died.emit(self)
	_play_death_effect()

func _play_death_effect() -> void:
	if sprite:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "modulate", Color(0.3, 0.3, 0.3), 0.3)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
		await tween.finished
		queue_free()
	else:
		queue_free()

# ==================== ПУБЛИЧНЫЕ МЕТОДЫ ====================
func get_facing_direction() -> String:
	return last_facing_direction

func get_horizontal_facing_direction() -> Vector2:
	if _in_combat_mode:
		return Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
	match last_facing_direction:
		"right", "down_right", "up_right":
			return Vector2.RIGHT
		"left", "down_left", "up_left":
			return Vector2.LEFT
		_:
			if abs(velocity.x) > 10:
				return Vector2(sign(velocity.x), 0)
			return Vector2.RIGHT

func get_sprite() -> Sprite2D:
	return sprite

func _register_surrender_state() -> void:
	var fsm_node = combat_component.get_fsm()
	if not fsm_node or fsm_node.has_node("SurrenderedState"):
		return
	var state = SurrenderedState.new()
	state.name = "SurrenderedState"
	state.entity = self
	state.stats_provider = progression_component
	state.combat_component = combat_component
	state.combat_config = combat_component.combat_config if combat_component else null
	state.fsm = fsm_node
	fsm_node.add_child(state)
	fsm_node.states["Surrendered"] = state
	state.transition_requested.connect(fsm_node._on_transition_requested)

func _on_resolve_depleted() -> void:
	var fsm_node = combat_component.get_fsm() if combat_component else null
	if fsm_node:
		fsm_node.change_state("Surrendered")

func _update_component_data(new_data: ActorData) -> void:
	if health_component and health_component.entity_data:
		health_component.entity_data = new_data

	if progression_component and progression_component.entity_data:
		progression_component.entity_data = new_data

	for child in get_children():
		if child is ResourceComponent:
			if child.entity_data:
				child.entity_data = new_data

	if ability_component and ability_component.entity_data:
		ability_component.entity_data = new_data

# ==================== СОХРАНЕНИЕ ====================
func get_save_data() -> Dictionary:
	var data = super.get_save_data()
	data.merge({
		"position": {
			"x": global_position.x,
			"y": global_position.y
		},
		"current_mode": current_mode,
		"dialogue_used": actor_data.dialogue_used if actor_data else false
	})
	return data

func load_save_data(data: Dictionary):
	super.load_save_data(data)
	if data.has("current_mode"):
		change_mode(data["current_mode"])
	if data.has("dialogue_used") and actor_data:
		actor_data.dialogue_used = data["dialogue_used"]
