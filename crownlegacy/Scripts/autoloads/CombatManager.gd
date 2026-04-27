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
	EventBus.Combat.start_combat_requested.connect(_on_start_combat_requested)
	EventBus.Combat.started.connect(_on_combat_started)
	EventBus.Dialogue.start_battle.connect(_on_dialogue_start_battle)
	
	# Слушаем смерть игрока
	EventBus.Entity.died.connect(_on_entity_died)
	
	# Слушаем события от DecisionSystem
	EventBus.Combat.decision.transition_to_dialogue.connect(_on_transition_to_dialogue)
	EventBus.Combat.decision.enemy_spared.connect(_on_enemy_spared)

# ==================== УПРАВЛЕНИЕ БОЕМ ====================
func start_combat(enemies: Array, marker_point: Node = null) -> void:
	"""
	Начало боя с опциональным отскоком персонажей.
	
	Параметры:
	- enemies: массив врагов (Actor) которые участвуют в бою
	- marker_point: Node2D — точка куда Player прыгнет (для боссов).
	  Если null — работает формула отскока по умолчанию.
	
	  Как использовать marker_point:
	  1. В сцене создай Node2D (или Marker2D) рядом с боссом
	  2. Назови его например "BossMarker"
	  3. Передай в start_combat([boss_actor], $BossMarker)
	  4. Player прыгнет к этой точке, босс НЕ прыгнет
	"""
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

	# Запускаем отскок перед боем
	_perform_combat_start_jump(enemies, marker_point)

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

func _on_start_combat_requested(enemies: Array) -> void:
	"""Обработчик запроса на начало боя от врагов (без диалога)"""
	if is_combat_active:
		print_debug("CombatManager: бой уже идёт, пропускаю запрос")
		return
	EventBus.Combat.started.emit(enemies)
	if debug_mode:
		print_debug("CombatManager: запрос на бой от врагов: ", enemies)
	
	# Проверяем, что все враги в массиве
	for enemy in enemies:
		if not enemy or not is_instance_valid(enemy):
			push_warning("CombatManager: недействительный враг в запросе")
			return
	
	# Начинаем бой
	EventBus.Combat.started.emit(enemies)

func _on_dialogue_start_battle(npc_id: String) -> void:
	"""Обработчик начала боя через диалог (для Actor)"""
	if debug_mode:
		print_debug("CombatManager: начало боя через диалог с NPC ID: ", npc_id)
	
	# Находим актора по ID
	var actor = _find_actor_by_id(npc_id)
	if not actor:
		push_error("CombatManager: актор с ID '" + npc_id + "' не найден!")
		return
	
	# Начинаем бой с этим актором
	EventBus.Combat.started.emit([actor])

func _find_actor_by_id(npc_id: String) -> Node:
	"""Поиск актора по ID среди всех акторов в сцене"""
	var actors = get_tree().get_nodes_in_group("actors")
	for actor in actors:
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

# ==================== ПУБЛИЧНЫЕ МЕТОДЫ ====================
func is_in_combat() -> bool:
	return is_combat_active

func get_active_enemies() -> Array:
	return active_enemies.duplicate()

# ==================== ОТБАСЫВАНИЕ ПРИ НАЧАЛЕ БОЯ ====================
func _perform_combat_start_jump(enemies: Array, marker_point: Node = null) -> void:
	"""
	Плавное расхождение Player и Actor при начале боя.
	
	Логика:
	- Player прыгает в сторону ОТ первого врага (или к marker_point если задан)
	- Actor прыгает в противоположную сторону от Player
	- Если marker_point задан — Actor НЕ прыгает (босс стоит на месте)
	- После задержки (combat_start_delay) начинается бой
	"""
	var player = get_tree().get_first_node_in_group("player")
	if not player or enemies.is_empty():
		# Нет игрока или врагов — сразу начинаем бой
		_finalize_combat_start(enemies)
		return

	var enemy = enemies[0] as Node
	var config = _get_combat_config_from_enemy(enemy)
	
	if not config:
		_finalize_combat_start(enemies)
		return

	var jump_distance = config.combat_start_jump_distance
	var jump_duration = config.combat_start_jump_duration
	var delay = config.combat_start_delay

	# Направление ОТ игрока К врагу (Player будет прыгать в противоположную сторону)
	var player_to_enemy = (enemy.global_position - player.global_position).normalized()
	
	# Если направление слишком маленькое — используем дефолт (вправо)
	if player_to_enemy.length() < 0.1:
		player_to_enemy = Vector2.RIGHT

	# Player прыгает в сторону ОТ врага (противоположное направление)
	if marker_point:
		# Босс с marker_point — Player прыгает к точке, Actor НЕ прыгает
		if player.has_method("combat_start_jump"):
			player.combat_start_jump(Vector2.ZERO, 0, jump_duration, marker_point)
	else:
		# Обычный бой — оба прыгают
		# Player прыгает ОТ врага
		if player.has_method("combat_start_jump"):
			player.combat_start_jump(-player_to_enemy, jump_distance, jump_duration)
		
		# Actor прыгает в сторону ОТ игрока (противоположно Player)
		if enemy.has_method("combat_start_jump"):
			enemy.combat_start_jump(player_to_enemy, jump_distance * 0.7, jump_duration)

	# Задержка перед началом боя
	await get_tree().create_timer(delay).timeout
	_finalize_combat_start(enemies)

func _finalize_combat_start(enemies: Array) -> void:
	"""Завершает начало боя — инициализирует врагов и эммитит сигналы"""
	for enemy in enemies:
		_initialize_enemy(enemy)
	
	combat_started.emit(enemies)
	EventBus.Combat.started.emit(enemies)

func _get_combat_config_from_enemy(enemy: Node) -> CombatConfig:
	"""Получает CombatConfig из Actor"""
	if enemy.has_node("ActorCombatComponent"):
		var combat_comp = enemy.get_node("ActorCombatComponent")
		if combat_comp.has_method("get_combat_config"):
			return combat_comp.get_combat_config()
		if "combat_config" in combat_comp:
			return combat_comp.combat_config
	return null
