#test_room.gd - скрипт Тестового меню, для перехода или проверки каких либо функций.

extends Node2D
#В этом скрипте находятся тестовые кнопки, которые связаны с функциями из других скриптов

func _on_button_pressed():
	RelationshipManager.change_sync(10)

func _on_button_2_pressed():
	RelationshipManager.use_king_will()

# При нажатии кнопки, открывается "BattleScene
func _on_battle_button_pressed():
	var batle_scene = load("res://Scenes/Battle/BattleScene.tscn")
	get_tree().change_scene_to_packed(batle_scene)


func _on_button_4_VillageScene() -> void:
	var Village_Scene = load("res://Scenes/VillageScene.tscn")
	get_tree().change_scene_to_packed(Village_Scene)
