# PlayerBattle.gd  
extends BattleUnitVisual  # ← НАСЛЕДУЕМ!

func _ready():
	var player_data = RelationshipManager.player_data
	# setup_visual уже доступен через наследование
	setup_visual(player_data, $Sprite2D)
