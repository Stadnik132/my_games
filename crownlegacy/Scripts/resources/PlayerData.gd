extends EntityData
class_name PlayerData

@export var character_name: String = "Клоус"

@export var attack_cooldown: float = 0.8
@export var dodge_stamina_cost: int = 25
@export var block_damage_reduction: float = 0.5
@export var block_stamina_cost_per_second: int = 20

@export var equipment: Dictionary = {
	"weapon": "",
	"armor": "",
	"accessory_1": "",
	"accessory_2": ""
}


# ==================== СПЕЦИФИЧНЫЕ ДЛЯ ИГРОКА МЕТОДЫ ====================
func can_dodge() -> bool:
	return current_stamina >= dodge_stamina_cost


func calculate_blocked_damage(incoming_damage: int) -> int:
	return int(incoming_damage * (1.0 - block_damage_reduction))


func can_block() -> bool:
	return current_stamina >= 5

# ==================== ПЕРЕОПРЕДЕЛЁННЫЕ МЕТОДЫ СОХРАНЕНИЯ ====================
func get_save_data() -> Dictionary:
	var data = super.get_save_data()
	data.merge({
		"character_name": character_name,
		"attack_cooldown": attack_cooldown,
		"dodge_stamina_cost": dodge_stamina_cost,
		"block_damage_reduction": block_damage_reduction,
		"block_stamina_cost_per_second": block_stamina_cost_per_second,
		"equipment": equipment.duplicate(true),
		"inventory": _get_inventory_from_component()
	})
	return data

func _get_inventory_from_component() -> Array:
	"""Читает инвентарь из компонента (для сохранения)"""
	var result = []
	var player = get_player_node()
	if player and player.has_node("InventoryComponent"):
		var inv = player.get_node("InventoryComponent")
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

func load_save_data(data: Dictionary) -> void:
	super.load_save_data(data)
	
	if data.has("character_name"): character_name = data.character_name
	if data.has("attack_cooldown"): attack_cooldown = data.attack_cooldown
	if data.has("dodge_stamina_cost"): dodge_stamina_cost = data.dodge_stamina_cost
	if data.has("block_damage_reduction"): block_damage_reduction = data.block_damage_reduction
	if data.has("block_stamina_cost_per_second"): block_stamina_cost_per_second = data.block_stamina_cost_per_second
	if data.has("equipment"): equipment = data.equipment.duplicate(true)
	
	
func _serialize_inventory() -> Array:
	"""Преобразует инвентарь из компонента в формат для сохранения"""
	var result = []
	var player = get_player_node()
	if player and player.has_node("InventoryComponent"):
		var inv = player.get_node("InventoryComponent")
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

func get_player_node() -> Node:
	"""Вспомогательный метод для получения узла игрока"""
	return Engine.get_main_loop().get_first_node_in_group("player")
