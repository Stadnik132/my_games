# AimingState.gd
class_name AimingState extends CombatState

var ability: Resource = null
var aiming_visual: Node2D = null

func enter():
	print("AimingState: прицеливание")
	
	ability = fsm.current_ability
	
	if not ability:
		print("AimingState: нет способности для прицеливания")
		transition_requested.emit("Idle")
		return
	
	_create_aiming_visual()
	EventBus.Combat.aiming_started.emit()

func _create_aiming_visual():
	if not ability:
		return
	
	# Загружаем сцену визуала
	var visual_scene = load("res://Test/TestAbility/AimingVisual.tscn")
	aiming_visual = visual_scene.instantiate()
	player.add_child(aiming_visual)
	
	# Настраиваем в зависимости от типа способности
	match ability.ability_type:
		AbilityResource.AbilityType.PROJECTILE:
			# Показываем линию направления
			aiming_visual.show_line()
		AbilityResource.AbilityType.AREA:
			# Показываем круг радиуса
			aiming_visual.show_circle(ability.effect_radius)
		_:
			# INSTANT или SELF_TARGET - без визуала
			aiming_visual.hide()

func process(delta: float):
	if aiming_visual and ability:
		var viewport = player.get_viewport()
		var mouse_pos = viewport.get_mouse_position()
		var camera = viewport.get_camera_2d()
		
		# Для центрированной камеры:
		# 1. Получаем смещение мыши от центра экрана
		var screen_center = viewport.size * 0.5
		var mouse_offset = mouse_pos - screen_center
		
		# 2. Конвертируем в мировые координаты с учётом зума камеры
		var camera_zoom = camera.zoom if camera else Vector2.ONE
		var world_offset = mouse_offset / camera_zoom
		
		# 3. Прибавляем к позиции камеры (которая равна позиции игрока)
		var global_mouse_pos = camera.global_position + world_offset
		
		# Альтернатива: если камера не центрирована на игроке
		# var global_mouse_pos = camera.project_position(mouse_pos, 0.0)
		
		match ability.ability_type:
			AbilityResource.AbilityType.PROJECTILE:
				aiming_visual.update_line(player.global_position, global_mouse_pos)
			AbilityResource.AbilityType.AREA:
				aiming_visual.update_circle(global_mouse_pos)

func handle_command(command: String, data: Dictionary = {}):
	match command:
		"cast":
			var target_position = data.get("target_position", player.global_position)
			_remove_aiming_visual()
			transition_requested.emit("Cast")
		
		"dodge", "aim_cancel", "block_start":
			# ПРОСТО ОТМЕНА ПРИЦЕЛИВАНИЯ
			_remove_aiming_visual()
			transition_requested.emit("Idle")
		
		"ability_selected":
			ability = data.get("ability")
			_remove_aiming_visual()
			_create_aiming_visual()

func _remove_aiming_visual():
	if aiming_visual:
		aiming_visual.queue_free()
		aiming_visual = null

func exit():
	_remove_aiming_visual()

func get_allowed_transitions() -> Array[StringName]:
	return ["Idle", "Dodge", "Cast"]

func cancel_aiming():
	EventBus.Combat.aiming_cancelled.emit()
	transition_requested.emit("Idle")
