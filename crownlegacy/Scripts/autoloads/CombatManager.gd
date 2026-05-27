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
var _death_sequence_started: bool = false

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func _ready() -> void:
	add_to_group("combat_manager")
	_setup_connections()
	
	if debug_mode:
		print_debug("CombatManager загружен")

func _setup_connections() -> void:
	# Слушаем запросы на начало боя
	EventBus.Combat.start_combat_requested.connect(_on_start_combat_requested)
	EventBus.Combat.started.connect(_on_combat_started)
	EventBus.Dialogue.start_battle.connect(_on_dialogue_start_battle)
	
	# Слушаем смерть игрока
	EventBus.Entity.died.connect(_on_entity_died)
	
	# Слушаем события от DecisionSystem
	EventBus.Combat.decision.transition_to_dialogue.connect(_on_transition_to_dialogue)
	EventBus.Combat.decision.enemy_spared.connect(_on_enemy_spared)
	
	# Persuasion
	EventBus.Combat.persuasion.action_requested.connect(_on_persuasion_requested)
	
	# Inventory
	EventBus.Combat.inventory.use_item_requested.connect(_on_use_item_requested)

	# Damage numbers
	EventBus.Entity.damage_taken.connect(_on_damage_taken)

# ==================== УПРАВЛЕНИЕ БОЕМ ====================
func start_combat(enemies: Array) -> void:
	if debug_mode:
		print_debug("CombatManager: начало боя с ", enemies.size(), " врагами")

	# Если бой уже идет - добавляем врагов к существующему
	if is_combat_active:
		if debug_mode:
			print_debug("CombatManager: добавляем врагов в текущий бой")
		for enemy in enemies:
			if enemy not in active_enemies:
				if debug_mode:
					print_debug("  добавляем: ", enemy.name)
				active_enemies.append(enemy)
				_initialize_enemy(enemy)
				EventBus.Combat.enemy.joined.emit(enemy)
			else:
				if debug_mode:
					print_debug("  уже в бою: ", enemy.name)
		return

	# Новый бой
	_initialized_enemies.clear()
	active_enemies = enemies.duplicate()
	_enemies_count_at_start = enemies.size()
	is_combat_active = true

	_finalize_combat_start(enemies)

func end_combat(victory: bool, transition_to_dialogue: bool = false, dialogue_target: Node = null) -> void:
	_death_sequence_started = false
	
	if debug_mode:
		print_debug("CombatManager: конец боя. Победа: ", victory)
	
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
			EventBus.Game.world_requested.emit()
	elif not victory:
		EventBus.Game.game_over_requested.emit()
	else:
		EventBus.Combat.reward_calculation_requested.emit(experience_gained, [])

# ==================== ОБРАБОТКА ВРАГОВ ====================
func _initialize_enemy(enemy: Node) -> void:
	if enemy.has_meta("in_combat"):
		return
	
	if debug_mode:
		print_debug("CombatManager: инициализация врага ", enemy.name)
	
	if enemy.has_method("enter_combat"):
		enemy.enter_combat(self)
	
	var health_comp = enemy.get_node_or_null("HealthComponent")
	if health_comp and health_comp.has_signal("died"):
		health_comp.died.connect(_on_enemy_died.bind(enemy))
	
	enemy.set_meta("in_combat", true)
	_initialized_enemies.append(enemy)

func _on_enemy_died(enemy: Node) -> void:
	if debug_mode:
		print_debug("CombatManager: враг умер: ", enemy.name)
	
	_initialized_enemies.erase(enemy)
	active_enemies.erase(enemy)
	
	if enemy.has_meta("in_combat"):
		enemy.remove_meta("in_combat")
	
	if active_enemies.size() == 0:
		_start_death_sequence()

func _start_death_sequence() -> void:
	if _death_sequence_started:
		return
	_death_sequence_started = true
	await get_tree().create_timer(0.6).timeout
	_death_sequence_started = false
	if is_combat_active:
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
	if is_combat_active:
		return
	start_combat(enemies)

