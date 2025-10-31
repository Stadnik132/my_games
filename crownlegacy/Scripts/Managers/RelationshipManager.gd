#RelationshipManager.gd
extends Node #Наследуем от базового объекта Godot - Node

# Сигналы - Это способ общения между скриптами
# Когда доверие меняется, мы сообщаем всем, кто подписан на сигнал.
signal trust_changed(new_value) # Сигнал при изменении доверя (trust_changed - доверие изменено) (new_value - новое значение)
signal will_power_changed(new_value) # Сигнал при изменении воли (will_power_changed - изменится ли сила воли)

#Переменные для хранения основных данных
var sync_level: int = 0 # Уровень доверия между духом и Клаусом (от -100 до 100) (sync_level - уровень синхронизации)
var will_power: int = 3 # Текущее количество Воли Короля (Стартовое значени) (will_power - сила воли)

# Функция _ready() вызывается автоматически, когда этот объект появляется в игре.
func _ready() -> void:
	# Выводим сообщение в консоль для проверки ,что скрипт работает
	print("RelationshopManager Загружен! Довери: ", sync_level, " Воля Короля: ", will_power)

# Функция дял проверки можно ли принудить (Есть ли воля)
func can_force_action() -> bool:
	# Просто проверяем есть ли хотя бы 1 единица воли
	return will_power > 0
	
# Функция для принуждения с использованием Воли (в диалогах и бою)
func force_action() -> bool:
	# Используем существующую функцию use_will()
	if use_will():
		# Дополнительно уменьшаем доверие за принуждение
		change_trust(-25)
		print("Принуждение волей! Доверие уменьшилось")
		return true
	else:
		return false
		
# Функция для изменения уровня доверия (change_trust - изменение доверия) (amount - сумма)
func change_trust(amount: int) -> void:
	# Складываем текущее доверие с переданным значением
	sync_level += amount
	# Ограничиваем значение между -100 и 100 с помощью clamp(Чтобы не ушло за пределы)
	sync_level = clamp(sync_level, -100, 100)
	# Сигналим все, кто подписан на trust_changed.
	emit_signal("trust_changed", sync_level)
	# выводим в консоль отладку
	print("Доверие изменено на: ", amount, ". Текущее: ", sync_level)
	
# Функция для использования Воли Короля (use_will - использовать волю)
func use_will() -> bool:
	# Проверяем есть ли ещё воля для использования
	if will_power > 0:
		# Уменьшам количество воли на 1
		will_power -= 1
		 # Сообщаем об этом изменении воли через сигнал
		emit_signal("will_power_changed", will_power)
		# Выводим отладку
		print("Воля использована. Осталось: ", will_power)
		return true # Возвращаем true - действите успешно выполнено
	else:
		# Если воли нот, выводим сообщение и возвращаем false
		print("Нет воли для использования!")
		return false
		
# Функция для добавления воли (Сделаем позже)
func add_will(amount: int) -> void:
	# Увеливичиваем кол-во воли
	will_power += amount
	# Сообщаем о изменении
	emit_signal("will_power_changed", will_power)
	# Выводим отладку
	print("Воля добавлена", amount, "Теперь: ", will_power)
	
# Функция для получения текстового статуса отношений (get_trust_status - получить доверительный статус)
func get_trust_status() -> String:
	# Проверяем уровень доверия и возвращаем соответсвующий текст
	if sync_level <= -50:
		return "Ненависть"
	elif sync_level <= -20:
		return "Неприязнь"
	elif sync_level < 20:
		return "Скептицизм"
	elif sync_level < 50:
		return "Нейтрально"
	elif sync_level <= 80:
		return "Доверие"
	else:
		return "Подчинение"
