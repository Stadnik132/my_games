extends EntityData
class_name PlayerData

@export var character_name: String = "Клоус"

@export var min_block_stamina: int = 5
@export var block_damage_reduction: float = 0.5

@export var equipment: Dictionary = {
	"weapon": "",
	"armor": "",
	"accessory_1": "",
	"accessory_2": ""
}

# ==================== СОХРАНЕНИЕ ====================
func get_save_data() -> Dictionary:
	var data = super.get_save_data()
	data.merge({
		"character_name": character_name,
		"min_block_stamina": min_block_stamina,
		"block_damage_reduction": block_damage_reduction,
		"equipment": equipment.duplicate(true)
	})
	return data

func load_save_data(data: Dictionary) -> void:
	super.load_save_data(data)

	if data.has("character_name"): character_name = data.character_name
	if data.has("min_block_stamina"): min_block_stamina = data.min_block_stamina
	if data.has("block_damage_reduction"): block_damage_reduction = data.block_damage_reduction
	if data.has("equipment"): equipment = data.equipment.duplicate(true)

