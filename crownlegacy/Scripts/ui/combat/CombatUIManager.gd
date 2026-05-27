extends Node


var hud: PlayerCombatHUD
var menu: CombatActionMenu
var reward_screen: CombatRewardScreen
var enemy_bar_layer: CanvasLayer
var enemy_bars: Array[EnemyStatusBar] = []

func _ready() -> void:
	print_debug("CombatUIManager: _ready()")
	process_mode = PROCESS_MODE_WHEN_PAUSED
	enemy_bar_layer = CanvasLayer.new()
	enemy_bar_layer.layer = 1
	add_child(enemy_bar_layer)
	_create_hud()
	_create_menu()
	EventBus.Combat.started.connect(_on_combat_started)
	EventBus.Combat.ended.connect(_on_combat_ended)
	EventBus.Combat.reward_calculation_requested.connect(_on_reward_requested)
	EventBus.Combat.enemy.joined.connect(_on_enemy_joined)
	EventBus.Entity.died.connect(_on_entity_died)

func _create_hud() -> void:
	var scene = load("res://Scenes/UI/combat/PlayerCombatHUD.tscn")
	if not scene:
		push_error("CombatUIManager: HUD scene not found!")
		return
	hud = scene.instantiate()
	add_child(hud)
	print_debug("CombatUIManager: HUD created, hidden=", hud.is_visible())

func _create_menu() -> void:
	var scene = load("res://Scenes/UI/combat/CombatActionMenu.tscn")
	if not scene:
		push_error("CombatUIManager: Menu scene not found!")
		return
	menu = scene.instantiate()
	add_child(menu)
	menu.action_selected.connect(_on_action_selected)
	print_debug("CombatUIManager: Menu created")

func _on_combat_started(enemies: Array) -> void:
	for enemy in enemies:
		_add_enemy_bar(enemy)

func _on_enemy_joined(enemy: Node) -> void:
	_add_enemy_bar(enemy)

func _on_reward_requested(experience: int, enemies: Array) -> void:
	print_debug("CombatUIManager: reward requested (exp=", experience, ")")
	var scene = load("res://Scenes/UI/combat/CombatRewardScreen.tscn")
	if not scene:
		push_error("CombatUIManager: Reward screen scene not found!")
		EventBus.Game.world_requested.emit()
		return
	var instance = scene.instantiate()
	if not instance:
		push_error("CombatUIManager: Failed to instantiate reward screen!")
		EventBus.Game.world_requested.emit()
		return
	reward_screen = instance as CombatRewardScreen
	if not reward_screen:
		push_error("CombatUIManager: instantiated node is not CombatRewardScreen!")
		instance.queue_free()
		EventBus.Game.world_requested.emit()
		return
	get_tree().current_scene.add_child(reward_screen)
	reward_screen.show_reward(experience, enemies)

func _on_combat_ended(_victory: bool) -> void:
	for bar in enemy_bars:
		if is_instance_valid(bar):
			bar.queue_free()
	enemy_bars.clear()

func _add_enemy_bar(enemy: Node) -> void:
	var bar_scene = load("res://Scenes/UI/combat/EnemyStatusBar.tscn")
	if not bar_scene:
		return
	var bar = bar_scene.instantiate() as EnemyStatusBar
	enemy_bar_layer.add_child(bar)
	bar.setup(enemy)
	bar.show()
	enemy_bars.append(bar)

func _on_action_selected(action_type: String, data: Dictionary) -> void:
	match action_type:
		"ability":
			EventBus.Combat.ability.slot_pressed.emit(data.slot_index)
		"persuasion":
			EventBus.Combat.persuasion.action_requested.emit(data.action)
		"item":
			EventBus.Combat.inventory.use_item_requested.emit(data.slot_index)

func _on_entity_died(entity: Node) -> void:
	for bar in enemy_bars:
		if is_instance_valid(bar) and bar.target == entity:
			bar.queue_free()
			enemy_bars.erase(bar)
			break
