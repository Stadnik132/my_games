extends Entity
class_name Actor

# ==================== РЕЖИМЫ ====================
const MODE_WORLD = "world"
const MODE_BATTLE = "battle"

# ==================== ЭКСПОРТ ====================
@export_category("Данные актёра")
@export var actor_id: String = "Actor"
@export var initial_mode: String = MODE_WORLD
@export var actor_data: ActorData
# ==================== ПАРАМЕТРЫ ДВИЖЕНИЯ ====================
var last_movement_direction: Vector2 = Vector2.DOWN
# ==================== ССЫЛКИ ====================
@export_category("Ссылки")
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var interaction_component: ActorInteractionComponent = $ActorInteractionComponent
@onready var combat_component: ActorCombatComponent = $ActorCombatComponent
@onready var ai_controller: AIController = $AIController
@onready var perception_component: AIPerception = $AIPerception  # НОВОЕ
@onready var brain_component: AIBrain = $AIBrain  # НОВОЕ
@onready var decision_trigger_component: DecisionTriggerComponent = $DecisionTriggerComponent

# Совместимость для кода, который ожидает свойство `entity_data` у Entity.
var entity_data: EntityData:
	get:
		return actor_data
	set(value):
		actor_data = value as ActorData

# ==================== ПЕРЕМЕННЫЕ СОСТОЯНИЯ ====================
var current_mode: String = MODE_WORLD
var last_facing_direction: String = "down"
var _is_in_dialogue: bool = false
var dialogue_used: bool = false

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func _ready() -> void:
	super._ready()
	
		# Создаем уникальную копию данных для этого экземпляра
	if actor_data and actor_data is Resource:
		var new_data = actor_data.duplicate(true)
		actor_data = new_data

		_update_component_data(new_data)
	
	current_mode = initial_mode
	add_to_group("actors")
	
	# Настраиваем hurtbox
	if hurtbox:
		hurtbox.set_entity_owner(self)
		hurtbox.update_layer_from_owner()
	
	# Настраиваем взаимодействие
	if interaction_component:
		interaction_component.setup(self)
		interaction_component.player_entered_range.connect(_on_player_entered_range)
		interaction_component.player_exited_range.connect(_on_player_exited_range)
	
	# Настраиваем боевой компонент
	if combat_component:
		combat_component.setup(self, actor_data)
	
	if ability_component and actor_data and not actor_data.ability_slot_assignments.is_empty():
		print_debug("Actor: инициализация AbilityComponent со слотами: ", actor_data.ability_slot_assignments)
		ability_component.initial_slot_assignments = actor_data.ability_slot_assignments
		ability_component.setup(self)
		print_debug("Actor ", actor_id, ": AbilityComponent настроен")
	else:
		print_debug("Actor: AbilityComponent не инициализирован")
		
	if not ability_component:
		print_debug("  ability_component = null")
	if not actor_data:
		print_debug("  actor_data = null")
	if actor_data and actor_data.ability_slot_assignments.is_empty():
		print_debug("  ability_slot_assignments пуст")

	# Инициализация AI
	if ai_controller:
		ai_controller.setup(self)

	if perception_component:
		perception_component.setup(self)

	if brain_component and perception_component and combat_component:
		brain_component.setup(self, perception_component, combat_component)
	
	# Настраиваем DecisionTriggerComponent
	if decision_trigger_component and actor_data and not actor_data.decision_triggers.is_empty():
		decision_trigger_component.setup(self, actor_data.decision_triggers)
		print_debug("Actor ", actor_id, ": DecisionTriggerComponent настроен")
	
	# Подписываемся на события
	EventBus.Dialogue.started.connect(_on_dialogue_started)
	EventBus.Dialogue.ended.connect(_on_dialogue_ended)
	EventBus.Actors.interaction_requested.connect(_on_interaction_requested)
	EventBus.Combat.started.connect(_on_combat_started)
	
	_play_idle_animation()
	print_debug("Actor создан: ", actor_id, " (режим: ", current_mode, ")")

# ==================== ФИЗИКА ====================
func _physics_process(_delta: float) -> void:
	move_and_slide()
	_update_animation()

# ==================== АНИМАЦИИ ====================
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
	var dir = get_cardinal_direction()
	var anim_name = "idle_" + dir
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)

# ==================== РЕЖИМЫ ====================
func change_mode(new_mode: String) -> void:
	if new_mode == current_mode:
		return
	
	var old_mode = current_mode
	current_mode = new_mode
	
	_apply_mode()
	
	EventBus.Actors.mode_changed.emit(self, new_mode, old_mode)

