# GuardEnemy.gd
extends CharacterBody2D  # ← ВОЗВРАЩАЕМ CharacterBody2D!

# ЗАГРУЖАЕМ КЛАССЫ
var BattleUnitData = load("res://Scripts/Battle/BattleUnitData.gd")
var BattleUnitVisual = load("res://Scripts/Battle/BattleUnitVisual.gd")

var unit_data: BattleUnitData
var unit_visual: BattleUnitVisual

var npc_name: String = "Страж"
var hp: int = 80
var attack: int = 12
var defense: int = 3

@onready var sprite: Sprite2D = $Sprite2D

var player_in_range: bool = false
var in_battle: bool = false
var world_position: Vector2

func _ready():
	unit_data = BattleUnitData.new()
	unit_data.setup_unit(npc_name, hp, attack, defense)
	
	unit_visual = BattleUnitVisual.new()
	unit_visual.setup_visual(unit_data, sprite)
	unit_visual.set_textures(
		load("res://Sprites/NPCs/guard_world.png"),
		load("res://Sprites/NPCs/guard_battle.png")
	)
	
	world_position = global_position
	unit_visual.set_world_appearance()

func _on_area_2d_body_entered(body):
	if body.name == "PlayerWorld":
		player_in_range = true
		body.nearby_npc = self
		print("Игрок рядом со стражем!")

func _on_area_2d_body_exited(body):
	if body.name == "PlayerWorld":
		player_in_range = false
		if body.nearby_npc == self:
			body.nearby_npc = null

func interact():
	if in_battle: return
	if player_in_range and GameStateManager.is_in_world():
		start_dialogue()

func start_dialogue():
	var dialog_ui = load("res://Scenes/UI/DialogUI.tscn").instantiate()
	get_tree().current_scene.add_child(dialog_ui)
	dialog_ui.start_dialogue("res://Scripts/dialog/guard_dialogue.json")

func start_battle():
	in_battle = true
	unit_visual.set_battle_appearance()
	world_position = global_position
	global_position = Vector2(600, 300)
	
	# ЗАПУСКАЕМ БОЙ ЧЕРЕЗ GameStateManager
	GameStateManager.start_battle_with_enemy(self)

func take_damage(damage: int):
	unit_data.take_damage(damage)
	unit_visual.show_damage_effect()
	if not unit_data.is_alive():
		defeat()

func defeat():
	print(npc_name + " побежден!")
	queue_free()

func return_to_world():
	in_battle = false
	global_position = world_position
	unit_visual.set_world_appearance()

func is_alive() -> bool:
	return unit_data.is_alive()
