extends Entity
class_name Enemy

enum Mode { WORLD, BATTLE }

@export var entity_id: String = "enemy"
@export var enemy_data: EntityData
@export var initial_mode: Mode = Mode.WORLD
@export var combat_config: CombatConfig
@export var detect_range: float = 150.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var combat_component: ActorCombatComponent = $ActorCombatComponent
@onready var ai_controller: AIController = $AIController
@onready var brain: AIBrain = $AIBrain
@onready var patrol_component: EnemyPatrolComponent = $EnemyPatrolComponent
@onready var fsm: EntityCombatFSM = $EntityCombatFSM
@onready var resolve_component: ResolveComponent = get_node_or_null("ResolveComponent") as ResolveComponent

var current_mode: Mode = Mode.WORLD
var _in_combat_mode: bool = false
var last_facing_direction: String = "down"


func _ready() -> void:
	super._ready()
	
	if enemy_data and enemy_data is Resource:
		enemy_data = enemy_data.duplicate(true)
		_update_component_data(enemy_data)
	
	current_mode = initial_mode
	add_to_group("enemies")
	
	if hurtbox:
		hurtbox.set_entity_owner(self)
		hurtbox.update_layer_from_owner()
	
	if combat_component:
		combat_component.setup(self, enemy_data)
		if combat_config:
			combat_component.combat_config = combat_config
	
	if ability_component and enemy_data:
		if not enemy_data.ability_slot_assignments.is_empty():
			ability_component.initial_slot_assignments = enemy_data.ability_slot_assignments
		ability_component.setup(self)
	
	if fsm and combat_component:
		fsm.setup(self, progression_component, combat_component, combat_config)
		_register_surrender_state()
	
	_ensure_resolve_component()
	
	if ai_controller:
		ai_controller.setup(self)
	
	if patrol_component:
		patrol_component.setup(self)
		print_debug("Enemy: patrol_component инициализирован")
		print_debug("  Enemy позиция (глобальная): ", global_position)
		print_debug("  Дочерние узлы Enemy: ")
		for child in get_children():
			print_debug("    - ", child.name, " (тип: ", child.get_class(), ")")
	
	EventBus.Combat.started.connect(_on_combat_started)
	EventBus.Combat.ended.connect(_on_combat_ended)
	EventBus.Animations.requested.connect(_on_animation_requested)

	
	_apply_mode()


func _update_component_data(new_data: EntityData) -> void:
	if health_component:
		health_component.entity_data = new_data
	if progression_component:
		progression_component.entity_data = new_data
	if mana_component:
		mana_component.entity_data = new_data
	if stamina_component:
		stamina_component.entity_data = new_data
	if ability_component:
		ability_component.entity_data = new_data


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	if current_mode == Mode.WORLD:
		var player = get_tree().get_first_node_in_group("player")
		if player and global_position.distance_to(player.global_position) <= detect_range:
			EventBus.Combat.start_combat_requested.emit([self])
	
	if _in_combat_mode:
		# В бою обновляем направление взгляда по velocity
		if velocity.length() > 10:
			sprite.flip_h = velocity.x < 0
			last_facing_direction = "right" if velocity.x >= 0 else "left"
		# else: сохраняем последнее направление
#		_update_animation()
		return
	
	if patrol_component:
		patrol_component.update(delta)
	
	move_and_slide()
#	_update_animation()


func _update_animation() -> void:
	if not animation_player:
		return
	
	if _in_combat_mode:
		var moving = velocity.length() > 10
		var dir = "right" if not sprite.flip_h else "left"
		
		if moving:
			# Если есть walk_battle анимация, используем её
			var anim_name = "walk_battle_" + dir
			if animation_player.has_animation(anim_name):
				animation_player.play(anim_name)
			else:
				# fallback на idle_battle
				animation_player.play("idle_battle_" + dir)
		else:
			var anim_name = "idle_battle_" + dir
			if animation_player.has_animation(anim_name):
				animation_player.play(anim_name)
	else:
		if velocity.length() > 10:
			_update_facing_direction_from_velocity()
			var anim_name = "walk_" + last_facing_direction
			if animation_player.has_animation(anim_name):
				animation_player.play(anim_name)
		else:
			var anim_name = "idle_" + last_facing_direction
			if animation_player.has_animation(anim_name):
				animation_player.play(anim_name)
				

func _on_animation_requested(target: Node, animation_name: String, duration: float) -> void:
	if target != self:
		return
	# Враг сам управляет анимациями, игнорируем
	pass

func _update_facing_direction_from_velocity() -> void:
	if abs(velocity.x) > abs(velocity.y):
		last_facing_direction = "right" if velocity.x > 0 else "left"
	else:
		last_facing_direction = "down" if velocity.y > 0 else "up"



func _ensure_resolve_component() -> void:
	if resolve_component:
		resolve_component.surrendered.connect(_on_resolve_depleted)

func _register_surrender_state() -> void:
	if not fsm or fsm.has_node("SurrenderedState"):
		return
	var state = SurrenderedState.new()
	state.name = "SurrenderedState"
	state.entity = self
	state.stats_provider = progression_component
	state.combat_component = combat_component
	state.combat_config = combat_config
	state.fsm = fsm
	fsm.add_child(state)
	fsm.states["Surrendered"] = state
	state.transition_requested.connect(fsm._on_transition_requested)

func _on_resolve_depleted() -> void:
	if fsm and combat_component:
		fsm.change_state("Surrendered")

func change_mode(new_mode: Mode) -> void:
	if new_mode == current_mode:
		return
	current_mode = new_mode
	_apply_mode()

func enter_combat(combat_manager: Node = null) -> void:
	change_mode(Mode.BATTLE)
	if combat_component:
		combat_component.enter_combat()

func _apply_mode() -> void:
	match current_mode:
		Mode.BATTLE:
			_in_combat_mode = true
			if ai_controller:
				ai_controller.set_active(true)
			if combat_component:
				combat_component.enter_combat()
		Mode.WORLD:
			_in_combat_mode = false
			velocity = Vector2.ZERO  # Сбрасываем скорость при выходе из боя
			if ai_controller:
				ai_controller.set_active(false)
			if combat_component:
				combat_component.exit_combat()
	
	if hurtbox:
		hurtbox.update_layer_from_owner()


func _on_player_detected(_player: Player) -> void:
	if current_mode == Mode.WORLD:
		EventBus.Combat.start_combat_requested.emit([self])


func _on_combat_started(enemies: Array) -> void:
	if self in enemies:
		change_mode(Mode.BATTLE)


func _on_combat_ended(victory: bool) -> void:
	if is_alive():
		change_mode(Mode.WORLD)


func get_sprite() -> Sprite2D:
	return sprite


func get_horizontal_facing_direction() -> Vector2:
	# В бою определяем по flip_h, в мире — по last_facing_direction
	if _in_combat_mode:
		return Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
	else:
		return Vector2.RIGHT if last_facing_direction in ["right", "up_right", "down_right"] else Vector2.LEFT


func _on_died() -> void:
	is_dead = true
	EventBus.Entity.died.emit(self)
	
	if sprite:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "modulate", Color(0.3, 0.3, 0.3), 0.3)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
		await tween.finished
	
	queue_free()
