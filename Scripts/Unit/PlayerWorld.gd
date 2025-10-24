# PlayerWorld.gd - скрипт игрока в мире
extends CharacterBody2D

var speed: int = 200
var battle_data: BattleUnitData
var nearby_npc: Node2D = null
var can_move: bool = true  # Флаг разрешения движения

func _ready():
	battle_data = RelationshipManager.player_data
	print("Игрок в МИРЕ. HP: ", battle_data.current_hp)
	$Camera2D.make_current()
	
func _process(_delta):
	# Движение разрешено только если can_move = true
	if can_move:
		var input_vector = Vector2.ZERO
		if Input.is_action_pressed("ui_right"): input_vector.x += 1
		if Input.is_action_pressed("ui_left"): input_vector.x -= 1
		if Input.is_action_pressed("ui_down"): input_vector.y += 1  
		if Input.is_action_pressed("ui_up"): input_vector.y -= 1
	
		velocity = input_vector.normalized() * speed
		move_and_slide()

# Взаимодействие
	if Input.is_action_just_pressed("ui_accept"):  # Клавиша E или Enter
		print("Нажата клавиша E")  # ← ДОБАВЬ ДЛЯ ПРОВЕРКИ
		check_interaction()

func check_interaction():
	print("Проверка взаимодействия. nearby_npc: ", nearby_npc)
	# Если есть NPC поблизости - взаимодействуем с ним
	# Взаимодействуем только если можем двигаться (чтобы избежать повторных открытий)
	if can_move and nearby_npc and GameStateManager.is_in_world():
		print("Вызываем interact() у NPC")
		nearby_npc.interact()

# Методы для управления состоянием игрока
func set_movement_enabled(enabled: bool):
	can_move = enabled
	print("Движение игрока: ", "разрешено" if enabled else "заблокировано")
