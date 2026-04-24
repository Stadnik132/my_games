extends Entity
class_name Enemy

enum Mode { WORLD, BATTLE }

@export var enemy_id: String = "enemy"
@export var enemy_data: EntityData
@export var initial_mode: Mode = Mode.WORLD
@export var combat_config: CombatConfig

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var combat_component: ActorCombatComponent = $ActorCombatComponent
@onready var ai_controller: AIController = $AIController
@onready var perception: AIPerception = $AIPerception
@onready var brain: AIBrain = $AIBrain
@onready var patrol_component: EnemyPatrolComponent = $EnemyPatrolComponent
@onready var fsm: EntityCombatFSM = $EntityCombatFSM

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
		ability_component.initial_slot_assignments = enemy_data.ability_slot_assignments
		ability_component.setup(self)
	
	if fsm and combat_component:
		fsm.setup(self, progression_component, combat_component, combat_config)
	
	if ai_controller:
		ai_controller.setup(self)
	
	if perception:
		perception.setup(self)
		perception.player_detected.connect(_on_player_detected)
	
	if brain and perception and combat_component:
		brain.setup(self, perception, combat_component)
	
	if patrol_component:
		patrol_component.setup(self)
		print_debug("Enemy: patrol_component инициализирован")
		print_debug("  Enemy позиция (глобальная): ", global_position)
		print_debug("  Дочерние узлы Enemy: ")
		for child in get_children():
			print_debug("    - ", child.name, " (тип: ", child.get_class(), ")")
	
	EventBus.Combat.started.connect(_on_combat_started)
	EventBus.Combat.ended.connect(_on_combat_ended)
	
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
	
	if _in_combat_mode:
		_update_animation()
		return
	
	if patrol_component:
		patrol_component.update(delta)
	
	move_and_slide()
	_update_animation()


func _update_animation() -> void:
	if not animation_player:
		return
	
	if _in_combat_mode:
		var dir = "right" if get_horizontal_facing_direction() == Vector2.RIGHT else "left"
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


func _update_facing_direction_from_velocity() -> void:
	if abs(velocity.x) > abs(velocity.y):
		last_facing_direction = "right" if velocity.x > 0 else "left"
	else:
		last_facing_direction = "down" if velocity.y > 0 else "up"


func change_mode(new_mode: Mode) -> void:
	if new_mode == current_mode:
		return
	current_mode = new_mode
	_apply_mode()


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
	if sprite:
		return Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
	return Vector2.RIGHT


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
