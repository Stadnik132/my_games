extends BattleAction
class_name DefendAction

func _init():
	action_name = "Защита"
	sync_required = 0
	sync_change = 0
	refusal_penalty = -5

func execute(caster: BattleUnitVisual, _target: BattleUnitVisual) -> bool:
	print(caster.unit_data.unit_name + " защищается!")
	return true
