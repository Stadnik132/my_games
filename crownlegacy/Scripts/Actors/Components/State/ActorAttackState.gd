class_name ActorAttackState extends ActorCombatState

@export var attack_delay: float = 0.3      # Задержка перед ударом
@export var attack_cooldown: float = 1.5   # Время до следующей атаки
@export var damage: int = 10               # Урон от атаки
@export var hitbox_active_time: float = 0.1 # Как долго хитбокс активен

@export var hitbox_offset_right: Vector2 = Vector2(30, 0)
@export var hitbox_offset_left: Vector2 = Vector2(-30, 0)
@export var hitbox_offset_up: Vector2 = Vector2(0, -30)
@export var hitbox_offset_down: Vector2 = Vector2(0, 30)

# Диагональные смещения (можно оставить как комбинацию основных)
# Или задать отдельно для более точного позиционирования
@export var hitbox_offset_up_right: Vector2 = Vector2(25, -25)
@export var hitbox_offset_up_left: Vector2 = Vector2(-25, -25)
@export var hitbox_offset_down_right: Vector2 = Vector2(25, 25)
@export var hitbox_offset_down_left: Vector2 = Vector2(-25, 25)

var state_timer: float = 0.0
var has_attacked: bool = false
var hitbox: Hitbox
var hitbox_original_position: Vector2  # Запоминаем исходное положение

func enter() -> void:
	print_debug("AttackState: ENTER")
	state_timer = 0.0
	has_attacked = false
	actor.velocity = Vector2.ZERO
	
	# Находим хитбокс
	_find_hitbox()

func _find_hitbox() -> void:
	# Ищем хитбокс у актора
	hitbox = actor.get_node_or_null("Hitbox")
	if not hitbox:
		# Если не нашли как прямой потомок, ищем среди детей
		for child in actor.get_children():
			if child is Hitbox:
				hitbox = child
				break
	
	if hitbox:
		# Запоминаем исходное положение хитбокса
		hitbox_original_position = hitbox.position
		# Убеждаемся, что хитбокс выключен
		hitbox.monitoring = false
		print_debug("AttackState: хитбокс найден")
	else:
		print_debug("AttackState: ХИТБОКС НЕ НАЙДЕН!")

func _update_hitbox_position() -> void:
	if not hitbox:
		return
	
	var facing = _get_facing_direction()
	
	# Смещаем хитбокс в зависимости от направления
	match facing:
		"right":
			hitbox.position = hitbox_original_position + hitbox_offset_right
		"left":
			hitbox.position = hitbox_original_position + hitbox_offset_left
		"up":
			hitbox.position = hitbox_original_position + hitbox_offset_up
		"down":
			hitbox.position = hitbox_original_position + hitbox_offset_down
		"up_right":
			hitbox.position = hitbox_original_position + hitbox_offset_up + hitbox_offset_right
		"up_left":
			hitbox.position = hitbox_original_position + hitbox_offset_up + hitbox_offset_left
		"down_right":
			hitbox.position = hitbox_original_position + hitbox_offset_down + hitbox_offset_right
		"down_left":
			hitbox.position = hitbox_original_position + hitbox_offset_down + hitbox_offset_left
		_:
			hitbox.position = hitbox_original_position + hitbox_offset_down



func _get_facing_direction() -> String:
	# Используем метод Actor
	if actor and actor.has_method("get_facing_direction"):
		var dir = actor.get_facing_direction()
		return dir
	return "down"
	
	# Fallback: определяем по скорости
	if actor.velocity.length() > 10:
		var vel = actor.velocity.normalized()
		var angle = rad_to_deg(vel.angle())
		if angle < 0:
			angle += 360
		
		if angle >= 337.5 or angle < 22.5:
			return "right"
		elif angle >= 22.5 and angle < 67.5:
			return "down_right"
		elif angle >= 67.5 and angle < 112.5:
			return "down"
		elif angle >= 112.5 and angle < 157.5:
			return "down_left"
		elif angle >= 157.5 and angle < 202.5:
			return "left"
		elif angle >= 202.5 and angle < 247.5:
			return "up_left"
		elif angle >= 247.5 and angle < 292.5:
			return "up"
		elif angle >= 292.5 and angle < 337.5:
			return "up_right"
	
	return "down"

func process(delta: float) -> void:
	state_timer += delta
	
	# Постоянно обновляем позицию хитбокса (на случай, если враг повернулся)
	_update_hitbox_position()
	
	if not has_attacked and state_timer >= attack_delay:
		_perform_attack()
		has_attacked = true
	
	if state_timer >= attack_cooldown:
		_finish_attack()

func _perform_attack() -> void:
	print_debug("AttackState: АТАКА! Урон=", damage)
	
	if actor.sprite:
		actor.sprite.modulate = Color.RED
	
	_update_hitbox_position()
	
	if hitbox:
		# Проверяем, есть ли DamageData
		print_debug("AttackState: создаю DamageData")
		var damage_data = DamageData.new()
		damage_data.amount = damage
		damage_data.damage_type = DamageData.DamageType.PHYSICAL
		
		print_debug("AttackState: устанавливаю DamageData в хитбокс")
		hitbox.set_damage_data(damage_data)
		
		print_debug("AttackState: включаю хитбокс, позиция=", hitbox.position)
		hitbox.monitoring = true
		
		# Проверяем, есть ли кто-то в хитбоксе прямо сейчас
		var overlapping = hitbox.get_overlapping_areas()
		print_debug("AttackState: областей в хитбоксе: ", overlapping.size())
		for area in overlapping:
			print_debug("  - ", area.name, " (", area.get_class(), ")")
		
		var timer = get_tree().create_timer(hitbox_active_time)
		timer.timeout.connect(_disable_hitbox)
	else:
		print_debug("AttackState: ХИТБОКС ОТСУТСТВУЕТ!")
		if actor.sprite:
			actor.sprite.modulate = Color.WHITE

func _disable_hitbox() -> void:
	if hitbox and is_instance_valid(hitbox):
		hitbox.monitoring = false
		print_debug("AttackState: хитбокс ВЫКЛЮЧЁН")
	
	# Возвращаем цвет обратно
	if actor.sprite:
		actor.sprite.modulate = Color.WHITE

func _finish_attack() -> void:
	print_debug("AttackState: атака завершена")
	
	# Убеждаемся, что хитбокс выключен
	if hitbox:
		hitbox.monitoring = false
		hitbox.position = hitbox_original_position
	
	if brain:
		# НЕ ЗАПРАШИВАЕМ ATTACK, если уже в нём
		# Вместо этого проверяем, что делать дальше
		if brain.should_attack():
			# Мы уже в ATTACK, просто начинаем новую атаку
			print_debug("AttackState: начинаю новую атаку")
			# Сбрасываем таймеры и начинаем заново
			state_timer = 0.0
			has_attacked = false
			# НЕ ИСПУСКАЕМ transition_requested!
		elif brain.should_move_to_player():
			print_debug("AttackState: переход в MOVE")
			transition_requested.emit("MOVE")
		else:
			print_debug("AttackState: переход в IDLE")
			transition_requested.emit("IDLE")

func exit() -> void:
	# При выходе из состояния обязательно выключаем хитбокс
	if hitbox:
		hitbox.monitoring = false
		# Возвращаем хитбокс в исходное положение
		hitbox.position = hitbox_original_position
	if actor.sprite:
		actor.sprite.modulate = Color.WHITE
