extends Node
#это автозагрузка!

# ==================== ПЕРЕМЕННЫЕ ====================
var player_data: PlayerData

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

func _restore_inventory_from_save(inventory_data: Array) -> void:
	"""Восстанавливает инвентарь из сохранённых данных"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var inv = player.get_node("InventoryComponent") as InventoryComponent
	if not inv:
		return
	
	# Очищаем текущий инвентарь
	inv.clear()
	
	# Загружаем предметы из сохранения
	for slot_data in inventory_data:
		if slot_data and slot_data.has("id"):
			var item = ItemRegistry.get_item(slot_data.id)
			if item:
				inv.add_item(item, slot_data.quantity)
			else:
				push_warning("PlayerManager: предмет не найден в реестре: ", slot_data.id)

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
	return player_data.get_stat(stat_name)


# ==================== СОХРАНЕНИЕ ====================
func save_player_data() -> Dictionary:
	# Сохраняем назначения способностей
	if ability_component:
		player_data.ability_slot_assignments = ability_component.save_assignments()
	
	var data = player_data.get_save_data()
	data["inventory"] = _save_inventory()
	return data

func _save_inventory() -> Array:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return []
	
	var inv = player.get_node_or_null("InventoryComponent") as InventoryComponent
	if not inv:
		return []
	
	var result = []
	for i in range(inv.max_slots):
		var slot = inv.get_item_at_slot(i)
		if slot:
			result.append({
				"id": slot.item.id,
				"quantity": slot.quantity
			})
		else:
			result.append(null)
	return result

func load_player_data(data: Dictionary) -> void:
	player_data.load_save_data(data)
	
	# Применяем назначения способностей в компонент (если есть)
	if ability_component:
		ability_component.load_assignments(player_data.ability_slot_assignments)
	
	# Обновляем компоненты
	if health_component and health_component.has_method("refresh_from_data"):
		health_component.refresh_from_data()
	_restore_inventory_from_save(data.get("inventory", []))
