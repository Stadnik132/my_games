extends Area2D
class_name Hitbox

# Данные урона (заполняются при создании)
var damage_data: DamageData
var direction: Vector2 = Vector2.ZERO  # для отбрасывания

# Время жизни (уничтожится автоматически)
var lifetime: float = 0.1

func _ready():
	# Ждём один кадр, чтобы damage_data точно был установлен
	await get_tree().process_frame
	_update_layers_from_source()
	
	# Подключаем сигнал входа в область
	area_entered.connect(_on_area_entered)
	
	# Автоуничтожение
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _update_layers_from_source():
	"""Настраивает слои коллизий на основе создателя (damage_data.source)"""
	
	# Получаем создателя из damage_data
	var source = damage_data.source if damage_data else null
	
	if not source:
		collision_layer = 0
		collision_mask = 0
		print("Hitbox: нет source, слои = 0")
		return
	
	# Если создатель игрок → хитбокс в слое 4 (бьёт врагов)
	if source.is_in_group("player"):
		collision_layer = 4
		collision_mask = 4
		print("Hitbox: создан игроком, слой 4")
	
	# Если создатель враг → хитбокс в слое 2 (бьёт игрока)
	elif source.is_in_group("enemies"):
		collision_layer = 2
		collision_mask = 2
		print("Hitbox: создан врагом, слой 2")
	
	else:
		collision_layer = 0
		collision_mask = 0
		print("Hitbox: неизвестный создатель, слои = 0")

# Метод, который вызывает Hurtbox
func get_damage_data() -> DamageData:
	return damage_data

# Установка данных урона (вызывается тем, кто создаёт хитбокс)
func set_damage_data(data: DamageData) -> void:
	damage_data = data

# Чтобы хитбокс не бил несколько раз
func _on_area_entered(area: Area2D):
	if area is Hurtbox:
		# Отключаем мониторинг после первого попадания
		set_deferred("monitoring", false)
		
		# Можно оставить для визуала, потом удалится по таймеру
