extends Node
# НЕТ class_name - это автозагрузка!

# ==================== ПЕРЕМЕННЫЕ ====================
var player_data: PlayerData

# Кэш модификаторов отношений (обновляется через EventBus)
var _trust_damage_multiplier: float = 1.0
var _trust_cost_multiplier: float = 1.0

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func _ready() -> void:
	# Загружаем данные по умолчанию
	player_data = PlayerData.new()
	
	_setup_connections()
	
	print_debug("PlayerManager загружен")
	
	await get_tree().process_frame
	_sync_ability_assignments()
	
	# Hurtbox -> урон и стан обрабатываются в PlayerCombatComponent (_on_hurtbox_damage -> apply_damage_data + request_stun)
	
	# Эмитим начальное состояние
	EventBus.Player.experience_gained.emit(0, player_data.experience)
	EventBus.Player.level_up.emit(player_data.level, {})

func _setup_connections() -> void:
	# Слушаем сигналы самого PlayerData
	player_data.died.connect(_on_player_died)
	player_data.hp_changed.connect(_on_hp_changed)
	player_data.mp_changed.connect(_on_mp_changed)
	player_data.stamina_changed.connect(_on_stamina_changed)
	player_data.level_changed.connect(_on_level_changed)
	player_data.experience_changed.connect(_on_experience_changed)
	
	# Слушаем изменения отношений через EventBus
	EventBus.Relationship.trust_changed.connect(_on_trust_changed)
	
	# Запросы на получение урона
	EventBus.Player.damage_taken.connect(damage_taken)

# ==================== ОБРАБОТЧИКИ СОБЫТИЙ PLAYERDATA ====================
func _on_player_died() -> void:
	print_debug("PlayerManager: игрок умер")
	EventBus.Player.died.emit()

func _on_hp_changed(new_hp: int, old_hp: int) -> void:
	EventBus.Player.hp_changed.emit(new_hp, old_hp)

func _on_mp_changed(new_mp: int, old_mp: int) -> void:
	EventBus.Player.mp_changed.emit(new_mp, old_mp)

func _on_stamina_changed(new_stamina: int, old_stamina: int) -> void:
	EventBus.Player.stamina_changed.emit(new_stamina, old_stamina)

func _on_level_changed(new_level: int, old_level: int) -> void:
	# При изменении уровня эмитим level_up с пустыми статами
	# Реальное увеличение статов происходит в _level_up()
	EventBus.Player.level_up.emit(new_level, {})
	print_debug("Уровень игрока: ", new_level)

func _on_experience_changed(new_exp: int, old_exp: int) -> void:
	EventBus.Player.experience_gained.emit(new_exp - old_exp, new_exp)

# ==================== ОБРАБОТЧИКИ ВНЕШНИХ СОБЫТИЙ ====================
func _on_trust_changed(new_value: int, delta: int) -> void:
	"""Обновляем кэш модификаторов при изменении доверия"""
	_trust_damage_multiplier = 1.0 + (new_value * 0.005)
	_trust_cost_multiplier = max(0.5, 1.0 + (new_value * -0.002))

# ==================== УРОВНИ И ОПЫТ ====================
func add_experience(amount: int, source: String = "unknown") -> void:
	if not player_data:
		return
	
	player_data.set_experience(player_data.experience + amount)
	
	var levels_gained = 0
	while player_data.experience >= player_data.experience_to_next_level:
		_level_up()
		levels_gained += 1
	
	if levels_gained > 0:
		print_debug("Получено %d уровней от %s" % [levels_gained, source])

