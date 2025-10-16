# PersuadeAction.gd

extends BattleAction
class_name PersuadeAction

func _init():
	action_name = "Убедить"
	sync_required = 50     # Требует высокого доверия
	sync_change = 5        # Повышает доверие при успехе
	refusal_penalty = -10  # Штраф за отказ пытаться убедить

func execute(caster, target) -> bool:
	# Временно выводим сообщение
	# ПОЗЖЕ добавим логику убеждения (альтернатива бою)
	print(caster.unit_name + " пытается убедить противника!")
	return true
