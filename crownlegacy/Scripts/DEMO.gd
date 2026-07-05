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

	await _show_text("Ты - дух, пробудившийся через сотни лет\nв теле своего потомка")
	await _show_text("Твоя цель - вернуть трон и восстановить\nпорядок на своих землях")

	forest_audio.play()
	footsteps_audio.play()
	await get_tree().create_timer(3.0).timeout
	footsteps_audio.stop()

	EventBus.Game.dialogue_requested.emit("Intro_dialogue")
	await _wait_for_dialogue()

	if _fade_tween:
		await _fade_tween.finished

	EventBus.Game.dialogue_requested.emit("pip_intro")
	await _wait_for_dialogue()

	_lock_player(false)
	forest_audio.stop()


func _wait_for_dialogue() -> void:
	var ended := false
	var end_handler := func(): ended = true
	EventBus.Dialogue.ended.connect(end_handler, CONNECT_ONE_SHOT)
	await get_tree().create_timer(30.0).timeout
	if not ended:
		push_warning("DEMO: диалог не завершился за 30с, продолжаем")

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
