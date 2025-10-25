# BattleUnitVisual.gd
class_name BattleUnitVisual
extends Node2D  # ← НАСЛЕДУЕМ ОТ Node2D!

var unit_data: BattleUnitData
var sprite: Sprite2D

var world_texture: Texture2D
var battle_texture: Texture2D

func setup_visual(data: BattleUnitData, target_sprite: Sprite2D):
	unit_data = data
	sprite = target_sprite

func set_world_appearance():
	if sprite and world_texture:
		sprite.texture = world_texture
		sprite.scale = Vector2(1, 1)

func set_battle_appearance():
	if sprite and battle_texture:
		sprite.texture = battle_texture
		sprite.scale = Vector2(2, 2)

func set_textures(world_tex: Texture2D, battle_tex: Texture2D):
	world_texture = world_tex
	battle_texture = battle_tex

func show_damage_effect():
	if sprite:
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.2).timeout
		sprite.modulate = Color.WHITE
