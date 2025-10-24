# BattleUnitData.gd
# Этот файл будет хранить ТОЛЬКО ДАННЫЕ о боевом юните
# Он не знает ничего о графике, сценах или отображении

# class_name позволяет использовать этот класс в других скриптах как тип
class_name BattleUnitData

# extends Resource означает что это "ресурс" - данные которые можно сохранять/загружать
extends Resource

# ОБЪЯВЛЯЕМ ПЕРЕМЕННЫЕ ДАННЫХ:
var unit_name: String      # Имя персонажа ("Алексей", "Страж")
var max_hp: int           # Максимальное здоровье
var current_hp: int       # Текущее здоровье  
var attack_power: int     # Сила атаки
var defense_power: int    # Сила защиты

# Функция настройки юнита
func setup_unit(new_name: String, hp: int, attack: int, defense: int):
	unit_name = new_name   # Сохраняем переданное имя
	max_hp = hp           # Сохраняем максимальное HP
	current_hp = hp       # Текущее HP = максимальному (полное здоровье)
	attack_power = attack # Сохраняем силу атаки
	defense_power = defense # Сохраняем силу защиты

# Функция получения урона
func take_damage(damage: int):
	current_hp -= damage  # Вычитаем урон из текущего HP
	current_hp = max(0, current_hp)  # Обеспечиваем что HP не станет меньше 0

# Функция проверки жив ли юнит
func is_alive() -> bool:
	return current_hp > 0  # Возвращает true если HP больше 0
