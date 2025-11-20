# RelationshipManager.gd
extends Node

# Сигналы для связи с UI и другими системами
signal trust_changed(new_value)        # Изменение уровня доверия
signal will_power_changed(new_value)   # Изменение количества Воли Короля

# Диапазоны уровней доверия для текстовых статусов
const TRUST_RANGES = {
	"НЕНАВИСТЬ": -100,
	"НЕПРИЯЗНЬ": -50, 
	"СКЕПТИЦИЗМ": -20,
	"НЕЙТРАЛЬНО": 20,
	"ДОВЕРИЕ": 50,
	"ПОДЧИНЕНИЕ": 80
}

# Основные параметры системы отношений
var sync_level: int = 100              # Уровень синхронизации (-100 до +100)
var will_power: int = 3                # Текущее количество Воли Короля

func _ready() -> void:
	# Вывод информации о загрузке для отладки
	print("RelationshipManager загружен! Доверие: ", sync_level, " Воля Короля: ", will_power)

# Проверяет можно ли использовать принуждение
func can_force_action() -> bool:
	return will_power > 0  # Возвращает true если есть хотя бы 1 единица Воли

# Основная функция использования Воли Короля
func use_will() -> bool:
	if will_power > 0:  # Проверяем есть ли Воля для использования
		will_power -= 1  # Уменьшаем количество Воли на 1
		emit_signal("will_power_changed", will_power)  # Сообщаем об изменении
		print("Воля использована. Осталось: ", will_power)
		return true  # Успешно использовали
	else:
		print("Нет Воли для использования!")
		return false  # Не удалось использовать

# Выполняет принуждение с использованием Воли Короля
func force_action() -> bool:
	if use_will():  # Пытаемся использовать Волю
		change_trust(-25)  # При успешном принуждении уменьшаем доверие
		print("Принуждение Волей! Доверие уменьшено.")
		return true
	else:
		return false  # Принуждение невозможно

# Добавляет указанное количество Воли Короля
func add_will(amount: int) -> void:
	will_power += amount  # Увеличиваем количество Воли
	emit_signal("will_power_changed", will_power)  # Сообщаем об изменении
	print("Воля добавлена: ", amount, ". Теперь: ", will_power)

# Изменяет уровень доверия на указанное количество
func change_trust(amount: int) -> void:
	sync_level += amount  # Изменяем текущее значение доверия
	sync_level = clamp(sync_level, -100, 100)  # Ограничиваем значение в диапазоне
	emit_signal("trust_changed", sync_level)  # Сообщаем об изменении
	print("Доверие изменено на: ", amount, ". Текущее: ", sync_level)

# Возвращает текстовое описание текущего уровня доверия
func get_trust_status() -> String:
	if sync_level <= TRUST_RANGES["НЕНАВИСТЬ"]:
		return "Ненависть"
	elif sync_level <= TRUST_RANGES["НЕПРИЯЗНЬ"]:
		return "Неприязнь" 
	elif sync_level < TRUST_RANGES["НЕЙТРАЛЬНО"]:
		return "Скептицизм"
	elif sync_level < TRUST_RANGES["ДОВЕРИЕ"]:
		return "Нейтрально"
	elif sync_level <= TRUST_RANGES["ПОДЧИНЕНИЕ"]:
		return "Доверие"
	else:
		return "Подчинение"

# Вспомогательные функции для внешних систем
func get_trust_level() -> int:
	return sync_level  # Возвращает текущий уровень доверия

func get_will_power() -> int:
	return will_power  # Возвращает текущее количество Воли Короля

func has_enough_trust(required_trust: int) -> bool:
	return sync_level >= required_trust  # Проверяет достаточно ли доверия для действия
