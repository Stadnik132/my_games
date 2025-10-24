# AttackAction.gd - скрипт атаки в бою
extends BattleAction
class_name AttackAction

# Конкретная реализация действия "Атака"

func _init():
	# Устанавливаем параметры для атаки при создании объекта
	action_name = "Атака"
	sync_required = -10    # Требуется умеренный уровень доверия
	sync_change = -10      # Небольшой штраф к доверию (агрессивное действие)
	refusal_penalty = -15 # Значительный штраф при отказе атаковать

# Реализация логики атаки
func execute(caster: BattleUnitData, target: BattleUnitData) -> bool:
	# Расчет урона: атака атакующего минус защита цели
	var damage = caster.attack_power - target.defense_power
	damage = max(1, damage)  # Гарантируем минимальный урон = 1
	
	# Применяем урон к цели
	target.take_damage(damage)
	
	print(caster.unit_name + " атакует " + target.unit_name + " на " + str(damage) + " урона!")
	return true
