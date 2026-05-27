extends EntityData
class_name ActorData

@export var display_name: String = "Actor"
@export var timeline_name: String = ""
@export var repeat_timeline_name: String = ""

var dialogue_used: bool = false


func get_save_data() -> Dictionary:
	var data = super.get_save_data()
	data.merge({
		"display_name": display_name,
		"timeline_name": timeline_name,
		"repeat_timeline_name": repeat_timeline_name,
		"dialogue_used": dialogue_used
	})
	return data


func load_save_data(data: Dictionary) -> void:
	super.load_save_data(data)
	if data.has("display_name"): display_name = data.display_name
	if data.has("timeline_name"): timeline_name = data.timeline_name
	if data.has("repeat_timeline_name"): repeat_timeline_name = data.repeat_timeline_name
	if data.has("dialogue_used"): dialogue_used = data.dialogue_used
