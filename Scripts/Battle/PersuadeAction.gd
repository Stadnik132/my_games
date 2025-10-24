# PersuadeAction.gd - скрипт убеждения в бою
extends BattleAction
class_name PersuadeAction

# Конкретная реализация действия "Убедить" - альтернатива насилию

func _init():
	# Устанавливаем параметры для убеждения
	action_name = "Убедить"
	sync_required = 50    # Требуется высокий уровень доверия
	sync_change = 5       # Повышение доверия при успешном убеждении
	refusal_penalty = -10 # Штраф за отказ пытаться убедить

# Реализация логики убеждения (временная заглушка)
func execute(caster: BattleUnitData, target: BattleUnitData) -> bool:
	# ВРЕМЕННАЯ РЕАЛИЗАЦИЯ - позже добавим реальную механику убеждения
	# (например, шанс завершить бой мирно или ослабить врага)
	print(caster.unit_name + " пытается убедить противника!")
	return true
