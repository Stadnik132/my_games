# InventoryPanel.gd
extends Panel

@onready var item_list: ItemList = $VBoxContainer/ItemList
@onready var use_button: Button = $VBoxContainer/HBoxContainer/UseButton
@onready var drop_button: Button = $VBoxContainer/HBoxContainer/DropButton
@onready var back_button: Button = $BackButton

var inventory_component: InventoryComponent
var selected_slot: int = -1

func _ready():
	use_button.pressed.connect(_on_use_pressed)
	drop_button.pressed.connect(_on_drop_pressed)
	back_button.pressed.connect(_on_back_pressed)
	item_list.item_selected.connect(_on_item_selected)
	
	use_button.disabled = true
	drop_button.disabled = true

func setup(inv: InventoryComponent) -> void:
	if inventory_component:
		if inventory_component.inventory_changed.is_connected(refresh):
			inventory_component.inventory_changed.disconnect(refresh)
	
	inventory_component = inv
	
	if inventory_component:
		inventory_component.inventory_changed.connect(refresh)
	
	refresh()

func refresh() -> void:
	"""Обновляет отображение инвентаря"""
	item_list.clear()
	if not inventory_component:
		return
	
	print("🟢 refresh: проверяем слоты...")
	for i in range(inventory_component.max_slots):
		var slot = inventory_component.get_item_at_slot(i)
		if slot:
			print("  Слот ", i, ": ", slot.item.name, " x", slot.quantity)
			var text = "%s x%d" % [slot.item.name, slot.quantity]
			var idx = item_list.add_item(text)
			item_list.set_item_metadata(idx, i)
			if slot.item.icon:
				item_list.set_item_icon(idx, slot.item.icon)
	
	print("🟢 refresh: добавлено в ItemList: ", item_list.item_count)
	
	selected_slot = -1
	use_button.disabled = true
	drop_button.disabled = true

func _on_item_selected(index: int) -> void:
	selected_slot = item_list.get_item_metadata(index)
	use_button.disabled = false
	drop_button.disabled = false

func _on_use_pressed() -> void:
	if selected_slot >= 0 and inventory_component:
		inventory_component.remove_item(selected_slot, 1)

func _on_drop_pressed() -> void:
	if selected_slot >= 0 and inventory_component:
		inventory_component.remove_item(selected_slot, 1)

func _on_close_pressed() -> void:
	hide()

func _on_back_pressed() -> void:
	hide()
