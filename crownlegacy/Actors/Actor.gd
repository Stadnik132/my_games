# Actor.gd
extends CharacterBody2D
class_name Actor

# ==================== НАСТРОЙКИ ====================
@export_category("Основные настройки")
@export var display_name: String = "NPC"
@export var actor_id: String = "unnamed_actor"
@export var dialogue_timeline: String = ""

@export_category("Состояние")
@export var max_health: int = 100
@export var initial_mode: String = "peaceful"  # peaceful/hostile
@export var is_interactive: bool = true

const MODE_PEACEFUL = "peaceful"
const MODE_HOSTILE = "hostile" 

@export_category("Компоненты (опционально)")
@export var interaction_component_path: NodePath
@export var combat_component_path: NodePath
@export var ai_component_path: NodePath

# ==================== СИГНАЛЫ ====================
signal health_changed(current: int, max: int)
signal mode_changed(new_mode: String, old_mode: String)
signal interaction_started(actor: Actor)
signal actor_died(actor: Actor)

# ==================== ПЕРЕМЕННЫЕ ====================
var current_health: int
var current_mode: String
var _player_in_range: bool = false
var _is_in_dialogue: bool = false
var _is_world_mode: bool = true

# Компоненты
@onready var interaction_component = get_node_or_null(interaction_component_path)
@onready var combat_component = get_node_or_null(combat_component_path)
@onready var ai_component = get_node_or_null(ai_component_path)

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func _ready() -> void:
	current_health = max_health
	current_mode = initial_mode
	
	# Настраиваем компоненты
	_setup_components()
	# Подписываемся на события
	_setup_connections()
	
	add_to_group("actors")
	print_debug("Actor создан: ", display_name, " (режим: ", current_mode, ")")

func start_interaction() -> void:
	"""Начать взаимодействие с актёром"""
	if not _can_interact():
		return
	
	_is_in_dialogue = true
	
	print_debug(display_name, ": начало взаимодействия")
	
	# Сигналы о начале взаимодействия
	interaction_started.emit(self)
	EventBus.Actors.interaction_started.emit(self)
	
	# Если есть диалог - запускаем
	if dialogue_timeline != "":
		EventBus.Game.transition_to_dialogue_requested.emit(dialogue_timeline)
	else:
		print_debug("У актёра ", display_name, " нет диалога")
		# Завершаем взаимодействие, если нет диалога
		_is_in_dialogue = false
	
	# Визуальная обратная связь
	_play_interaction_feedback()

func _setup_components() -> void:
	"""Настройка компонентов"""
	if interaction_component:
		interaction_component.setup(self)
	
	if combat_component:
		combat_component.setup(self)
		# Подписываемся на сигналы CombatComponent
		if combat_component.has_signal("health_changed"):
			combat_component.health_changed.connect(_on_combat_health_changed)
		if combat_component.has_signal("died"):
			combat_component.died.connect(_on_combat_death)
	
	if ai_component:
		ai_component.setup(self)

func _setup_connections() -> void:
	"""Подключение к сигналам"""
	EventBus.Actors.interaction_requested.connect(_on_interaction_requested)
	EventBus.Dialogue.started.connect(_on_dialogue_started)
	EventBus.Game.transition_to_world_requested.connect(_on_dialogue_ended)
	EventBus.Game.state_changed.connect(_on_game_state_changed) 

# ==================== ВЗАИМОДЕЙСТВИЕ ====================
func _play_interaction_feedback() -> void:
	"""Анимация при взаимодействии"""
	# Можно добавить твин иконки как в NPC
	var interaction_component = get_node_or_null(interaction_component_path)
	if interaction_component and interaction_component.has_method("play_feedback"):
		interaction_component.play_feedback()

func _on_interaction_requested() -> void:
	"""Когда игрок запрашивает взаимодействие"""
	if _can_interact():
		_start_interaction()

func _can_interact() -> bool:
	"""Можно ли взаимодействовать с актёром"""
	return (is_interactive and 
			_player_in_range and 
			not _is_in_dialogue and
			is_alive() and
			current_mode == "peaceful" and
			_is_world_mode)

