# NPC.gd
extends Area2D

# Настройки NPC для редактора Godot
@export var npc_id: String = "test_npc"  # Уникальный идентификатор
@export var dialogue_file: String = "res://Dialogue/Characters/guard_captain.json"  # JSON диалог
@export var npc_name: String = "Тестовый NPC"  # Отображаемое имя

# Боевые параметры NPC
@export var is_hostile: bool = false  # Является ли NPC врагом
@export var health: int = 100  # Текущее здоровье
@export var max_health: int = 100  # Максимальное здоровье
@export var attack_power: int = 5  # Сила атаки
@export var defense_power: int = 5  # Защита
@export var initiative: int = 10  # Инициатива для очереди ходов

# Ссылки на ноды сцены
@onready var interaction_label = $InteractionLabel           # Подсказка взаимодействия
@onready var sprite = $Sprite2D                             # Спрайт NPC

# Состояния NPC
var player_in_range: bool = false  # Игрок в зоне взаимодействия
var can_interact: bool = true      # Можно ли взаимодействовать с NPC

func _ready() -> void:
	interaction_label.visible = false  # Скрываем подсказку при загрузке
	add_to_group("enemy")  # Добавляем в группу врагов для боевой системы
	
	# Подключаем сигналы для обнаружения игрока
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Подключаемся к завершению диалога
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	
	print("NPC загружен: ", npc_name, " (ID: ", npc_id, ")")

func _process(delta: float) -> void:
	# Обрабатываем ввод если игрок в зоне и можно взаимодействовать
	if player_in_range and can_interact:
		handle_interaction_input()

# Обрабатывает ввод для взаимодействия
func handle_interaction_input() -> void:
	if Input.is_action_just_pressed("ui_accept"):  # Проверяем нажатие клавиши взаимодействия
		interact()  # Запускаем взаимодействие

# Запускает взаимодействие с NPC (начало диалога)
func interact() -> void:
	if GameStateManager.is_dialogue_active() or GameStateManager.is_battle_active():
		print("Нельзя начать диалог - игра в состоянии: ", GameStateManager.get_state_name(GameStateManager.current_state))
		return
	
	if DialogueManager.is_dialogue_active:  # Проверяем не активен ли уже диалог
		print("Диалог уже активен, нельзя начать новый")
		return
		
	add_to_group("npc_dialogue_active")  # Добавляемся в группу активных NPC
	print("NPC добавлен в группу диалога: ", npc_name)
	
	if DialogueManager.load_dialogue(dialogue_file):  # Загружаем диалог из JSON
		DialogueManager.start_dialogue()  # Начинаем диалог
		print("Начато взаимодействие с NPC: ", npc_name)
	else:
		print("Ошибка: не удалось загрузить диалог для NPC ", npc_name)

# Обработчик входа игрока в зону NPC
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and can_interact:  # Проверяем что это игрок
		player_in_range = true
		interaction_label.visible = true  # Показываем подсказку
		print("Игрок вошел в зону NPC: ", npc_name)

# Обработчик выхода игрока из зоны NPC
func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):  # Проверяем что это игрок
		player_in_range = false
		interaction_label.visible = false  # Скрываем подсказку
		print("Игрок вышел из зоны NPC: ", npc_name)

# Обработчик завершения диалога
func _on_dialogue_ended() -> void:
	remove_from_group("npc_dialogue_active")  # Удаляемся из группы активных NPC
	print("NPC удален из группы диалога: ", npc_name)
	
	if player_in_range:  # Если игрок все еще в зоне - показываем подсказку снова
		interaction_label.visible = true
	print("Диалог с NPC завершен: ", npc_name)

# Блокирует взаимодействие с NPC
func disable_interaction() -> void:
	can_interact = false
	interaction_label.visible = false
	print("Взаимодействие с NPC заблокировано: ", npc_name)

# Разблокирует взаимодействие с NPC
func enable_interaction() -> void:
	can_interact = true
	print("Взаимодействие с NPC разблокировано: ", npc_name)

# БОЕВЫЕ ФУНКЦИИ

# Запускает бой с этим NPC
func start_battle(initiator: String = "player") -> void:
	if health <= 0:  # Проверяем может ли NPC сражаться
		print("NPC ", npc_name, " не может сражаться (health = 0)")
		return
	
	print("Начинается бой с NPC: ", npc_name, " Инициатор: ", initiator)
	BattleManager.start_battle(self, initiator)  # Запускаем бой через BattleManager

# Наносит урон NPC и возвращает true если NPC умер
func take_damage(damage_amount: int) -> bool:
	var actual_damage = max(1, damage_amount - defense_power)  # Вычисляем фактический урон
	health -= actual_damage  # Уменьшаем здоровье
	
	print("NPC ", npc_name, " получает ", actual_damage, " урона. Здоровье: ", health)
	
	if health <= 0:  # Проверяем умер ли NPC
		die()
		return true
	else:
		return false

# Обрабатывает смерть NPC
func die() -> void:
	print("NPC умер: ", npc_name)
	# Сообщаем BattleManager о смерти врага
	if BattleManager and BattleManager.has_method("end_battle"):
		BattleManager.end_battle("victory")
	# TODO: Анимация смерти и удаление NPC
	# disable_interaction()
	# queue_free()

# Возвращает true если NPC может сражаться
func can_fight() -> bool:
	return health > 0 and is_hostile

# Возвращает инициативу NPC
func get_initiative() -> int:
	return initiative
