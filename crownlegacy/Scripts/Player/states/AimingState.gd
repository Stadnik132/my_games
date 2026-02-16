class_name AimingState extends CombatState

# Aim: выбран скилл. ЛКМ = Cast, Space = Dodge, ПКМ = отмена (Idle, блок не нажимается).

var ability: AbilityResource = null
var aiming_visual: Node2D = null

func enter() -> void:
	ability = fsm.current_ability
	if not ability:
		transition_requested.emit("Idle")
		return
	_create_aiming_visual()
	EventBus.Combat.aiming_started.emit()

func _create_aiming_visual() -> void:
	if not ability:
		return
	var scene = load("res://Test/TestAbility/AimingVisual.tscn") as PackedScene
	if not scene:
		return
	aiming_visual = scene.instantiate()
	player.add_child(aiming_visual)
	match ability.ability_type:
		AbilityResource.AbilityType.PROJECTILE:
			if aiming_visual.has_method("show_line"):
				aiming_visual.show_line()
		AbilityResource.AbilityType.AREA:
			if aiming_visual.has_method("show_circle"):
				aiming_visual.show_circle(ability.effect_radius)
		_:
			if aiming_visual.has_method("hide"):
				aiming_visual.hide()

func _remove_aiming_visual() -> void:
	if aiming_visual:
		aiming_visual.queue_free()
		aiming_visual = null

func process(_delta: float) -> void:
	if not aiming_visual or not ability:
		return
	var vp = player.get_viewport()
	var mouse_pos = vp.get_mouse_position()
	var cam = vp.get_camera_2d()
	var screen_center = vp.size * 0.5
	var zoom = cam.zoom if cam else Vector2.ONE
	var world_mouse = cam.global_position + (mouse_pos - screen_center) / zoom if cam else player.global_position
	match ability.ability_type:
		AbilityResource.AbilityType.PROJECTILE:
			if aiming_visual.has_method("update_line"):
				aiming_visual.update_line(player.global_position, world_mouse)
		AbilityResource.AbilityType.AREA:
			if aiming_visual.has_method("update_circle"):
				aiming_visual.update_circle(world_mouse)

func physics_process(_delta: float) -> void:
	set_battle_velocity(Vector2.ZERO)
	apply_movement()

func handle_command(command: String, data: Dictionary = {}) -> void:
	super.handle_command(command, data)
	match command:
		"cast":
			fsm.cast_target_position = data.get("target", player.global_position)
			_remove_aiming_visual()
			transition_requested.emit("Cast")
		"dodge":
			_remove_aiming_visual()
			EventBus.Combat.aiming_cancelled.emit()
			transition_requested.emit("Dodge")
		"aim_cancel", "block_start":
			_remove_aiming_visual()
			EventBus.Combat.aiming_cancelled.emit()
			transition_requested.emit("Idle")
		"ability_selected":
			ability = data.get("ability")
			_remove_aiming_visual()
			_create_aiming_visual()

func exit() -> void:
	_remove_aiming_visual()

func get_allowed_transitions() -> Array[String]:
	return ["Idle", "Dodge", "Cast", "Stun"]
