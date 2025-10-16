# AttackAction.gd

# Эта строка говорит что этот класс наследуется от BattleAction
extends BattleAction
class_name AttackAction

# Функция _init() автоматически вызывается при создании объекта
func _init():
	# Устанавливаем свойства унаследованные от BattleAction
	action_name = "Атака"
	sync_required = 30
	sync_change = -2
	refusal_penalty = -15

# Переопределяем функцию execute из родительского класса
func execute(caster, target) -> bool:
	# Вычисляем урон: сила атаки минус защита цели
	var damage = caster.attack_power - target.defense_power
	# Убеждаемся что урон не меньше 1
	damage = max(1, damage)
	# Наносим урон цели
	target.take_damage(damage)
	# Выводим сообщение в консоль
	print(caster.unit_name + " атакует " + target.unit_name + " на " + str(damage) + " урона!")
	# Возвращаем true - действие выполнено успешно
	return true
