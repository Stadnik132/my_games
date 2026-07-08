extends CanvasLayer

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var load_menu: Panel = $LoadMenu
@onready var settings_menu: Panel = $SettingMenu
@onready var main_menu_container: VBoxContainer = $CenterContainer/VBox/MenuButtons
@onready var title_label: Label = $CenterContainer/VBox/Title
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var texture_rect: TextureRect = $TextureRect
@onready var background_dim: ColorRect = $BackgroundDim
@onready var new_game_sfx: AudioStreamPlayer = $NewGameSFX

func _ready() -> void:
	await get_tree().process_frame
	
	if animation_player:
		animation_player.play("fade_in")
	
	if load_menu:
		load_menu.hide()
	if settings_menu:
		settings_menu.hide()
	
	$CenterContainer/VBox/MenuButtons/NewGame.pressed.connect(_on_new_game_pressed)
	$CenterContainer/VBox/MenuButtons/Loading.pressed.connect(_on_load_pressed)
	$CenterContainer/VBox/MenuButtons/Setting.pressed.connect(_on_settings_pressed)
	$CenterContainer/VBox/MenuButtons/Exit.pressed.connect(_on_quit_pressed)
	
	_start_music()


func _start_music() -> void:
	if music_player and music_player.stream == null:
		var music_stream = load("res://Assets/Music/main_theme.ogg")
		if music_stream:
			music_player.stream = music_stream
	
	if music_player and not music_player.playing:
		music_player.volume_db = 0
		music_player.play()


func _fade_out_music() -> void:
	if not music_player or not music_player.playing:
		return
	
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -60, 1.0)
	await tween.finished
	music_player.stop()


func _on_new_game_pressed() -> void:
	if new_game_sfx and new_game_sfx.stream:
		new_game_sfx.play()
	
	await _fade_out_music()
	
	SaveManager.reset_game()
	
	if animation_player:
		animation_player.play("fade_out")
		await animation_player.animation_finished
	
	get_tree().change_scene_to_file("res://Scenes/DEMO.tscn")


func _on_load_pressed() -> void:
	main_menu_container.hide()
	if title_label:
		title_label.hide()
	
	if load_menu:
		load_menu.show()
		if load_menu.has_method("refresh_save_list"):
			load_menu.refresh_save_list()


func _on_settings_pressed() -> void:
	main_menu_container.hide()
	if title_label:
		title_label.hide()
	
	if settings_menu:
		settings_menu.show()
		if settings_menu.has_method("load_settings"):
			settings_menu.load_settings()


func _on_quit_pressed() -> void:
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Вы уверены, что хотите выйти?"
	dialog.confirmed.connect(_on_quit_confirmed)
	add_child(dialog)
	dialog.popup_centered()


func _on_quit_confirmed() -> void:
	await _fade_out_music()
	get_tree().quit()


func show_main_menu() -> void:
	main_menu_container.show()
	if title_label:
		title_label.show()
	
	if load_menu:
		load_menu.hide()
	if settings_menu:
		settings_menu.hide()


func _exit_tree() -> void:
	if music_player:
		music_player.stop()
