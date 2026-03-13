extends Node
# НЕТ class_name - это автозагрузка!

# ==================== СИГНАЛЫ ====================
signal combat_started(enemies: Array)
signal combat_ended(victory: bool, experience_gained: int)

# ==================== НАСТРОЙКИ ====================
@export var debug_mode: bool = true
@export var base_experience_per_enemy: int = 25

# ==================== ПЕРЕМЕННЫЕ СОСТОЯНИЯ ====================
var active_enemies: Array = []
var is_combat_active: bool = false
var _enemies_count_at_start: int = 0
var _initialized_enemies: Array = []

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func _ready() -> void:
	add_to_group("combat_manager")
	_setup_connections()
	
	if debug_mode:
		print_debug("CombatManager загружен")

func _setup_connections() -> void:
	# Слушаем запросы на начало боя
	EventBus.Combat.started.connect(_on_combat_started)
	EventBus.Dialogue.start_battle.connect(_on_dialogue_start_battle)
	
	# Слушаем смерть игрока
	EventBus.Entity.died.connect(_on_entity_died)
	
	# Слушаем события от DecisionSystem
	EventBus.Combat.decision.transition_to_dialogue.connect(_on_transition_to_dialogue)
	EventBus.Combat.decision.enemy_spared.connect(_on_enemy_spared)

# ==================== УПРАВЛЕНИЕ БОЕМ ====================
func start_combat(enemies: Array) -> void:
	if debug_mode:
		print_debug("CombatManager: начало боя с ", enemies.size(), " врагами")
	
	# Если бой уже идет - добавляем врагов к существующему
	if is_combat_active:
		print_debug("CombatManager: добавляем врагов в текущий бой")
		for enemy in enemies:
			if enemy not in active_enemies:
				print_debug("  добавляем: ", enemy.name)
				active_enemies.append(enemy)
				_initialize_enemy(enemy)
			else:
				print_debug("  уже в бою: ", enemy.name)
		return
	
	# Новый бой
	_initialized_enemies.clear()
	active_enemies = enemies.duplicate()
	_enemies_count_at_start = enemies.size()
	is_combat_active = true
	
	for enemy in enemies:
		_initialize_enemy(enemy)
	
	combat_started.emit(enemies)
	EventBus.Combat.started.emit(enemies)

func end_combat(victory: bool, transition_to_dialogue: bool = false, dialogue_target: Node = null) -> void:
	if debug_mode:
		print_debug("CombatManager: конец боя. Победа: ", victory)
	
	# Очищаем состояние
	var experience_gained = _calculate_experience(victory)
	
	active_enemies.clear()
	is_combat_active = false
	_initialized_enemies.clear()
	
	# Уведомляем всех
	combat_ended.emit(victory, experience_gained)
	EventBus.Combat.ended.emit(victory)
	
	# Переход в соответствующее состояние
	if transition_to_dialogue and dialogue_target:
		var timeline = ""
		if dialogue_target.has_method("get_dialogue_timeline"):
			timeline = dialogue_target.get_dialogue_timeline()
		elif "dialogue_timeline" in dialogue_target:
			timeline = dialogue_target.dialogue_timeline
		
		if not timeline.is_empty():
			EventBus.Game.dialogue_requested.emit(timeline)
		else:
			# Если нет диалога - просто в мир
			EventBus.Game.world_requested.emit()
	elif not victory:
		EventBus.Game.game_over_requested.emit()
	else:
		EventBus.Game.world_requested.emit()

# ==================== ОБРАБОТКА ВРАГОВ ====================
func _initialize_enemy(enemy: Node) -> void:
	print_debug("CombatManager: _initialize_enemy для ", enemy.name)
	
	if enemy.has_meta("in_combat"):
		print_debug("  уже в бою, пропускаем")
		return
	
	if debug_mode:
		print_debug("CombatManager: инициализация врага ", enemy.name)
	
	# Уведомляем врага о начале боя
	if enemy.has_method("enter_combat"):  # ← проверь, есть ли такой метод
		print_debug("  вызываем enter_combat()")
		enemy.enter_combat(self)
	else:
		print_debug("  ❌ у врага нет метода enter_combat!")
	
	# Подписываемся на смерть
	var health_comp = enemy.get_node_or_null("HealthComponent")
	if health_comp and health_comp.has_signal("died"):
		health_comp.died.connect(_on_enemy_died.bind(enemy))
	
	# Помечаем
	enemy.set_meta("in_combat", true)
	_initialized_enemies.append(enemy)

