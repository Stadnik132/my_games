class_name PlayerCombatHUD extends CanvasLayer

@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/HP/ProgressBar
@onready var hp_label: Label = $MarginContainer/VBoxContainer/HP/Label
@onready var mp_bar: ProgressBar = $MarginContainer/VBoxContainer/MP/ProgressBar
@onready var mp_label: Label = $MarginContainer/VBoxContainer/MP/Label
@onready var st_bar: ProgressBar = $MarginContainer/VBoxContainer/Stamina/ProgressBar
@onready var st_label: Label = $MarginContainer/VBoxContainer/Stamina/Label
@onready var ability_slots: Array = [
	$MarginContainer/VBoxContainer/Abilities/Slot0,
	$MarginContainer/VBoxContainer/Abilities/Slot1,
	$MarginContainer/VBoxContainer/Abilities/Slot2,
	$MarginContainer/VBoxContainer/Abilities/Slot3
]

var _player: Entity
var _health: HealthComponent
var _mana: ResourceComponent
var _stamina: ResourceComponent

func _ready() -> void:
	hide()
	EventBus.Combat.started.connect(_on_combat_started)
	EventBus.Combat.ended.connect(_on_combat_ended)
	EventBus.UI.hud_update_required.connect(_on_hud_update)
	print_debug("PlayerCombatHUD: _ready(), hidden")

func _on_combat_started(_enemies: Array = []) -> void:
	print_debug("PlayerCombatHUD: combat started signal received")
	show()
	_find_player()

func _on_combat_ended(_victory: bool) -> void:
	hide()

func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Entity
	if not _player:
		push_warning("PlayerCombatHUD: player not found in group 'player'")
		return
	print_debug("PlayerCombatHUD: player found, hp=", _player.health_component.get_current_health() if _player.health_component else "null")
	_health = _player.health_component
	_mana = _player.mana_component
	_stamina = _player.stamina_component
	if _health and not _health.health_changed.is_connected(_update_hp):
		_health.health_changed.connect(_update_hp)
	if _mana and not _mana.changed.is_connected(_update_mp):
		_mana.changed.connect(_update_mp)
	if _stamina and not _stamina.changed.is_connected(_update_st):
		_stamina.changed.connect(_update_st)
	_update_all()

func _update_hp(new_val: int, _old: int, max_val: int) -> void:
	hp_bar.max_value = max_val
	hp_bar.value = new_val
	hp_label.text = "%d/%d" % [new_val, max_val]

func _update_mp(new_val: int, _old: int, max_val: int) -> void:
	mp_bar.max_value = max_val
	mp_bar.value = new_val
	mp_label.text = "%d/%d" % [new_val, max_val]

func _update_st(new_val: int, _old: int, max_val: int) -> void:
	st_bar.max_value = max_val
	st_bar.value = new_val
	st_label.text = "%d/%d" % [new_val, max_val]

func _update_all() -> void:
	if _health:
		_update_hp(_health.get_current_health(), 0, _health.get_max_health())
	if _mana:
		_update_mp(_mana.get_current(), 0, _mana.get_max())
	if _stamina:
		_update_st(_stamina.get_current(), 0, _stamina.get_max())

func _on_hud_update(data: Dictionary) -> void:
	var slot_index = data.get("slot_index", -1)
	if slot_index < 0 or slot_index >= ability_slots.size():
		return
	var slot = ability_slots[slot_index]
	var overlay = slot.get_node_or_null("CooldownOverlay")
	if overlay:
		overlay.visible = data.get("on_cooldown", false)
		overlay.modulate.a = 1.0 - data.get("percentage", 0.0)
	var key_label = slot.get_node_or_null("KeyLabel")
	if key_label:
		key_label.text = str(slot_index + 1)
