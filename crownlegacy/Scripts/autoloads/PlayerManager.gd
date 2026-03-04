extends Node
#это автозагрузка!

# ==================== ПЕРЕМЕННЫЕ ====================
var player_data: PlayerData

# Кэш модификаторов отношений
var _trust_damage_multiplier: float = 1.0
var _trust_cost_multiplier: float = 1.0

# Ссылки на компоненты
var health_component: HealthComponent
var stamina_component: ResourceComponent
var mana_component: ResourceComponent
var progression_component: ProgressionComponent
var ability_component: AbilityComponent

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func _ready() -> void:
	await get_tree().process_frame
	_find_components()
	_bind_player_data()
	_setup_connections()
	
	print_debug("PlayerManager загружен")

func _find_components() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("PlayerManager: игрок не найден")
		return
	
	health_component = player.get_node("HealthComponent") if player.has_node("HealthComponent") else null
	stamina_component = player.get_node("StaminaComponent") if player.has_node("StaminaComponent") else null
	mana_component = player.get_node("ManaComponent") if player.has_node("ManaComponent") else null
	progression_component = player.get_node("ProgressionComponent") if player.has_node("ProgressionComponent") else null
	ability_component = player.get_node("PlayerCombatComponent/AbilityComponent") if player.has_node("PlayerCombatComponent/AbilityComponent") else null

func _bind_player_data() -> void:
	# PlayerData должен быть единым источником данных (тот же ресурс, который
	# используют компоненты Player). Если его нет — создаём временный.
	var player = get_tree().get_first_node_in_group("player")
	if player and "player_data" in player and player.player_data:
		player_data = player.player_data
		return
	
	if progression_component and progression_component.entity_data:
		player_data = progression_component.entity_data as PlayerData
		return
	
	player_data = PlayerData.new()

func _setup_connections() -> void:
	EventBus.Relationship.trust_changed.connect(_on_trust_changed)

# ==================== ОБРАБОТЧИКИ ====================
func _on_trust_changed(new_value: int, _delta: int) -> void:
	_trust_damage_multiplier = 1.0 + (new_value * 0.005)
	_trust_cost_multiplier = max(0.5, 1.0 + (new_value * -0.002))

# ==================== ДЕЛЕГИРОВАНИЕ КОМПОНЕНТАМ ====================
func add_experience(amount: int, source: String = "unknown") -> void:
	if progression_component:
		progression_component.add_experience(amount, source)

func heal(amount: int, _source: String = "unknown") -> void:
	if health_component:
		health_component.heal(amount)

func get_effective_stat(stat_name: String) -> int:
	if progression_component:
		return progression_component.get_stat(stat_name)
	return int(player_data.get_stat(stat_name) * _trust_damage_multiplier)

# ==================== СОХРАНЕНИЕ ====================
func save_player_data() -> Dictionary:
	# Сохраняем назначения способностей
	if ability_component:
		player_data.ability_slot_assignments = ability_component.save_assignments()
	
	return player_data.get_save_data()

func load_player_data(data: Dictionary) -> void:
	player_data.load_save_data(data)
	
	# Применяем назначения способностей в компонент (если есть)
	if ability_component:
		ability_component.load_assignments(player_data.ability_slot_assignments)
	
	# Обновляем компоненты
	if health_component and health_component.has_method("refresh_from_data"):
		health_component.refresh_from_data()
	
	print_debug("PlayerManager: данные загружены")
