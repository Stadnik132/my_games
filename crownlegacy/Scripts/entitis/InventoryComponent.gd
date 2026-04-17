# InventoryComponent.gd
extends Node
class_name InventoryComponent

# Сигналы
signal item_added(item: ItemResource, quantity: int, slot_index: int)
signal item_removed(slot_index: int, item: ItemResource, quantity: int)
signal inventory_changed
signal inventory_updated

# Структура слота
class SlotData:
	var item: ItemResource
	var quantity: int
	
	func _init(p_item: ItemResource, p_quantity: int = 1):
		item = p_item
		quantity = p_quantity

# Параметры
@export var max_slots: int = 20

# Данные
var slots: Array = []  # массив SlotData или null

func _ready():
	# Инициализация пустых слотов
	slots.resize(max_slots)
	for i in range(max_slots):
		slots[i] = null

# Добавить предмет
func add_item(item: ItemResource, quantity: int = 1) -> bool:
	if item == null:
		push_error("InventoryComponent: попытка добавить null предмет")
		return false
	if quantity <= 0:
		return false
	
	var remaining = quantity
	
	# Если предмет складывается - ищем существующие стопки
	if item.stackable:
		for i in range(max_slots):
			var slot = slots[i] as SlotData
			if slot and slot.item.id == item.id and slot.quantity < item.max_stack:
				var space = item.max_stack - slot.quantity
				var add_amount = min(remaining, space)
				slot.quantity += add_amount
				remaining -= add_amount
				item_added.emit(item, add_amount, i)
				
				if remaining <= 0:
					inventory_changed.emit()
					return true
	
	# Ищем пустые слоты для оставшихся предметов
	while remaining > 0:
		var empty_slot = -1
		for i in range(max_slots):
			if slots[i] == null:
				empty_slot = i
				break
		
		if empty_slot == -1:
			push_warning("InventoryComponent: нет места для ", item.name)
			return false  # Нет места
		
		var add_amount = min(remaining, item.max_stack if item.stackable else 1)
		slots[empty_slot] = SlotData.new(item, add_amount)
		remaining -= add_amount
		item_added.emit(item, add_amount, empty_slot)
	
	inventory_changed.emit()
	inventory_updated.emit()
	return true

# Удалить предмет
func remove_item(slot_index: int, quantity: int = 1) -> bool:
	if slot_index < 0 or slot_index >= max_slots:
		return false
	
	var slot = slots[slot_index] as SlotData
	if not slot or slot.quantity < quantity:
		return false
	
	var item = slot.item
	slot.quantity -= quantity
	item_removed.emit(slot_index, item, quantity)
	
	if slot.quantity <= 0:
		slots[slot_index] = null
	
	inventory_changed.emit()
	inventory_updated.emit()
	return true

func get_item_at_slot(slot_index: int) -> SlotData:
	"""Возвращает SlotData для указанного слота или null, если слот пуст"""
	if slot_index < 0 or slot_index >= max_slots:
		return null
	return slots[slot_index] as SlotData

# Получить предмет в слоте
func get_item_id_at_slot(slot_index: int) -> String:
	"""Получить ID предмета в слоте (для сохранения)"""
	var slot = get_item_at_slot(slot_index)
	if slot and slot.item:
		return slot.item.id
	return ""

# Проверить наличие предмета
func has_item(item_id: String, quantity: int = 1) -> bool:
	var total = 0
	for slot in slots:
		var slot_data = slot as SlotData
		if slot_data and slot_data.item.id == item_id:
			total += slot_data.quantity
			if total >= quantity:
				return true
	return false

# Получить общее количество предмета
func get_item_quantity(item_id: String) -> int:
	var total = 0
	for slot in slots:
		var slot_data = slot as SlotData
		if slot_data and slot_data.item.id == item_id:
			total += slot_data.quantity
	return total

# Очистить инвентарь
func clear() -> void:
	for i in range(max_slots):
		slots[i] = null
	inventory_changed.emit()
	inventory_updated.emit()
