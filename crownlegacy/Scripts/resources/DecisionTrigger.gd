extends Resource
class_name DecisionTrigger

# ==================== ТИПЫ ТРИГГЕРОВ ====================
enum TriggerType { TIME, HP }

# ==================== ЭКСПОРТ ====================
@export var trigger_type: TriggerType = TriggerType.HP
@export var value: float = 0.3  # секунды для TIME, процент для HP
@export var dialogue_timeline: String = ""
@export var one_shot: bool = true  # один раз за бой

func get_trigger_key() -> String:
	match trigger_type:
		TriggerType.TIME:
			return "time_" + str(value)
		TriggerType.HP:
			return "hp_" + str(value)
		_:
			return "unknown"