func _level_up() -> void:
	# Расчёт нового опыта
	player_data.experience -= player_data.experience_to_next_level
	
	# Увеличение уровня
	var old_level = player_data.level
	player_data.set_level(player_data.level + 1)
	
	# Прогрессия опыта: каждые 5 уровней +25% к порогу
	var level = player_data.level
	var multiplier = 1.0 + (floor(level / 5) * 0.25)
	player_data.experience_to_next_level = int(100 * multiplier)
	
	# Увеличение характеристик
	var stat_increases = {}
	
	# Базовое увеличение статов
	player_data.set_stat("attack", player_data.get_stat("attack") + 2)
	stat_increases["attack"] = 2
	
	player_data.set_stat("magic_attack", player_data.get_stat("magic_attack") + 2)
	stat_increases["magic_attack"] = 2
	
	player_data.set_stat("defense", player_data.get_stat("defense") + 1)
	stat_increases["defense"] = 1
	
	player_data.set_stat("magic_defense", player_data.get_stat("magic_defense") + 1)
	stat_increases["magic_defense"] = 1
	
	player_data.set_stat("speed", player_data.get_stat("speed") + 1)
	stat_increases["speed"] = 1
	
	player_data.set_stat("agility", player_data.get_stat("agility") + 1)
	stat_increases["agility"] = 1
	
	# Увеличение здоровья и маны
	player_data.max_hp += 10
	player_data.set_current_hp(player_data.max_hp)
	
	player_data.max_mp += 5
	player_data.set_current_mp(player_data.max_mp)
	
	# Сигнал уже будет отправлен через _on_level_changed
	print_debug("Уровень повышен до %d!" % player_data.level)

# ==================== БОЕВЫЕ МЕТОДЫ ====================
func apply_damage_data(damage_data: DamageData, source: Node = null, was_blocked: bool = false) -> void:
	"""Урон из Hurtbox (Hitbox -> Hurtbox). Конвертирует DamageData в amount/type и вызывает damage_taken."""
	if not damage_data:
		return
	var amount = damage_data.amount
	var damage_type = damage_data.get_damage_type_name().to_lower()
	damage_taken(amount, damage_type, source, was_blocked, damage_data.can_crit)

func damage_taken(amount: int, damage_type: String, source: Node = null, was_blocked: bool = false, is_critical: bool = false) -> void:
	print_debug("Игрок получает урон:", amount, " тип:", damage_type)
	
	if not player_data or not player_data.is_alive():
		print_debug("  Игрок мёртв или нет данных")
		return
	
	var old_hp = player_data.current_hp
	
	# Расчёт защиты
	var defense_stat = "defense" if damage_type == "physical" else "magic_defense"
	var defense_value = get_effective_stat(defense_stat)
	var final_damage = maxi(1, amount - defense_value)
	
	if was_blocked:
		final_damage = player_data.calculate_blocked_damage(final_damage)
		print_debug("  Блок: урон снижен до ", final_damage)
	
	print_debug("  Защита:", defense_value, " Получено урона:", final_damage)
	
	player_data.set_current_hp(player_data.current_hp - final_damage)
	
	EventBus.Player.damage_taken.emit(final_damage, damage_type, source, was_blocked, is_critical)

func heal(amount: int, source: String = "unknown") -> void:
	print_debug("Игрок лечится:", amount, " от:", source)
	
	if not player_data or not player_data.is_alive():
		return
	
	var old_hp = player_data.current_hp
	player_data.set_current_hp(player_data.current_hp + amount)
	
	if player_data.current_hp > old_hp:
		EventBus.Player.healed.emit(player_data.current_hp - old_hp, player_data.current_hp)

# ==================== СИНХРОНИЗАЦИЯ СПОСОБНОСТЕЙ ====================
func _sync_ability_assignments() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("AbilityComponent"):
		var ability_comp = player.get_node("AbilityComponent")
		ability_comp.load_assignments(player_data.ability_slot_assignments)
		print_debug("PlayerManager: синхронизированы назначения способностей")

# ==================== УТИЛИТЫ ====================
func get_effective_stat(stat_name: String) -> int:
	var base = player_data.get_stat(stat_name)
	# Снаряжение и эффекты пока не реализованы
	return int(base * _trust_damage_multiplier)

# ==================== СОХРАНЕНИЕ ====================
func save_player_data() -> Dictionary:
	# Сохраняем текущие назначения из AbilityComponent
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("AbilityComponent"):
		var ability_comp = player.get_node("AbilityComponent")
		player_data.ability_slot_assignments = ability_comp.save_assignments()
	
	return player_data.get_save_data()

func load_player_data(data: Dictionary) -> void:
	player_data.load_save_data(data)
	print_debug("PlayerManager: данные загружены")
