extends CharacterBody2D
class_name Entity

# ==================== ССЫЛКИ НА КОМПОНЕНТЫ ====================
var health_component: HealthComponent
var mana_component: ResourceComponent
var stamina_component: ResourceComponent
var progression_component: ProgressionComponent
var ability_component: AbilityComponent
var hurtbox: Hurtbox


# ==================== СОСТОЯНИЕ ====================
var is_dead: bool = false
var movement_locked: bool = false
var interaction_locked: bool = false

var _flash_tween: Tween
var _death_tween: Tween
var _stun_tween: Tween

# ==================== ВСТРОЕННЫЕ МЕТОДЫ ====================
func _ready() -> void:
	_find_components()
	_setup_component_connections()
	
	# Добавляем в группу для поиска
	add_to_group("entities")

func _find_components() -> void:
	"""Ищет компоненты среди дочерних узлов"""
	health_component = get_node_or_null("HealthComponent") as HealthComponent
	mana_component = get_node_or_null("ManaComponent") as ResourceComponent
	stamina_component = get_node_or_null("StaminaComponent") as ResourceComponent
	progression_component = get_node_or_null("ProgressionComponent") as ProgressionComponent
	ability_component = get_node_or_null("AbilityComponent") as AbilityComponent
	hurtbox = get_node_or_null("Hurtbox") as Hurtbox

func _setup_component_connections() -> void:
	"""Подключает сигналы компонентов к EventBus"""
	if health_component:
		health_component.health_changed.connect(_on_health_changed)
		health_component.died.connect(_on_died)
		health_component.damage_taken.connect(_on_damage_taken)
	
	if mana_component:
		mana_component.changed.connect(_on_mana_changed)
	
	if stamina_component:
		stamina_component.changed.connect(_on_stamina_changed)
	
	if progression_component:
		progression_component.level_up.connect(_on_level_up)
		progression_component.experience_gained.connect(_on_experience_gained)

# ==================== ОБРАБОТЧИКИ СОБЫТИЙ КОМПОНЕНТОВ ====================
func _on_health_changed(new_value: int, old_value: int, max_value: int) -> void:
	EventBus.Entity.health_changed.emit(self, new_value, old_value, max_value)

func _on_died() -> void:
	is_dead = true
	EventBus.Entity.died.emit(self)
	_play_death_effect()

func _play_death_effect() -> void:
	var sprite = get_sprite()
	if sprite:
		_death_tween = create_tween()
		_death_tween.set_parallel(true)
		_death_tween.tween_property(sprite, "modulate", Color(0.3, 0.3, 0.3), 0.3)
		_death_tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
		await _death_tween.finished
		hide()
	else:
		hide()
	
	set_physics_process(false)
	set_process(false)

func apply_damage_flash(damage_type: int) -> void:
	var sprite = get_sprite()
	
	if not sprite:
		return
	
	var flash_color: Color
	match damage_type:
		0:
			flash_color = Color.RED
		1:
			flash_color = Color.BLUE
		_:
			flash_color = Color.WHITE
	
	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()
	
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", flash_color, 0.05)
	_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func apply_stun_effect() -> void:
	var sprite = get_sprite()
	if not sprite:
		return
	
	if _stun_tween and _stun_tween.is_running():
		_stun_tween.kill()
	
	_stun_tween = create_tween()
	_stun_tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func clear_stun_effect() -> void:
	var sprite = get_sprite()
	if not sprite:
		return
	
	if _stun_tween:
		_stun_tween.kill()
	sprite.modulate = Color.WHITE


func _on_damage_taken(amount: int, damage_type: int, source: Node, is_critical: bool) -> void:
	EventBus.Entity.damage_taken.emit(self, amount, damage_type, source, is_critical)

func _on_mana_changed(new_value: int, old_value: int, max_value: int) -> void:
	EventBus.Entity.mana_changed.emit(self, new_value, old_value, max_value)

func _on_stamina_changed(new_value: int, old_value: int, max_value: int) -> void:
	EventBus.Entity.stamina_changed.emit(self, new_value, old_value, max_value)

func _on_level_up(new_level: int, stat_increases: Dictionary) -> void:
	# Только для игрока — оставляем в Player.gd
	pass

func _on_experience_gained(amount: int, new_total: int, next_level: int) -> void:
	# Только для игрока — оставляем в Player.gd
	pass

# ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ====================
func _disable_entity() -> void:
	movement_locked = true
	interaction_locked = true
	set_physics_process(false)
	set_process(false)

# ==================== ПУБЛИЧНЫЕ МЕТОДЫ ====================
func take_damage(amount: int, damage_type: int, source: Node = null, is_critical: bool = false) -> void:
	"""Нанести урон сущности"""
	if health_component and not is_dead:
		health_component.take_damage(amount, damage_type, source, is_critical)

func heal(amount: int) -> void:
	"""Лечение сущности"""
	if health_component:
		health_component.heal(amount)

func use_stamina(amount: int) -> bool:
	"""Использовать выносливость"""
	return stamina_component and stamina_component.use(amount)

func use_mana(amount: int) -> bool:
	"""Использовать ману"""
	return mana_component and mana_component.use(amount)

func get_stat(stat_name: String) -> int:
	"""Получить характеристику"""
	if progression_component:
		return progression_component.get_stat(stat_name)
	return 0

func is_alive() -> bool:
	return health_component and health_component.is_alive() and not is_dead

func lock_movement(locked: bool = true) -> void:
	movement_locked = locked

func lock_interaction(locked: bool = true) -> void:
	interaction_locked = locked

# ==================== ВИРТУАЛЬНЫЕ МЕТОДЫ (ДЛЯ НАСЛЕДНИКОВ) ====================
func _on_interaction_started(activator: Node) -> void:
	"""Вызывается при начале взаимодействия (для переопределения)"""
	EventBus.Entity.interaction_started.emit(self, activator)

func _on_interaction_ended() -> void:
	"""Вызывается при завершении взаимодействия"""
	EventBus.Entity.interaction_ended.emit(self)

func get_horizontal_facing_direction() -> Vector2:
	"""Виртуальный метод - возвращает горизонтальное направление (вправо/влево).
	Должен быть переопределён в наследниках (Player, Actor)"""
	return Vector2.RIGHT  # значение по умолчанию

func get_sprite() -> Sprite2D:
	return null

# ==================== СОХРАНЕНИЕ ====================
func get_save_data() -> Dictionary:
	"""Сохранить состояние сущности"""
	var data = {}
	
	if progression_component:
		data["level"] = progression_component.get_level()
		data["experience"] = progression_component.get_experience()
	
	if health_component:
		data["current_hp"] = health_component.get_current_health()
		data["max_hp"] = health_component.get_max_health()
	
	if mana_component:
		data["current_mp"] = mana_component.get_current()
		data["max_mp"] = mana_component.get_max()
	
	if stamina_component:
		data["current_stamina"] = stamina_component.get_current()
		data["max_stamina"] = stamina_component.get_max()
	
	return data

func load_save_data(data: Dictionary) -> void:
	"""Загрузить состояние сущности"""
	# Будет переопределяться в наследниках
	pass