func _start_interaction() -> void:
	"""Начало взаимодействия"""
	_is_in_dialogue = true
	
	print_debug(display_name, ": начало взаимодействия")
	
	# Сигналы о начале взаимодействия
	interaction_started.emit(self)
	EventBus.Actors.interaction_started.emit(self)
	
	# Если есть диалог - запускаем
	if dialogue_timeline != "":
		EventBus.Game.transition_to_dialogue_requested.emit(dialogue_timeline)
	else:
		print_debug("У актёра ", display_name, " нет диалога")
		# Завершаем взаимодействие, если нет диалога
		_is_in_dialogue = false

func apply_combat_damage(amount: int, source: Node = null) -> void:
	"""Совместимость со старым кодом (TestAttack)"""
	if combat_component and combat_component.has_method("take_damage_legacy"):
		combat_component.take_damage_legacy(amount, source)
	else:
		push_warning("CombatComponent не поддерживает старый формат урона")
		
func apply_combat_damage_data(damage_data: DamageData, source: Node = null) -> void:
	"""Новый метод для DamageData"""
	if combat_component and combat_component.has_method("take_damage"):
		combat_component.take_damage(damage_data, source)
	else:
		push_warning("CombatComponent не найден или не поддерживает DamageData")

func _on_death() -> void:
	"""Смерть актёра (вызывается CombatComponent)"""
	print_debug(display_name, ": смерть")
	
	is_interactive = false
	_player_in_range = false
	
	# Отключаем все компоненты
	if interaction_component:
		interaction_component.set_active(false)
	
	if combat_component:
		combat_component.set_active(false)
	
	if ai_component:
		ai_component.set_active(false)
	
	# Визуальные эффекты
	hide()
	set_process(false)
	set_physics_process(false)
	
	# Сигналы
	actor_died.emit(self)
	EventBus.Actors.died.emit(self)

# ==================== РЕЖИМЫ ====================
func change_mode(new_mode: String) -> void:
	"""Смена режима поведения"""
	if new_mode == current_mode:
		return
	
	var old_mode = current_mode
	current_mode = new_mode
	
	print_debug(display_name, ": смена режима ", old_mode, " → ", new_mode)
	
	match new_mode:
		"hostile":
			_on_become_hostile()
			_apply_hostile_appearance()
			# ДОБАВИТЬ ЭТО:
			if not is_in_group("enemies"):
				add_to_group("enemies")
				print_debug("Actor добавлен в группу 'enemies'")
		
		"peaceful":
			_on_become_peaceful()
			# ДОБАВИТЬ ЭТО:
			if is_in_group("enemies"):
				remove_from_group("enemies")
				print_debug("Actor удалён из группы 'enemies'")
	# ===================================
	
	# Сигналы (оставить без изменений)
	mode_changed.emit(new_mode, old_mode)
	EventBus.Actors.mode_changed.emit(self, new_mode, old_mode)

func become_enemy(combat_manager: Node = null) -> void:
	"""NPC становится врагом (вызывается из диалога)"""
	print_debug(display_name, ": становлюсь врагом!")
	
	# ВСЁ что нужно - меняем режим (change_mode сам добавит в группу)
	change_mode("hostile")
	
	# Активируем CombatComponent если есть
	if combat_component:
		if combat_manager:
			combat_component.setup_combat(combat_manager)
		else:
			# Ищем CombatManager в сцене
			var cm = get_tree().get_first_node_in_group("combat_manager")
			if cm:
				combat_component.setup_combat(cm)
	
	
	EventBus.Actors.mode_changed.emit(self, MODE_HOSTILE, MODE_PEACEFUL)

func _on_become_hostile() -> void:
	"""При становлении враждебным"""
	is_interactive = false
	
	# Активируем боевые компоненты
	if combat_component:
		combat_component.set_active(true)
	
	if ai_component:
		ai_component.set_active(true)

func _on_become_peaceful() -> void:
	"""При становлении мирным"""
	is_interactive = true
	
	# Деактивируем боевые компоненты
	if combat_component:
		combat_component.set_active(false)
	
	if ai_component:
		ai_component.set_active(false)

