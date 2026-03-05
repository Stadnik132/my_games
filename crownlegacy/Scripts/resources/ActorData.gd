extends EntityData
class_name ActorData

# ==================== ОСНОВНЫЕ ДАННЫЕ ====================
@export var display_name: String = "Actor"
@export var timeline_name: String = "guard_encounter"  # первый диалог
@export var repeat_timeline_name: String = ""          # диалог при повторе (если пусто - использовать первый)

# ==================== ЗАЩИТА ====================
@export var physical_defense: int = 5
@export var magical_defense: int = 5

# ==================== СПОСОБНОСТИ ====================
# ID способностей из JSON для слотов актора
@export var ability_slot_assignments: Array[String] = []

# ==================== ТОЧКИ РЕШЕНИЯ ====================
# Триггеры, которые активируются в бою
@export var decision_triggers: Array[DecisionTrigger] = []

# ==================== СОСТОЯНИЕ (НЕ ЭКСПОРТИРУЕТСЯ) ====================
# Флаг для отслеживания, был ли уже использован диалог
var dialogue_used: bool = false

# ==================== МЕТОДЫ ДЛЯ РАБОТЫ С ТРИГГЕРАМИ ====================
func add_decision_trigger(trigger: DecisionTrigger) -> void:
	"""Добавить новый триггер (например, из кода)"""
	decision_triggers.append(trigger)

func remove_decision_trigger(trigger: DecisionTrigger) -> void:
	"""Удалить триггер"""
	decision_triggers.erase(trigger)

func clear_decision_triggers() -> void:
	"""Очистить все триггеры"""
	decision_triggers.clear()

func has_decision_triggers() -> bool:
	"""Есть ли хотя бы один триггер"""
	return not decision_triggers.is_empty()

# ==================== ПЕРЕОПРЕДЕЛЁННЫЕ МЕТОДЫ СОХРАНЕНИЯ ====================
func get_save_data() -> Dictionary:
	var data = super.get_save_data()
	data.merge({
		"display_name": display_name,
		"timeline_name": timeline_name,
		"repeat_timeline_name": repeat_timeline_name,
		"physical_defense": physical_defense,
		"magical_defense": magical_defense,
		"ability_slot_assignments": ability_slot_assignments.duplicate(),
		"dialogue_used": dialogue_used,
		# Триггеры сохраняем как ссылки на ресурсы (они сами сохраняются отдельно)
		"decision_triggers": decision_triggers.map(func(t): return t.resource_path if t else "")
	})
	return data

func load_save_data(data: Dictionary) -> void:
	super.load_save_data(data)
	
	if data.has("display_name"):
		display_name = data.display_name
	if data.has("timeline_name"):
		timeline_name = data.timeline_name
	if data.has("repeat_timeline_name"):
		repeat_timeline_name = data.repeat_timeline_name
	if data.has("physical_defense"):
		physical_defense = data.physical_defense
	if data.has("magical_defense"):
		magical_defense = data.magical_defense
	if data.has("ability_slot_assignments"):
		ability_slot_assignments = data.ability_slot_assignments.duplicate()
	if data.has("dialogue_used"):
		dialogue_used = data.dialogue_used
	
	# Загружаем триггеры по resource_path
	if data.has("decision_triggers"):
		decision_triggers.clear()
		for path in data.decision_triggers:
			if path and ResourceLoader.exists(path):
				var trigger = load(path)
				if trigger is DecisionTrigger:
					decision_triggers.append(trigger)
