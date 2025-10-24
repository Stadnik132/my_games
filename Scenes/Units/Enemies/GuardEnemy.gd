#GuardEnemy.gd - Скрипт стража в бою

extends "res://Scripts/Battle/BattleUnitVisual.gd"  # ← Наследуем от Visual

func _ready():
	# СОЗДАЁМ ДАННЫЕ прямо в сцене
	var enemy_data = BattleUnitData.new()
	enemy_data.setup_unit("Страж", 80, 12, 3)
	setup_visual(enemy_data)  # Передаём данные в визуал
	
	# Настраиваем уникальный спрайт
	$Sprite2D.texture = load("res://Assets/Sprites/bload Knight.png")
