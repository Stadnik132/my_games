# ItemResource.gd
extends Resource
class_name ItemResource

# Уникальный идентификатор предмета (например "health_potion")
@export var id: String = ""

# Отображаемое название
@export var name: String = "Предмет"

# Описание для UI
@export_multiline var description: String = ""

# Иконка для инвентаря
@export var icon: Texture2D

# Можно ли складывать в стопку
@export var stackable: bool = true

# Максимальный размер стопки (если stackable)
@export var max_stack: int = 99

# Базовая цена (для продажи/покупки)
@export var value: int = 0

# Тип предмета (для фильтрации в UI)
enum ItemType {
	CONSUMABLE,  # расходуемое (зелья, еда)
	EQUIPMENT,   # снаряжение (оружие, броня)
	QUEST,       # квестовый предмет
	MATERIAL,    # материал для крафта
	MISC         # прочее
}
@export var item_type: ItemType = ItemType.MISC

func _init(p_id: String = "", p_name: String = ""):
	if p_id:
		id = p_id
	if p_name:
		name = p_name
