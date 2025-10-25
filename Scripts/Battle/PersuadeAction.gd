extends BattleAction
class_name PersuadeAction

func _init():
	action_name = "Убедить"
	sync_required = 50
	sync_change = 5
	refusal_penalty = -10

func execute(caster: BattleUnitVisual, _target: BattleUnitVisual) -> bool:
	print(caster.unit_data.unit_name + " пытается убедить противника!")
	return true