func stop_ai() -> void:
	"""Останавливает AI и движение во время точки решения"""
	if ai_controller:
		ai_controller.set_active(false)
	velocity = Vector2.ZERO
	move_and_slide()
	_play_idle_animation()

func _apply_mode() -> void:
	match current_mode:
		MODE_BATTLE:
			if not is_in_group("enemies"):
				add_to_group("enemies")
			if ai_controller:
				ai_controller.set_active(true)
			
		MODE_WORLD:
			if is_in_group("enemies"):
				remove_from_group("enemies")
			if ai_controller:
				ai_controller.set_active(false)
	
	if hurtbox:
		hurtbox.update_layer_from_owner()

# ==================== ВЗАИМОДЕЙСТВИЕ ====================
func _on_player_entered_range() -> void:
	print_debug(actor_id, ": игрок в зоне взаимодействия")

func _on_player_exited_range() -> void:
	print_debug(actor_id, ": игрок покинул зону взаимодействия")

func _on_interaction_requested() -> void:
	if _can_interact():
		start_interaction()

func _can_interact() -> bool:
	return (interaction_component and 
			interaction_component.is_player_in_range() and 
			not _is_in_dialogue and
			current_mode == MODE_WORLD and
			not interaction_locked)

func start_interaction() -> void:
	if not _can_interact():
		return
	
	_is_in_dialogue = true
	print_debug(actor_id, ": начало взаимодействия")
	
	EventBus.Actors.interaction_started.emit(self)
	
	if not actor_data:
		_is_in_dialogue = false
		return
	
	# Выбираем какой диалог играть
	var timeline_to_play = actor_data.timeline_name
	
	# Если диалог уже использован и есть повторный - играем его
	if dialogue_used and actor_data.repeat_timeline_name != "":
		timeline_to_play = actor_data.repeat_timeline_name
	
	if timeline_to_play != "":
		EventBus.Game.dialogue_requested.emit(timeline_to_play)
		dialogue_used = true
	else:
		print_debug("У актёра ", actor_id, " нет диалога")
		_is_in_dialogue = false

# ==================== ДИАЛОГИ ====================
func _on_dialogue_started(timeline_name: String) -> void:
	if actor_data and timeline_name == actor_data.timeline_name:
		_is_in_dialogue = true

func _on_dialogue_ended() -> void:
	_is_in_dialogue = false
	print_debug(actor_id, ": диалог закончен, можно взаимодействовать снова")

func reset_after_spare() -> void:
	"""Сбрасывает состояние актора после пощады для возможности нового диалога"""
	# Сбрасываем флаг диалога
	_is_in_dialogue = false
	
	# Убеждаемся, что режим WORLD
	if current_mode != MODE_WORLD:
		change_mode(MODE_WORLD)
	
	interaction_locked = false
	
	if ai_controller:
		ai_controller.set_active(false)  # В мире AI не активен	
	print_debug(actor_id, ": сброшен после пощады")

# ==================== БОЙ ====================
func enter_combat(combat_manager: Node = null) -> void:
	"""Вызывается CombatManager при начале боя"""
	change_mode(MODE_BATTLE)
	if combat_component:
		combat_component.enter_combat()

func _on_combat_started(enemies: Array) -> void:
	if self in enemies:
		change_mode(MODE_BATTLE)
		if combat_component:
			combat_component.enter_combat()

# ==================== ЗДОРОВЬЕ И СМЕРТЬ ====================
func _on_health_changed(new_value: int, _old_value: int, max_value: int) -> void:
	print_debug(actor_id, " здоровье: ", new_value, "/", max_value)

func _on_died() -> void:
	is_dead = true
	EventBus.Entity.died.emit(self)
	_play_death_effect()

func _play_death_effect() -> void:
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(0.3, 0.3, 0.3, 0.5), 0.5)
		tween.tween_callback(queue_free)
	else:
		queue_free()

# ==================== ПУБЛИЧНЫЕ МЕТОДЫ ====================
func get_facing_direction() -> String:
	return last_facing_direction

func get_horizontal_facing_direction() -> Vector2:
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

func _update_component_data(new_data: ActorData) -> void:
	"""Обновляет ссылки на данные во всех компонентах"""
	# HealthComponent
	if health_component and health_component.entity_data:
		health_component.entity_data = new_data
	
	# ProgressionComponent
	if progression_component and progression_component.entity_data:
		progression_component.entity_data = new_data
	
	# ResourceComponent (мана/стамина)
	for child in get_children():
		if child is ResourceComponent:
			if child.entity_data:
				child.entity_data = new_data
	
	# Другие компоненты, которые используют entity_data
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
