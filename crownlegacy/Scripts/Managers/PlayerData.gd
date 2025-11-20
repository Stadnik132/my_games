# PlayerData.gd
extends Node

# Базовые параметры персонажа
var player_name: String = "Клаус"  # Имя главного персонажа
var health: int = 100              # Текущее здоровье
var max_health: int = 100          # Максимальное здоровье
var attack_power: int = 105         # Сила атаки для боя
var defense_power: int = 5         # Защита от урона
var initiative: int = 10           # Инициатива для очереди ходов

# Системы инвентаря и способностей
var unlocked_abilities: Array = []  # Массив разблокированных умений
var inventory: Array = []           # Массив предметов в инвентаре

# Системы прогресса и репутации
var story_flags: Dictionary = {}    # Флаги сюжета для отслеживания прогресса
var reputation: Dictionary = {      # Репутация с фракциями
	"church": 0,      # Отношения с церковью
	"nobles": 0,      # Отношения с дворянами  
	"commoners": 0    # Отношения с простолюдинами
}

func _ready() -> void:
	print("PlayerData загружен! Игрок: ", player_name)

# Изменяет количество здоровья на указанное значение
func change_health(amount: int) -> void:
	health += amount  # Увеличиваем или уменьшаем здоровье
	health = clamp(health, 0, max_health)  # Ограничиваем между 0 и максимумом
	print("Здоровье изменено на ", amount, ". Текущее здоровье: ", health)

# Возвращает инициативу персонажа
func get_initiative() -> int:
	return initiative  # TODO: Рассчитывать на основе характеристик

# Разблокирует новую способность
func unlock_ability(ability_name: String) -> void:
	if not ability_name in unlocked_abilities:  # Проверяем нет ли уже способности
		unlocked_abilities.append(ability_name)  # Добавляем в массив
		print("Умение разблокировано: ", ability_name)

# Добавляет предмет в инвентарь
func add_item(item_name: String) -> void:
	inventory.append(item_name)  # Добавляем предмет в массив
	print("Предмет добавлен: ", item_name)

# Устанавливает флаг сюжета
func set_story_flag(flag_name: String, value: bool = true) -> void:
	story_flags[flag_name] = value  # Записываем флаг в словарь
	print("Флаг сюжета установлен: ", flag_name, " = ", value)

# Изменяет репутацию с фракцией
func change_reputation(faction: String, amount: int) -> void:
	if faction in reputation:  # Проверяем существует ли фракция
		reputation[faction] += amount  # Изменяем репутацию
		print("Репутация ", faction, " изменена на ", amount, ". Теперь: ", reputation[faction])
	else:
		print("Ошибка: фракция ", faction, " не найдена!")
