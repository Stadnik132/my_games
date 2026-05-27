class_name CombatRewardScreen extends CanvasLayer

@onready var continue_button: Button = $ContentPanel/MarginContainer/VBox/ContinueButton
@onready var xp_label: Label = $ContentPanel/MarginContainer/VBox/ExperienceLabel

var _active := false

func _ready() -> void:
	hide()
	continue_button.pressed.connect(_on_continue_pressed)

func show_reward(experience: int, _enemies: Array) -> void:
	print_debug("CombatRewardScreen: показать награду (exp=", experience, ")")

	process_mode = PROCESS_MODE_WHEN_PAUSED

	xp_label.text = "+%d XP" % experience
	_active = true
	continue_button.grab_focus()

	get_tree().paused = true

	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.process_mode = PROCESS_MODE_WHEN_PAUSED
		player.force_stop()
		var combat = player.get_node_or_null("PlayerCombatComponent")
		if combat and combat.fsm:
			combat.fsm.set_process(false)
			combat.fsm.set_physics_process(false)

	show()

func _on_continue_pressed() -> void:
	print_debug("CombatRewardScreen: Continue нажат")
	_active = false

	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.process_mode = PROCESS_MODE_INHERIT
	process_mode = PROCESS_MODE_INHERIT

	hide()
	queue_free()
	EventBus.Game.world_requested.emit()
