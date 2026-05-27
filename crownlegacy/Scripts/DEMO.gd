extends Node2D

@onready var fade_rect: ColorRect = $OverlayUI/FadeRect
@onready var prologue_label: Label = $OverlayUI/PrologueLabel
@onready var forest_audio: AudioStreamPlayer = $ForestAudio
@onready var footsteps_audio: AudioStreamPlayer = $FootstepsAudio
@onready var campfire: AnimatedSprite2D = $AnimatedSprite2D
@onready var campfire_visibility: VisibleOnScreenNotifier2D = $CampfireVisibility

var _fade_tween: Tween = null

func _ready() -> void:
	print("DEMO: _ready начался")

	_lock_player(true)
	prologue_label.hide()

	campfire.stop()
	campfire_visibility.screen_entered.connect(_on_campfire_screen_entered)
	campfire_visibility.screen_exited.connect(_on_campfire_screen_exited)

	if Dialogic.has_signal("signal_event"):
		Dialogic.signal_event.connect(_on_dialogic_signal)

	await _show_text("Ты - дух, пробудившийся через сотни лет\nв теле своего потомка")
	await _show_text("Твоя цель - вернуть трон и восстановить\nпорядок на своих землях")

	forest_audio.play()
	footsteps_audio.play()
	await get_tree().create_timer(3.0).timeout
	footsteps_audio.stop()

	Dialogic.start("Intro_dialogue")
	await Dialogic.timeline_ended

	if _fade_tween:
		await _fade_tween.finished

	Dialogic.start("pip_intro")
	await Dialogic.timeline_ended

	_lock_player(false)
	forest_audio.stop()


func _on_dialogic_signal(argument: String) -> void:
	if argument == "fade_in":
		_fade_tween = create_tween()
		_fade_tween.tween_property(fade_rect, "color", Color(0, 0, 0, 0), 1.5)


func _show_text(text: String) -> void:
	prologue_label.text = text
	prologue_label.modulate = Color(1, 1, 1, 0)
	prologue_label.show()

	var tween = create_tween()
	tween.tween_property(prologue_label, "modulate", Color(1, 1, 1, 1), 1.0)
	await tween.finished
	await get_tree().create_timer(2.5).timeout

	tween = create_tween()
	tween.tween_property(prologue_label, "modulate", Color(1, 1, 1, 0), 1.0)
	await tween.finished

	prologue_label.hide()


func _lock_player(locked: bool) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.movement_locked = locked
		player.interaction_locked = locked


func _on_campfire_screen_entered() -> void:
	campfire.play()


func _on_campfire_screen_exited() -> void:
	campfire.stop()
