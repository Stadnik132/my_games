extends Panel

@onready var item_list: ItemList = $VBoxContainer/SaveList
@onready var load_button: Button = $VBoxContainer/HBoxContainer/Loading
@onready var delete_button: Button = $VBoxContainer/HBoxContainer/Remove
@onready var back_button: Button = $VBoxContainer/HBoxContainer/Back


func _ready() -> void:
	hide()
	
	load_button.pressed.connect(_on_load_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	item_list.item_selected.connect(_on_item_selected)


func refresh_save_list() -> void:
	item_list.clear()
	var saves: Array = SaveManager.get_save_list()
	for save in saves:
		var slot_name: String = str(save.get("name", ""))
		var slot_time: String = str(save.get("time", ""))
		var display_text: String = slot_name if slot_time == "" else "%s - %s" % [slot_name, slot_time]
		item_list.add_item(display_text)
	
	load_button.disabled = item_list.item_count == 0
	delete_button.disabled = item_list.item_count == 0


func _on_item_selected(_index: int) -> void:
	load_button.disabled = false
	delete_button.disabled = false


func _on_load_pressed() -> void:
	var selected := item_list.get_selected_items()
	if selected.size() == 0:
		return
	
	var save_name := item_list.get_item_text(selected[0]).split(" - ")[0]
	if save_name.is_empty():
		return
	
	SaveManager.load_game(save_name)
	# Переход к основной игровой сцене
	get_tree().change_scene_to_file("res://Scenes/TEST/Main.tscn")


func _on_delete_pressed() -> void:
	var selected := item_list.get_selected_items()
	if selected.size() == 0:
		return
	
	var save_name := item_list.get_item_text(selected[0]).split(" - ")[0]
	if save_name.is_empty():
		return
	
	SaveManager.delete_save(save_name)
	refresh_save_list()


func _on_back_pressed() -> void:
	hide()
	# Находим MainMenu и показываем его кнопки
	var main_menu = get_parent()
	if main_menu.has_method("show_main_menu"):
		main_menu.show_main_menu()
