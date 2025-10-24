# DefendAction.gd - скрипт защиты в бою
extends BattleAction
class_name DefendAction

# Конкретная реализация действия "Защита"

func _init():
	# Устанавливаем параметры для защиты
	action_name = "Защита"
	sync_required = 0     # Защита всегда доступна (не требует доверия)
	sync_change = 0       # Доверие не меняется при защите
	refusal_penalty = -5  # Небольшой штраф за отказ защищаться

# Реализация логики защиты (временная заглушка)
func execute(caster: BattleUnitVisual, target: BattleUnitVisual) -> bool:
	# ВРЕМЕННАЯ РЕАЛИЗАЦИЯ - позже добавим реальную механику защиты
	# (например, временное увеличение защиты или поглощение урона)
	print(caster.unit_name + " защищается!")
	return true