func _on_start_combat_requested(enemies: Array) -> void:
	"""Обработчик запроса на начало боя от врагов (без диалога)"""
	if is_combat_active:
		print_debug("CombatManager: бой уже идёт, пропускаю запрос")
		return
	if debug_mode:
		print_debug("CombatManager: запрос на бой от врагов: ", enemies)
	
	for enemy in enemies:
		if not enemy or not is_instance_valid(enemy):
			push_warning("CombatManager: недействительный враг в запросе")
			return
	
	start_combat(enemies)

func _on_dialogue_start_battle(npc_ids: Array) -> void:
	if debug_mode:
		print_debug("CombatManager: начало боя через диалог с NPC IDs: ", npc_ids)
	
	var actors = []
	for npc_id in npc_ids:
		var actor = _find_actor_by_id(npc_id.strip_edges())
		if actor:
			actors.append(actor)
		else:
			push_error("CombatManager: актор с ID '" + npc_id + "' не найден!")
	
	if actors.is_empty():
		return
	
	start_combat(actors)

func _find_actor_by_id(npc_id: String) -> Node:
	"""Поиск актора по ID среди всех акторов и врагов в сцене"""
	var candidates = get_tree().get_nodes_in_group("actors") + get_tree().get_nodes_in_group("enemies")
	for actor in candidates:
		if actor.has_method("get_enemy_id") and actor.get_enemy_id() == npc_id:
			return actor
		elif "entity_id" in actor and actor.entity_id == npc_id:
			return actor
	return null


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

func _on_damage_taken(entity: Node, amount: int, _damage_type: int, _source: Node, is_critical: bool) -> void:
	if not is_instance_valid(entity):
		return
	var dmg = DamageNumber.new()
	dmg.damage_amount = amount
	dmg.is_critical_hit = is_critical
	dmg.global_position = entity.global_position
	get_tree().current_scene.add_child(dmg)

# ==================== PERSUASION ====================
func _on_persuasion_requested(action_name: String) -> void:
	var enemy = _get_nearest_enemy_with_resolve()
	if not enemy:
		return
	
	var resolve = enemy.get_node_or_null("ResolveComponent") as ResolveComponent
	if not resolve or resolve.is_surrendered():
		return
	
	var resolve_damage = _get_persuasion_damage(action_name)
	resolve.take_resolve_damage(resolve_damage)
	EventBus.Combat.persuasion.action_performed.emit(action_name, enemy)
	if debug_mode:
		print_debug("CombatManager: persuasion [", action_name, "] на ", enemy.name, " -> resolve dmg ", resolve_damage)

func _get_nearest_enemy_with_resolve() -> Node:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return null
	var nearest: Node = null
	var min_dist: float = INF
	for enemy in active_enemies:
		if not is_instance_valid(enemy):
			continue
		var rc = enemy.get_node_or_null("ResolveComponent") as ResolveComponent
		if not rc or rc.is_surrendered():
			continue
		var dist = enemy.global_position.distance_to(player.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = enemy
	return nearest

func _get_persuasion_damage(action: String) -> int:
	match action:
		"Convince": return 25
		"Threaten": return 40
		"Understand": return 15
	return 20

# ==================== ITEMS ====================
func _on_use_item_requested(slot_index: int) -> void:
	if debug_mode:
		print_debug("CombatManager: use item slot ", slot_index, " (stub)")

# ==================== ПУБЛИЧНЫЕ МЕТОДЫ ====================
func is_in_combat() -> bool:
	return is_combat_active

func get_active_enemies() -> Array:
	return active_enemies.duplicate()

func _finalize_combat_start(enemies: Array) -> void:
	"""Завершает начало боя — инициализирует врагов и эммитит сигналы"""
	if debug_mode:
		print_debug("CombatManager: финализация старта боя для ", enemies.size(), " врагов")
	for enemy in enemies:
		_initialize_enemy(enemy)
	
	combat_started.emit(enemies)
	EventBus.Combat.started.emit(enemies)
