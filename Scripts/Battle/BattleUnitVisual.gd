# BattleUnitVisual.gd
# Этот скрипт теперь отвечает ТОЛЬКО за ОТОБРАЖЕНИЕ юнита в бою
# Он получает данные из BattleUnitData и показывает их на экране

extends Node2D

# Объявляем класс для работы с данными
class_name BattleUnitVisual

# Ссылка на ProgressBar для отображения HP
@onready var hp_bar: ProgressBar = $HPBar

# Ссылка на ДАННЫЕ юнита (теперь отдельный объект)
var unit_data: BattleUnitData

# Функция инициализации при создании юнита
func _ready():
	print("BattleUnitVisual готов! HP бар: ", hp_bar)

# Настройка визуального представления на основе данных
func setup_visual(data: BattleUnitData):
	unit_data = data  # Сохраняем ссылку на данные
	
	# Инициализируем HP бар если он существует в сцене
	if hp_bar:
		hp_bar.max_value = unit_data.max_hp    # Устанавливаем максимальное значение
		hp_bar.value = unit_data.current_hp    # Устанавливаем текущее значение
		print("HP бар инициализирован для: " + unit_data.unit_name)

# Обработка получения урона (теперь работает с данными)
func take_damage(damage: int):
	# Передаём урон в ДАННЫЕ
	unit_data.take_damage(damage)
	
	# Обновляем отображение HP бара
	if hp_bar:
		hp_bar.value = unit_data.current_hp  # Синхронизируем с данными
	
	print(unit_data.unit_name + " получает урон: " + str(damage) + ". Осталось HP: " + str(unit_data.current_hp))

# Проверка жив ли юнит (через данные)
func is_alive() -> bool:
	return unit_data.is_alive()

# Обновление визуального отображения (HP бар)
func update_display():
	if hp_bar and unit_data:
		hp_bar.max_value = unit_data.max_hp      # Обновляем максимум
		hp_bar.value = unit_data.current_hp      # Обновляем текущее значение
