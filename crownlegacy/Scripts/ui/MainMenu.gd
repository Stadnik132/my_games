extends CanvasLayer

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var load_menu: Panel = $LoadMenu
@onready var settings_menu: Panel = $SettingMenu
@onready var main_menu_container: VBoxContainer = $VBoxContainer
@onready var title_label: Label = $Label
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var texture_rect: TextureRect = $TextureRect
@onready var background_dim: ColorRect = $BackgroundDim  # Опционально
@onready var new_game_sfx: AudioStreamPlayer = $NewGameSFX

func _ready() -> void:
	await get_tree().process_frame
	_resize_logo()
	
	if animation_player:
		animation_player.play("fade_in")
	
	# Скрываем подменю при старте
	if load_menu:
		load_menu.hide()
	if settings_menu:
		settings_menu.hide()
	
	# Подключаем сигналы кнопок
	$VBoxContainer/NewGame.pressed.connect(_on_new_game_pressed)
	$VBoxContainer/Loading.pressed.connect(_on_load_pressed)
	$VBoxContainer/Setting.pressed.connect(_on_settings_pressed)
	$VBoxContainer/Exit.pressed.connect(_on_quit_pressed)
	
	# Запускаем музыку
	_start_music()
	
	# Подписываемся на изменение размера окна
	get_tree().root.size_changed.connect(_resize_logo)


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
	
	# Обновляем фон при возврате в главное меню
	_resize_logo()


func _exit_tree() -> void:
	if music_player:
		music_player.stop()
	
	if get_tree().root.size_changed.is_connected(_resize_logo):
		get_tree().root.size_changed.disconnect(_resize_logo)


func _resize_logo() -> void:
	if not texture_rect or not texture_rect.texture:
		return
	
	# Полноэкранное растягивание через anchors
	texture_rect.anchor_left = 0.0
	texture_rect.anchor_top = 0.0
	texture_rect.anchor_right = 1.0
	texture_rect.anchor_bottom = 1.0
	
	# Сбрасываем offsets
	texture_rect.offset_left = 0
	texture_rect.offset_top = 0
	texture_rect.offset_right = 0
	texture_rect.offset_bottom = 0
	
	# Настройка масштабирования с сохранением пропорций
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	
	# Растягиваем на весь контейнер
	texture_rect.size_flags_horizontal = Control.SIZE_FILL
	texture_rect.size_flags_vertical = Control.SIZE_FILL
	
	# Синхронизируем затемнение с фоном (опционально)
	if background_dim:
		background_dim.anchor_left = 0.0
		background_dim.anchor_top = 0.0
		background_dim.anchor_right = 1.0
		background_dim.anchor_bottom = 1.0
		background_dim.offset_left = 0
		background_dim.offset_top = 0
		background_dim.offset_right = 0
		background_dim.offset_bottom = 0