func _on_become_neutral() -> void:
	"""При становлении нейтральным"""
	is_interactive = false
	
	if combat_component:
		combat_component.set_active(false)
	
	if ai_component:
		ai_component.set_active(true)  # AI может быть активен для патрулирования

# ==================== ДИАЛОГИ ====================
func _on_dialogue_started(timeline_name: String) -> void:
	"""Когда начинается диалог"""
	if timeline_name == dialogue_timeline:
		_is_in_dialogue = true


func _on_dialogue_ended() -> void:
	"""Когда диалог заканчивается"""
	_is_in_dialogue = false

# ==================== УТИЛИТЫ ====================
func set_player_in_range(value: bool) -> void:
	"""Установить флаг нахождения игрока в зоне"""
	_player_in_range = value
	
	# Обновляем видимость иконки взаимодействия
	if interaction_component:
		interaction_component.update_visibility()

func is_alive() -> bool:
	"""Проверка, жив ли актёр"""
	return current_health > 0

func get_health_percentage() -> float:
	"""Процент здоровья"""
	return float(current_health) / max_health if max_health > 0 else 0.0

func get_actor_info() -> Dictionary:
	"""Информация об актёре для сохранения"""
	return {
		"actor_id": actor_id,
		"display_name": display_name,
		"current_health": current_health,
		"max_health": max_health,
		"current_mode": current_mode,
		"is_interactive": is_interactive,
		"dialogue_timeline": dialogue_timeline
	}

func _on_game_state_changed(new_state: int, old_state: int) -> void:
	"""Реакция на смену состояния игры
	Используем константы из PlayerController для согласованности"""
	
	_is_world_mode = (new_state == 0)  # 0 = WORLD

func _apply_hostile_appearance() -> void:
	"""Визуальные изменения при становлении врагом"""
	var sprite = $Sprite2D
	if sprite:
			print_debug(display_name, ": внешний вид изменён на враждебный")

func get_actor_id() -> String:
	"""Возвращает ID актёра"""
	return actor_id

# ==================== ПУБЛИЧНЫЕ МЕТОДЫ ====================
func enter_combat(combat_manager: Node) -> void:
	"""Вход в боевой режим"""
	print_debug(display_name, ": вступает в бой")
	
	if combat_component and combat_component.has_method("setup_combat"):
		combat_component.setup_combat(combat_manager)
	
	change_mode("hostile")

func check_decision_triggers() -> Dictionary:
	"""Проверка триггеров для точек решений (для CombatManager)"""
	if combat_component and combat_component.has_method("check_decision_triggers"):
		return combat_component.check_decision_triggers()
	return {}

func mark_trigger_used(trigger_type: String) -> void:
	"""Пометить триггер как использованный"""
	if combat_component and combat_component.has_method("mark_trigger_used"):
		combat_component.mark_trigger_used(trigger_type)
		
#=======TEST атаки и точек решения
# 2. Метод для обработки смерти от CombatComponent
func _on_combat_death(killer: Node = null) -> void:
	"""Смерть в бою (вызывается CombatComponent)"""
	print_debug(display_name, ": смерть в бою")
	
	# Отключаем всё
	is_interactive = false
	_player_in_range = false
	
	if interaction_component:
		interaction_component.set_active(false)
	
	if combat_component:
		combat_component.set_active(false)
	
	if ai_component:
		ai_component.set_active(false)
	
	# Визуальный эффект смерти
	_play_death_effect(killer)
	
	# Сигналы
	actor_died.emit(self)
	EventBus.Actors.died.emit(self)

# 3. Визуальный эффект смерти
func _play_death_effect(killer: Node = null) -> void:
	"""Простой эффект смерти"""
	var sprite = $Sprite2D
	if sprite:
		# Затемнение
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(0.3, 0.3, 0.3, 0.5), 0.5)
		tween.tween_callback(_finalize_death)
	
	# TODO: позже добавить анимацию падения/исчезновения

func _finalize_death() -> void:
	"""Финальная стадия смерти"""
	hide()
	set_process(false)
	set_physics_process(false)
	queue_free()
	
func _on_combat_health_changed(current: int, max: int) -> void:
	"""Когда здоровье в бою изменилось"""
	# Синхронизируем с Actor
	current_health = current
	max_health = max
	health_changed.emit(current, max)
