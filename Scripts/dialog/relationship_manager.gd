# RelationshipManager.gd 
extends Node
# 1. Объявляем переменные для хранения данных sync_level(Уровень_синхронизации), Воля_Короля(King_will)
var sync_level: int = 0
var king_will: int = 3
# 2. Объявляем сигналы.
signal sync_level_changed(new_value)
signal king_will_changed(new_value)
# 3. Функция для изменения уровня синхронизации
func change_sync(amount: int):
	#Сначала рассчитываем новое значение
	var new_sync_value = sync_level + amount #для работы диапозона новая синхронизация = синхронизация + 
	# Ограничиваем его диапазон от -100 до 100 с помощью встроенной функции clamp()
	new_sync_value = clamp(new_sync_value, -100, 100)
		#Если значение действительно изменилось...
	if sync_level != new_sync_value:
		sync_level = new_sync_value #Если уров. синхронизации не равен новому, то уровень синхронизации будет равен новому(Записываем новое значение)
		# При True кричим сигнал, передавая новое значение.
		emit_signal("sync_level_changed", sync_level)
		print("Sync level is now: ", sync_level)

# 4. Функция для использования Воли короля.
func use_king_will() -> bool:
	#Проверяем, есть ли ресурс
	if king_will > 0:
		king_will -=1 # Уменьшаем количество на 1
		# Кричим сигнал об изменении воли
		emit_signal("king_will_changed", king_will)
		print("Kings's Will used. Remaining: ", king_will)
		return true # Возвращаем "True"
	else:
		print("Not enough King's Will!")
		return false # Возвращаем "False"
# 5. Функция дял востановления Воли Короля
func restore_king_will(amount: int):
	king_will += amount
	# Сигнал об изменении воли
	emit_signal("king_will_changed", king_will)
	print("King's Will restored. Total; ", king_will)
