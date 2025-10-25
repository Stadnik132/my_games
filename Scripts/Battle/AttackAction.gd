extends BattleAction
class_name AttackAction

func _init():
	action_name = "Атака"
	sync_required = -10
	sync_change = -10
	refusal_penalty = -15

func execute(caster: BattleUnitVisual, target: BattleUnitVisual) -> bool:
	var damage = caster.unit_data.attack_power - target.unit_data.defense_power
	damage = max(1, damage)
	target.take_damage(damage)
	print(caster.unit_data.unit_name + " атакует " + target.unit_data.unit_name + " на " + str(damage) + " урона!")
	return true
