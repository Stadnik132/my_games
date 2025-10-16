# DefendAction.gd

# Наследуемся от BattleAction - получаем все его свойства
extends BattleAction
class_name DefendAction

# Конструктор - вызывается при создании объекта
func _init():
	# Устанавливаем значения унаследованных свойств
	action_name = "Защита"
	sync_required = 0 # Защита всегда доступна
	sync_change = 0  # Доверие не меняется
	refusal_penalty = -5 # Меньший штраф за отказ защищаться
	
# Переопределяем функцию выполнения действия
func execute(caster, target) -> bool:
	# Временно просто выводим сообщение
	# ПОЗЖЕ добавим реальную логику защиты
	print(caster.unit_name + " защищается!")
	# Возвращаем true - действие выполнено
	return true
