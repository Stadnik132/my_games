# BattleAction.gd - скрипт класса для показателей битвы
class_name BattleAction
extends Resource

# Базовый класс для всех действий в бою. Наследуется от Resource для возможности
# сохранения/загрузки и использования в редакторе Godot.

# Основные свойства действия
var action_name: String        # Отображаемое название действия ("Атака", "Защита" и т.д.)
var sync_required: int = 0     # Требуемый уровень доверия для выполнения действия
var sync_change: int = 0       # Изменение доверия после выполнения (+/-)
var refusal_penalty: int = -10 # Штраф к доверию при отказе выполнить действие

# Базовая функция выполнения действия (переопределяется в дочерних классах)
func execute(caster: BattleUnitData, target: BattleUnitData) -> bool:
	print("Выполняется действие: " + action_name)
	return true  # Возвращает true если действие выполнено успешно