func _on_enemy_died(enemy: Node) -> void:
	print_debug("CombatManager: враг умер: ", enemy.name)
	print_debug("  active_enemies до: ", active_enemies)
	
	_initialized_enemies.erase(enemy)
	active_enemies.erase(enemy)
	
	print_debug("  active_enemies после: ", active_enemies)
	print_debug("  размер: ", active_enemies.size())
	if debug_mode:
		print_debug("CombatManager: враг умер: ", enemy.name)
	
	# Удаляем из списков
	_initialized_enemies.erase(enemy)
	active_enemies.erase(enemy)
	
	# Убираем метку
	if enemy.has_meta("in_combat"):
		enemy.remove_meta("in_combat")
	
	# Уведомляем о смерти
	EventBus.Entity.died.emit(enemy)
	
	# Проверяем конец боя
	if active_enemies.size() == 0:
		end_combat(true)

func _on_enemy_spared(enemy: Node) -> void:
	"""Враг пощажён — удаляем из боя без смерти"""
	if debug_mode:
		print_debug("CombatManager: враг пощажён: ", enemy.name)
	
	# Удаляем из списков
	_initialized_enemies.erase(enemy)
	active_enemies.erase(enemy)
	
	# Убираем метку боя
	if enemy.has_meta("in_combat"):
		enemy.remove_meta("in_combat")
	
	# Проверяем конец боя
	if active_enemies.size() == 0:
		end_combat(true)

func _on_transition_to_dialogue(enemy: Node, timeline: String) -> void:
	"""Переход в диалог из точки решения"""
	if debug_mode:
		print_debug("CombatManager: переход в диалог с ", enemy.name)
	
	end_combat(false, true, enemy)

# ==================== РАСЧЁТ ОПЫТА ====================
func _calculate_experience(victory: bool) -> int:
	if not victory:
		return 0
	return base_experience_per_enemy * _enemies_count_at_start

# ==================== ОБРАБОТЧИКИ СОБЫТИЙ ====================
func _on_combat_started(enemies: Array) -> void:
	# Защита от двойного вызова
	if is_combat_active:
		return
	start_combat(enemies)

func _on_dialogue_start_battle(npc_id: String) -> void:
	if debug_mode:
		print_debug("CombatManager: запрос боя с NPC ID: ", npc_id)
	
	var npc = _find_npc_by_id(npc_id)
	if npc:
		start_combat_with_npc(npc)

func start_combat_with_npc(npc: Node) -> void:
	if debug_mode:
		print_debug("CombatManager: начало боя с NPC ", npc.name)
	
	# Переводим NPC в боевой режим
	if npc.has_method("become_enemy"):
		npc.become_enemy(self)
	elif npc.has_method("change_mode"):
		npc.change_mode("battle")
	
	# Начинаем бой
	start_combat([npc])

func _find_npc_by_id(npc_id: String) -> Node:
	"""Поиск NPC по ID среди всех актёров"""
	for actor in get_tree().get_nodes_in_group("actors"):
		if "actor_id" in actor and actor.actor_id == npc_id:
			return actor
		if "display_name" in actor and actor.display_name == npc_id:
			return actor
	return null

func _on_entity_died(entity: Node) -> void:
	"""Обработчик смерти любой сущности"""
	if entity.is_in_group("player"):
		if debug_mode:
			print_debug("CombatManager: игрок умер в бою")
		end_combat(false)

# ==================== ПУБЛИЧНЫЕ МЕТОДЫ ====================
func is_in_combat() -> bool:
	return is_combat_active

func get_active_enemies() -> Array:
	return active_enemies.duplicate()
