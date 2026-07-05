extends Panel

@onready var health_label: Label = $VBoxContainer/HealthLabel
@onready var mana_label: Label = $VBoxContainer/ManaLabel
@onready var stamina_label: Label = $VBoxContainer/StaminaLabel
@onready var level_label: Label = $VBoxContainer/LevelLabel
@onready var exp_label: Label = $VBoxContainer/ExpLabel
@onready var trust_status_label: Label = $VBoxContainer/TrustStatusLabel
@onready var will_label: Label = $VBoxContainer/WillLabel

# Ссылки на компоненты игрока
var _player_health: HealthComponent = null
var _player_mana: ResourceComponent = null
var _player_stamina: ResourceComponent = null
var _player_progression: ProgressionComponent = null

func _ready() -> void:
	# Подписываемся на глобальные изменения отношений (доверие/воля)
	EventBus.Relationship.trust_changed.connect(_on_trust_changed)
	EventBus.Relationship.will_changed.connect(_on_will_changed)
	
	# Подписываемся на изменение видимости
	visibility_changed.connect(_on_visibility_changed)
	
	# Начальная настройка
	_find_player_components()
	_connect_component_signals()
	update_data()

func _on_visibility_changed() -> void:
	if visible:
		_find_player_components()
		_connect_component_signals()
		if not EventBus.Relationship.trust_changed.is_connected(_on_trust_changed):
			EventBus.Relationship.trust_changed.connect(_on_trust_changed)
		if not EventBus.Relationship.will_changed.is_connected(_on_will_changed):
			EventBus.Relationship.will_changed.connect(_on_will_changed)
		update_data()
	else:
		_disconnect_component_signals()
		if EventBus.Relationship.trust_changed.is_connected(_on_trust_changed):
			EventBus.Relationship.trust_changed.disconnect(_on_trust_changed)
		if EventBus.Relationship.will_changed.is_connected(_on_will_changed):
			EventBus.Relationship.will_changed.disconnect(_on_will_changed)

func _find_player_components() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	_player_health = player.get_node_or_null("HealthComponent")
	_player_mana = player.get_node_or_null("ManaComponent")
	_player_stamina = player.get_node_or_null("StaminaComponent")
	_player_progression = player.get_node_or_null("ProgressionComponent")

func _connect_component_signals() -> void:
	_disconnect_component_signals()  # Сначала отключаем старые

	if _player_health:
		if not _player_health.health_changed.is_connected(_on_health_changed):
			_player_health.health_changed.connect(_on_health_changed)

	if _player_mana:
		if not _player_mana.changed.is_connected(_on_mana_changed):
			_player_mana.changed.connect(_on_mana_changed)

	if _player_stamina:
		if not _player_stamina.changed.is_connected(_on_stamina_changed):
			_player_stamina.changed.connect(_on_stamina_changed)

	if _player_progression and _player_progression.entity_data:
		# Подписываемся на сигналы entity_data (уровень/опыт хранятся там)
		var entity_data = _player_progression.entity_data
		if not entity_data.level_changed.is_connected(_on_level_changed):
			entity_data.level_changed.connect(_on_level_changed)
		if not entity_data.experience_changed.is_connected(_on_exp_changed):
			entity_data.experience_changed.connect(_on_exp_changed)
		if not _player_progression.experience_gained.is_connected(_on_exp_gained):
			_player_progression.experience_gained.connect(_on_exp_gained)

func _disconnect_component_signals() -> void:
	if _player_health and _player_health.health_changed.is_connected(_on_health_changed):
		_player_health.health_changed.disconnect(_on_health_changed)

	if _player_mana and _player_mana.changed.is_connected(_on_mana_changed):
		_player_mana.changed.disconnect(_on_mana_changed)

	if _player_stamina and _player_stamina.changed.is_connected(_on_stamina_changed):
		_player_stamina.changed.disconnect(_on_stamina_changed)

	if _player_progression and _player_progression.entity_data:
		var entity_data = _player_progression.entity_data
		if entity_data.level_changed.is_connected(_on_level_changed):
			entity_data.level_changed.disconnect(_on_level_changed)
		if entity_data.experience_changed.is_connected(_on_exp_changed):
			entity_data.experience_changed.disconnect(_on_exp_changed)
		if _player_progression.experience_gained.is_connected(_on_exp_gained):
			_player_progression.experience_gained.disconnect(_on_exp_gained)

