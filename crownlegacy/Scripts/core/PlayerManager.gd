# PlayerManager.gd (АВТОЗАГРУЗКА)
extends Node

# ==================== СИГНАЛЫ ====================
signal level_up(new_level: int, stat_increases: Dictionary)
signal experience_gained(amount: int, new_total: int)
signal equipment_changed(slot: String, old_item: String, new_item: String)

# ==================== ПЕРЕМЕННЫЕ ====================
var player_data: PlayerData
var equipped_items: Dictionary = {}  # Кэш реальных объектов снаряжения
var active_buffs: Array = []

# Конфигурация баланса
@export var balance_config: BalanceConfig  # Создайте отдельный ресурс

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func _ready() -> void:
	# Загружаем данные по умолчанию
	player_data = PlayerData.new()
	
	# Создаём конфиг баланса, если не задан
	if not balance_config:
		balance_config = BalanceConfig.new()
	
	print_debug("PlayerManager загружен")

	await get_tree().process_frame
	call_deferred("_sync_ability_assignments")
	
	# Отправляем начальные данные
	EventBus.Player.level_up.emit(player_data.level, {})
	
	print_debug("PlayerManager загружен")
# ==================== УРОВНИ И ОПЫТ ====================
func add_experience(amount: int, source: String = "unknown") -> void:
	if not player_data:
		return
	
	player_data.experience += amount
	EventBus.experience_gained.emit(amount, player_data.experience)
	
	var levels_gained = 0
	while player_data.experience >= player_data.experience_to_next_level:
		_level_up()
		levels_gained += 1
	
	if levels_gained > 0:
		print_debug("Получено %d уровней от %s" % [levels_gained, source])

func _level_up() -> void:
	var old_level = player_data.level
	
	# Расчёт нового опыта
	player_data.experience -= player_data.experience_to_next_level
	player_data.level += 1
	player_data.experience_to_next_level = int(player_data.experience_to_next_level * balance_config.level_exp_multiplier)
	
	# Увеличение характеристик
	var stat_increases = {}
	for stat in balance_config.stats_per_level:
		var increase = balance_config.stats_per_level[stat]
		player_data.base_stats[stat] += increase
		stat_increases[stat] = increase
	
	# Восстановление здоровья/маны
	player_data.max_hp += balance_config.hp_per_level
	player_data.set_current_hp(player_data.max_hp)
	player_data.max_mp += balance_config.mp_per_level
	player_data.set_current_mp(player_data.max_mp)
	
	# Сигналы
	level_up.emit(player_data.level, stat_increases)
	EventBus.level_up.emit(player_data.level, stat_increases)
	print_debug("Уровень повышен до %d!" % player_data.level)

# ==================== СНАРЯЖЕНИЕ ====================
func equip_item(item_id: String, slot: String) -> void:
	if not slot in player_data.equipment:
		push_warning("Неизвестный слот: %s" % slot)
		return
	
	var old_item = player_data.equipment[slot]
	player_data.equipment[slot] = item_id
	
	# Здесь можно загрузить реальный ресурс предмета
	# var item_resource = load("res://items/%s.tres" % item_id)
	# equipped_items[slot] = item_resource
	
	equipment_changed.emit(slot, old_item, item_id)
	EventBus.equipment_changed.emit(slot, old_item, item_id)

func get_equipment_bonus(stat_name: String) -> int:
	# Рассчитывает суммарный бонус от всего снаряжения
	var total_bonus = 0
	for item in equipped_items.values():
		if item and item.has_stat_bonus(stat_name):
			total_bonus += item.get_stat_bonus(stat_name)
	return total_bonus

# ==================== БОЕВЫЕ МЕТОДЫ ====================
func take_damage(amount: int, damage_type: String = "physical") -> void:
	if not player_data or not player_data.is_alive():
		return
	
	var old_hp = player_data.current_hp
	
	# Рассчёт защиты
	var defense_stat = "defense" if damage_type == "physical" else "magic_defense"
	var defense_value = get_effective_stat(defense_stat)
	var damage_taken = max(1, amount - defense_value)  # Минимум 1 урон
	
	player_data.set_current_hp(player_data.current_hp - damage_taken)
	
	# Сигнал в EventBus
	EventBus.player_took_damage.emit(damage_taken, player_data.current_hp)
	
	if not player_data.is_alive():
		EventBus.player_died.emit()

func heal(amount: int, source: String = "unknown") -> void:
	if not player_data or not player_data.is_alive():
		return
	
	var old_hp = player_data.current_hp
	player_data.set_current_hp(player_data.current_hp + amount)
	
	# Сигнал только если действительно полечились
	if player_data.current_hp > old_hp:
		EventBus.player_healed.emit(player_data.current_hp - old_hp, player_data.current_hp)

func _sync_ability_assignments():
	# Находим AbilityComponent (может быть в Player узле)
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("AbilityComponent"):
		var ability_comp = player.get_node("AbilityComponent")
		ability_comp.load_assignments(player_data.ability_slot_assignments)
		print("PlayerManager: синхронизированы назначения способностей")
	
	# Альтернатива через сигнал
	EventBus.UI.hud_update_required.connect(_on_hud_update_requested)
	
func _on_hud_update_requested(data: Dictionary):
	# Можно обновлять UI здесь если нужно
	pass

# ==================== УТИЛИТЫ ====================
func get_effective_stat(stat_name: String) -> int:
	var base = player_data.get_stat(stat_name)
	var equipment_bonus = get_equipment_bonus(stat_name)
	var effect_bonus = _get_effects_bonus(stat_name)
	var trust_multiplier = RelationshipManager.get_combat_modifier("damage_multiplier")  # Пример
	
	return int((base + equipment_bonus + effect_bonus) * trust_multiplier)

func _get_effects_bonus(stat_name: String) -> int:
	# Суммирует бонусы от всех активных эффектов
	var total = 0
	for effect in active_buffs:
		if effect.has_stat_bonus(stat_name):
			total += effect.get_stat_bonus(stat_name)
	return total

# ==================== СОХРАНЕНИЕ ====================
func save_player_data() -> Dictionary:
	var data = player_data.get_save_data()
	
	# Сохраняем текущие назначения из AbilityComponent
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("AbilityComponent"):
		var ability_comp = player.get_node("AbilityComponent")
		player_data.ability_slot_assignments = ability_comp.save_assignments()
	
	return data

func load_player_data(data: Dictionary) -> void:
	player_data.load_save_data(data)
