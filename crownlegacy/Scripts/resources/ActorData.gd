extends EntityData
class_name ActorData

@export var display_name: String = "Actor"
@export var timeline_name: String = ""
@export var repeat_timeline_name: String = ""

@export var decision_triggers: Array[DecisionTrigger] = []

var dialogue_used: bool = false


func add_decision_trigger(trigger: DecisionTrigger) -> void:
	decision_triggers.append(trigger)


func remove_decision_trigger(trigger: DecisionTrigger) -> void:
	decision_triggers.erase(trigger)


func clear_decision_triggers() -> void:
	decision_triggers.clear()


func has_decision_triggers() -> bool:
	return not decision_triggers.is_empty()


func get_save_data() -> Dictionary:
	var data = super.get_save_data()
	data.merge({
		"display_name": display_name,
		"timeline_name": timeline_name,
		"repeat_timeline_name": repeat_timeline_name,
		"dialogue_used": dialogue_used,
		"decision_triggers": decision_triggers.map(func(t): return t.resource_path if t else "")
	})
	return data


func load_save_data(data: Dictionary) -> void:
	super.load_save_data(data)
	if data.has("display_name"): display_name = data.display_name
	if data.has("timeline_name"): timeline_name = data.timeline_name
	if data.has("repeat_timeline_name"): repeat_timeline_name = data.repeat_timeline_name
	if data.has("dialogue_used"): dialogue_used = data.dialogue_used
	if data.has("decision_triggers"):
		decision_triggers.clear()
		for path in data.decision_triggers:
			if path and ResourceLoader.exists(path):
				var trigger = load(path)
				if trigger is DecisionTrigger:
					decision_triggers.append(trigger)