# ==================== ОБНОВЛЕНИЕ ДАННЫХ ====================
func update_data() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		_set_default_values()
		return

	# Здоровье
	if _player_health and _player_health.entity_data:
		health_label.text = "Здоровье: %d/%d" % [_player_health.get_current_health(), _player_health.get_max_health()]
	else:
		health_label.text = "Здоровье: 0/0"

	# Мана
	if _player_mana and _player_mana.entity_data:
		mana_label.text = "Мана: %d/%d" % [_player_mana.get_current(), _player_mana.get_max()]
	else:
		mana_label.text = "Мана: 0/0"

	# Выносливость
	if _player_stamina and _player_stamina.entity_data:
		stamina_label.text = "Выносливость: %d/%d" % [_player_stamina.get_current(), _player_stamina.get_max()]
	else:
		stamina_label.text = "Выносливость: 0/0"

	# Уровень
	if _player_progression and _player_progression.entity_data:
		level_label.text = "Уровень: %d" % _player_progression.entity_data.level
		exp_label.text = "Опыт: %d/%d" % [_player_progression.entity_data.experience, _player_progression.entity_data.experience_to_next_level]
	else:
		level_label.text = "Уровень: 1"
		exp_label.text = "Опыт: 0/0"

	# Доверие и воля (из RelationshipManager)
	trust_status_label.text = "Статус: %s" % RelationshipManager.get_trust_status()
	will_label.text = "Воля: %d" % RelationshipManager.get_will_power()

func _set_default_values() -> void:
	health_label.text = "Здоровье: 0/0"
	mana_label.text = "Мана: 0/0"
	stamina_label.text = "Выносливость: 0/0"
	level_label.text = "Уровень: 1"
	exp_label.text = "Опыт: 0/0"
	trust_status_label.text = "Статус: Неизвестно"
	will_label.text = "Воля: 0"

# ==================== ОБРАБОТЧИКИ СИГНАЛОВ ====================
func _on_health_changed(_new_hp: int, _old_hp: int, _max_hp: int) -> void:
	if _player_health:
		health_label.text = "Здоровье: %d/%d" % [_player_health.get_current_health(), _player_health.get_max_health()]

func _on_mana_changed(_new_value: int, _old_value: int, _max_value: int) -> void:
	if _player_mana:
		mana_label.text = "Мана: %d/%d" % [_player_mana.get_current(), _player_mana.get_max()]

func _on_stamina_changed(_new_value: int, _old_value: int, _max_value: int) -> void:
	if _player_stamina:
		stamina_label.text = "Выносливость: %d/%d" % [_player_stamina.get_current(), _player_stamina.get_max()]

func _on_level_changed(_new_level: int, _old_level: int) -> void:
	if _player_progression and _player_progression.entity_data:
		level_label.text = "Уровень: %d" % _player_progression.entity_data.level
		exp_label.text = "Опыт: %d/%d" % [_player_progression.entity_data.experience, _player_progression.entity_data.experience_to_next_level]

func _on_exp_changed(_new_exp: int, _old_exp: int) -> void:
	if _player_progression and _player_progression.entity_data:
		exp_label.text = "Опыт: %d/%d" % [_player_progression.entity_data.experience, _player_progression.entity_data.experience_to_next_level]

func _on_exp_gained(_amount: int, _new_total: int, _next_level: int) -> void:
	if _player_progression and _player_progression.entity_data:
		exp_label.text = "Опыт: %d/%d" % [_player_progression.entity_data.experience, _player_progression.entity_data.experience_to_next_level]

func _on_trust_changed(_new_value: int, _delta: int) -> void:
	trust_status_label.text = "Статус: %s" % RelationshipManager.get_trust_status()

func _on_will_changed(_new_value: int, _delta: int) -> void:
	will_label.text = "Воля: %d" % RelationshipManager.get_will_power()
