# PlayerData.gd
extends Node
# Автозагружаемый скрипт для хранения постоянных данных игрока

# Базовые параметры персонажа (характеристики)
var player_name: String = "Клаус" # Имя персонажа
var health: int = 100 # Текущее здоровье
var max_health: int = 100 # Макс. здоровье персонажа
var attack_power: int = 10 # Сила атаки (Для боя)
var defense_power: int = 5 # Защита (Для боя)

# Списки умений и предметов (Инвентарь и способности) (Array - массив) Array = [] — УПОРЯДОЧЕННЫЙ список (Обращаемся по ИНДЕКСУ (порядковому номеру))
var unlocked_abilities: Array = [] # Массив открытых умений (unlocked_avilities - разблокированные умения)
var inventory: Array = [] # Массив предметов в (inventory - инвентарь)

# Прогресс и репутация (Dictionary - словарь) НЕУПОРЯДОЧЕННЫЙ набор пар «КЛЮЧ-ЗНАЧЕНИЕ» (Обращаемся по КЛЮЧУ (названию))
var story_flags: Dictionary = {} # Флаги сюжета
var reputation: Dictionary = { # Репутация с флагами (Придумать назначение)
	"church": 0, # Отношение с church - церковь
	"nobles": 0, # Отношение с nobles - Дворянами
	"commoners": 0, # Отношение с commoners - простолюдинами
}

# Функция _ready() выполняется автомат. при загрузке скрипта
func _ready() -> void:
	print("PlayerData загружен! Игрок: ", player_name)
	
# Функция для изменения здоровья В бою, лечении (позже при поднятии уровня или его аналога)
func change_health(amount: int) -> void:
	# Увеличиваем или уменьшаем здоровье на указанное колличество
	health += amount
	# Ограничиваем здоровье между 0 и максимумом с помощью clamp
	health = clamp(health, 0, max_health)
	print("Здоровье изменено на ", amount, " Текущее здоровье: ", health)
	
# Функция для добовления умения (Будет вызываться при прогрессе) (unlock_ability - разблокированные способности)
func unlock_ability(ability_name: String) -> void:
	# Проверяем, нет ли уже этого умения в списке
	if not ability_name in unlocked_abilities:
		# Добавляем умение в массив
		unlocked_abilities.append(ability_name)
		print("Умение разблокировано: ", ability_name)

# Функция для добавления предмета в инвентарь
func add_item(item_name: String) -> void:
	# Добавляем предмет в массив инвентаря.
	inventory.append(item_name)
	print("Предмет добавлент: ", item_name)
	
# функция для установки флага сюжета (Влияет на диалог и события) (set_story_flag - установить флаг истории)
func set_story_flag(flag_name: String, value: bool = true) -> void:
	# Записываем флаг в словарь story_flags
	story_flags[flag_name] = value
	print("Флаг сюжета установлен: ", flag_name, " = ", value)
	
# Функция для изменения репутации с фракцией
func chfnge_reputation(faction: String, amount: int) -> void:
	# Проверяем существует ли такая фракция в лсловаре
	if faction in reputation:
		# Изменяем репутацию на указанное колличество
		reputation[faction] +- amount
		print("Репутация ", faction, " изменена на ", amount, ". Теперь: ", reputation[faction])
	else:
		# Если фракции нет - выводим ошибку
		print("Ошибка: фракция ", faction, " не найдена!")
