class_name CombatActionMenu extends CanvasLayer

signal action_selected(action_type: String, data: Dictionary)

var is_open: bool = false
var is_in_combat: bool = false
var _saved_time_scale: float = 1.0

@onready var panel: Panel = $Panel
@onready var ability_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/AbilityContainer
@onready var persuasion_container: HBoxContainer = $Panel/MarginContainer/VBoxContainer/PersuasionContainer
@onready var item_container: HBoxContainer = $Panel/MarginContainer/VBoxContainer/ItemContainer

const SLOWMO_SCALE: float = 0.15

func _ready() -> void:
	panel.hide()
	EventBus.Combat.started.connect(_on_combat_started)
	EventBus.Combat.ended.connect(_on_combat_ended)
	EventBus.Combat.ability.slot_pressed.connect(_on_hotkey_pressed)

func _on_combat_started(_enemies: Array = []) -> void:
	is_in_combat = true

func _on_combat_ended(_victory: bool) -> void:
	is_in_combat = false
	if is_open:
		close()

func open() -> void:
	if is_open or not is_in_combat:
		return
	is_open = true
	_saved_time_scale = Engine.time_scale
	Engine.time_scale = SLOWMO_SCALE
	_populate()
	panel.show()

func close() -> void:
	if not is_open:
		return
	is_open = false
	Engine.time_scale = _saved_time_scale
	panel.hide()

func _populate() -> void:
	_populate_abilities()
	_populate_persuasion()
	_populate_items()

func _populate_abilities() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var ability_comp = player.get_node_or_null("AbilityComponent") as AbilityComponent
	if not ability_comp:
		ability_comp = player.get_node_or_null("PlayerCombatComponent/AbilityComponent") as AbilityComponent
	if not ability_comp:
		return
	
	for child in ability_container.get_children():
		child.queue_free()
	
	var abilities = ability_comp.get_unlocked_abilities()
	for i in abilities.size():
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(140, 36)
		ability_container.add_child(btn)
		
		var ability = abilities[i]
		var slot_idx = ability_comp.find_slot_index(ability)
		var can_cast = slot_idx >= 0 and ability_comp.can_cast_ability(slot_idx)
		
		btn.text = ability.ability_name
		btn.disabled = not can_cast
		if can_cast:
			var idx = slot_idx
			btn.pressed.connect(func(): _on_ability_picked(idx, ability), CONNECT_ONE_SHOT)

func _populate_persuasion() -> void:
	for child in persuasion_container.get_children():
		child.queue_free()
	var actions = ["Convince", "Threaten", "Understand"]
	for i in actions.size():
		var btn = _get_or_create_button(persuasion_container, i)
		btn.text = actions[i]
		var action_name = actions[i]
		btn.pressed.connect(func(): _on_persuasion_picked(action_name), CONNECT_ONE_SHOT)

func _populate_items() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var inv = player.get_node_or_null("InventoryComponent")
	if not inv:
		return
	for child in item_container.get_children():
		child.queue_free()
	var slot = 0
	for i in inv.max_slots:
		var data = inv.get_item_at_slot(i)
		if data and data.item and data.item.item_type == 0:
			var btn = _get_or_create_button(item_container, slot)
			btn.text = "%s x%d" % [data.item.name, data.quantity]
			var idx = i
			btn.pressed.connect(func(): _on_item_picked(idx), CONNECT_ONE_SHOT)
			slot += 1

func _on_ability_picked(slot_index: int, ability: AbilityResource) -> void:
	action_selected.emit("ability", {"slot_index": slot_index, "ability": ability})
	close()

func _on_persuasion_picked(action: String) -> void:
	action_selected.emit("persuasion", {"action": action})
	close()

func _on_item_picked(slot_index: int) -> void:
	action_selected.emit("item", {"slot_index": slot_index})
	close()

func _on_hotkey_pressed(_slot_index: int) -> void:
	if is_open:
		close()

func _get_or_create_button(container: Container, index: int) -> Button:
	if index < container.get_child_count():
		return container.get_child(index) as Button
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(100, 40)
	container.add_child(btn)
	return btn

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_combat_menu"):
		if is_open:
			close()
		elif is_in_combat:
			open()
		get_viewport().set_input_as_handled()
