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
