# TestAbilitySystem.gd (отдельная сцена)
extends Node

func _ready():
	await get_tree().process_frame  # Ждём инициализации
	
	print("=== FSM + Abilities Integration Test ===")
	
	# 1. Находим компоненты
	var player = get_parent().get_node("Player")  # Путь к игроку
	var combat_comp = player.get_node("PlayerCombatComponent")
	var fsm = combat_comp.fsm
	var ability_comp = combat_comp.ability_component
	
	print("1. Components found:")
	print("   FSM: ", fsm != null)
	print("   AbilityComponent: ", ability_comp != null)
	print("   Current state: ", fsm.get_current_state_name())
	
	# 2. Тест выбора способности
	print("\n2. Ability selection test:")
	var fireball = get_node("/root/AbilityManager").get_ability("fireball")
	fsm.send_command("ability_selected", {"ability": fireball})
	print("   Selected: ", fsm.current_ability.ability_name)
	
	# 3. Тест перехода в Aiming
	print("\n3. Transition to Aiming:")
	fsm.send_command("aim_start")
	print("   State: ", fsm.get_current_state_name())
	print("   Should be: Aiming")
	
	# 4. Тест каста
	print("\n4. Cast test:")
	var old_mp = PlayerManager.player_data.current_mp
	fsm.send_command("cast", {"target_position": Vector2(500, 300)})
	await get_tree().create_timer(2.0).timeout  # Ждём каст
	print("   State: ", fsm.get_current_state_name())
	print("   Should be: Idle")
	print("   MP used: ", old_mp - PlayerManager.player_data.current_mp)
	
	print("\n=== TEST COMPLETE ===")
