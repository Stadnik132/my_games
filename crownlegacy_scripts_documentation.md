# ================================================================================
# ПОЛНОЕ СОДЕРЖИМОЕ: EventBus.gd
# ================================================================================

extends Node

# ==================== ГРУППЫ СИГНАЛОВ ====================

# ----- Глобальные состояния игры -----
class GameSignals:
	signal state_changed(new_state: int, old_state: int)
	signal paused(is_paused: bool)
	signal world_requested()
	signal dialogue_requested(timeline_name: String)
	signal menu_requested()
	signal cutscene_requested(cutscene_id: String)
	signal game_over_requested()
	signal decision_point_activated()  # Замедление времени
	signal decision_point_deactivated()  # Возврат времени	

# ----- Общие сигналы для всех живых сущностей (Player, Actor, Enemy) -----
class EntitySignals:
	# Здоровье
	signal health_changed(entity: Node, new_value: int, old_value: int, max_value: int)
	signal damage_taken(entity: Node, amount: int, damage_type: int, source: Node, is_critical: bool)
	signal healed(entity: Node, amount: int, new_health: int)
	signal died(entity: Node)
	
	# Мана
	signal mana_changed(entity: Node, new_value: int, old_value: int, max_value: int)
	
	# Выносливость
	signal stamina_changed(entity: Node, new_value: int, old_value: int, max_value: int)
	
	# Взаимодействие
	signal interaction_started(entity: Node, activator: Node)
	signal interaction_ended(entity: Node)

# ----- Специфичные для игрока сигналы (только то, чего нет у других) -----
class PlayerSignals:
	signal level_up(new_level: int, stat_increases: Dictionary)
	signal experience_gained(amount: int, new_total: int)
	signal equipment_changed(slot: String, old_item: String, new_item: String)

# ----- Система отношений Доверие/Воля -----
class RelationshipSignals:
	signal trust_changed(new_value: int, delta: int)
	signal will_changed(new_value: int, delta: int)
	signal will_used(amount: int, remaining: int)
	signal trust_effect_applied(effect_type: String, multiplier: float)

# ----- Система диалогов (Dialogic 2.0) -----
class DialogueSignals:
	signal started(timeline_name: String, npc: Node)
	signal ended()
	signal choice_selected(choice_index: int, choice_text: String)
	signal requested(timeline_name: String, npc_id: String)
	signal change_trust(amount: int)
	signal set_flag(flag_name: String, value: Variant)
	signal use_will(amount: int)
	signal start_battle(npc_id: String)

# ----- Боевая система (структурированная) -----
class CombatSignals:
	# Управление боем
	signal started(enemies: Array)
	signal ended(victory: bool)
	signal combat_state_changed(old_state: String, new_state: String)
	signal entity_stunned(entity: Node, is_stunned: bool)
	
	# Враги
	class EnemySignals:
		signal health_changed(enemy: Node, current_hp: int, max_hp: int)
		signal died(enemy: Node, experience: int)
		signal hit(enemy: Node, damage: int, is_critical: bool)
	
	# Точки решений
	class DecisionSignals:
		signal point_triggered(enemy: Node, trigger_data: Dictionary)
		signal made(enemy: Node, choice: String)
		signal ui_closed()
		signal dialogic_made(choice: String)
		signal combat_to_dialogue_requested(enemy: Node)
		signal point_requested(enemy: Node, trigger_data: Dictionary)  # Запрос от актора
		signal transition_to_dialogue(enemy: Node, timeline: String)  # Переход в диалог
		signal enemy_spared(enemy: Node)  # Враг пощажён
	
	# Атаки
	class AttackSignals:
		signal basic_requested()
		signal basic_started()
		signal basic_hit(combo_step: int, enemies_hit: int)
		signal combo_reset()
		signal combo_window_opened()
		signal combo_window_closed()
	
	# Уклонение (теперь без failed)
	class DodgeSignals:
		signal requested(direction: Vector2)
		signal started()
		signal completed()
	
	# Блокирование
	class BlockSignals:
		signal started()
		signal ended()
		signal active()
		signal reduced_damage(damage_after_block: int)
		signal broken()
	
	# Способности
	class AbilitySignals:
		signal slot_pressed(slot_index: int)
		signal aiming_started(slot_index: int)
		signal aiming_cancelled()
		signal target_confirmed(target_position: Vector2)
		signal cast_started(ability: Resource)  # AbilityResource
		signal cast_completed()
		signal animation_started(animation_name: String, duration: float)
	
	# Экземпляры подгрупп (создаются в CombatSignals)
	var enemy: EnemySignals
	var decision: DecisionSignals
	var attack: AttackSignals
	var dodge: DodgeSignals
	var block: BlockSignals
	var ability: AbilitySignals
	
	func _init():
		enemy = EnemySignals.new()
		decision = DecisionSignals.new()
		attack = AttackSignals.new()
		dodge = DodgeSignals.new()
		block = BlockSignals.new()
		ability = AbilitySignals.new()

# ----- Система анимаций (общая) -----
class AnimationSignals:
	signal requested(target: Node, animation_name: String, duration: float)
	signal started(target: Node, animation_name: String)
	signal finished(target: Node, animation_name: String)
	signal interrupted(target: Node, animation_name: String)

# ----- Пользовательский интерфейс -----
class UISignals:
	signal menu_opened(menu_type: String)
	signal menu_closed()
	signal notification(text: String, duration: float)
	signal hud_update_required()

# ----- Акторы (NPC, объекты мира) -----
class ActorsSignals:
	signal mode_changed(actor: Node, new_mode: String, old_mode: String)
	signal interaction_started(actor: Node)  # устареет, используйте Entity.interaction_started
	signal died(actor: Node)  # устареет, используйте Entity.died
	signal interaction_requested()  # устареет

# ----- Система глобальных флагов -----
class FlagsSignals:
	signal flag_changed(flag_name: String, value: Variant)

# ----- Системные события -----
class SystemSignals:
	signal settings_changed(setting_name: String, value: Variant)
	signal scene_changed(old_scene: String, new_scene: String)


# ==================== ЭКЗЕМПЛЯРЫ ====================

var Game: GameSignals = GameSignals.new()
var Entity: EntitySignals = EntitySignals.new()
var Player: PlayerSignals = PlayerSignals.new()
var Relationship: RelationshipSignals = RelationshipSignals.new()
var Dialogue: DialogueSignals = DialogueSignals.new()
var Combat: CombatSignals = CombatSignals.new()
var Animations: AnimationSignals = AnimationSignals.new()
var UI: UISignals = UISignals.new()
var Actors: ActorsSignals = ActorsSignals.new()
var Flags: FlagsSignals = FlagsSignals.new()
var System: SystemSignals = SystemSignals.new()


# ==================== МЕТОДЫ ====================

func _ready() -> void:
	_clear_all_connections()
	print("EventBus: инициализирован")
	if OS.is_debug_build():
		_print_debug_info()


func _clear_all_connections() -> void:
	var signal_groups = [
		Game, Entity, Player, Relationship, Dialogue,
		Combat, Animations, UI, Actors, Flags, System,
		Combat.enemy, Combat.decision, Combat.attack,
		Combat.dodge, Combat.block, Combat.ability
	]
	
	for group in signal_groups:
		if not group:
			continue
			
		var signals_dict = group.get_signal_list()
		for signal_info in signals_dict:
			var signal_name = signal_info["name"] as StringName
			var connections = group.get_signal_connection_list(signal_name)
			for conn in connections:
				var callable_obj = conn["callable"]
				if group.is_connected(signal_name, callable_obj):
					group.disconnect(signal_name, callable_obj)
	
	print("EventBus: все старые подключения очищены")


func _print_debug_info() -> void:
	print("=== EventBus [Активен] ===")
	print("Основные группы: Game, Entity, Player, Relationship, Dialogue, Combat, Animations, UI, Actors, Flags, System")
	print("Подгруппы Combat: enemy, decision, attack, dodge, block, ability")
	print("===========================")


# ==================== МИГРАЦИЯ (совместимость со старым кодом) ====================

# Эти варнинги помогут найти старый код, который ещё использует устаревшие сигналы
func _get_property_list() -> Array:
	return [
		{
			"name": "EventBus_Compatibility_Warnings",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
		}
	]

# Вызовется при обращении к несуществующему свойству (для отлова старого кода)
func _get(property: StringName):
	if property in ["Player_damage_taken", "Player_hp_changed", "Player_mp_changed", "Player_stamina_changed"]:
		push_warning("EventBus: Сигнал ", property, " устарел. Используйте EventBus.Entity.*")
	return null


# ================================================================================
# СПИСОК ФУНКЦИЙ ВСЕХ ОСТАЛЬНЫХ СКРИПТОВ
# ================================================================================

# ------------------------------------------------------------------------------
# Scripts/Ability/AbilityComponent.gd
# class_name: AbilityComponent
# ------------------------------------------------------------------------------
• _ready() — Инициализация компонента
• setup(owner_entity: Entity) — Настройка компонента с привязкой к сущности
• _find_components() — Поиск необходимых компонентов
• _initialize_slots() — Инициализация слотов способностей
• _process(delta) — Обработка каждый кадр
• get_ability_in_slot(slot_index) — Получение способности из слота
• set_ability_in_slot(slot_index, ability_id) — Установка способности в слот

# ------------------------------------------------------------------------------
# Scripts/Ability/AbilityEffect/AreaEffect.gd
# class_name: AreaEffect
# ------------------------------------------------------------------------------
• setup(params) — Настройка эффекта области
• _apply_initial_damage() — Применение начального урона
• _damage_target(target) — Нанесение урона цели
• _on_area_entered(area) — Обработчик входа в область
• _on_body_entered(body) — Обработчик входа тела в область
• _queue_after_duration() — Очередь удаления после завершения

# ------------------------------------------------------------------------------
# Scripts/Ability/AbilityEffect/BerserkEffect.gd
# class_name: BerserkEffect
# ------------------------------------------------------------------------------
• setup(params) — Настройка эффекта берсерка
• _apply_buff_visual(sprite) — Применение визуального эффекта баффа
• _queue_after_duration() — Очередь удаления после завершения
• _cleanup() — Очистка эффекта

# ------------------------------------------------------------------------------
# Scripts/Ability/AbilityEffect/InstantEffect.gd
# class_name: InstantEffect
# ------------------------------------------------------------------------------
• setup(params) — Настройка мгновенного эффекта
• _apply_initial_damage() — Применение начального урона
• _damage_target(target) — Нанесение урона цели
• _on_area_entered(area) — Обработчик входа в область
• _on_body_entered(body) — Обработчик входа тела в область
• _queue_after_duration() — Очередь удаления после завершения

# ------------------------------------------------------------------------------
# Scripts/Ability/AbilityEffect/Projectile.gd
# class_name: Projectile
# ------------------------------------------------------------------------------
• setup(params) — Настройка снаряда
• _physics_process(delta) — Физическая обработка каждый кадр
• _on_body_entered(body) — Обработчик столкновения с телом
• _on_area_entered(area) — Обработчик входа в область
• _apply_damage(target) — Применение урона к цели
• _apply_damage_to_hurtbox(hurtbox) — Применение урона к hurtbox

# ------------------------------------------------------------------------------
# Scripts/Ability/AbilityEffect/fireball.gd
# class_name: FireballProjectile
# ------------------------------------------------------------------------------
• setup(params) — Настройка огненного шара
• _physics_process(delta) — Физическая обработка каждый кадр
• _apply_damage(target) — Применение урона к цели

# ------------------------------------------------------------------------------
# Scripts/Ability/AbilityVisual/AreaAimingVisual.gd
# class_name: AreaAimingVisual
# ------------------------------------------------------------------------------
• _ready_setup() — Настройка при готовности
• _process(delta) — Обработка каждый кадр
• _get_target_data() — Получение данных о цели

# ------------------------------------------------------------------------------
# Scripts/Ability/AbilityVisual/BaseAimingVisual.gd
# class_name: BaseAimingVisual
# Signals: confirmed, cancelled
# ------------------------------------------------------------------------------
• setup(p_ability, p_caster) — Настройка прицеливания
• _ready_setup() — Настройка при готовности
• _input(event) — Обработка ввода
• _confirm() — Подтверждение прицеливания
• cancel() — Отмена прицеливания
• _get_target_data() — Получение данных о цели

# ------------------------------------------------------------------------------
# Scripts/Ability/AbilityVisual/ProjectileAimingVisual.gd
# class_name: ProjectileAimingVisual
# ------------------------------------------------------------------------------
• _ready_setup() — Настройка при готовности
• _process(delta) — Обработка каждый кадр
• _get_target_data() — Получение данных о цели

# ------------------------------------------------------------------------------
# Scripts/autoloads/AbilityManager.gd
# ------------------------------------------------------------------------------
• _ready() — Инициализация менеджера способностей
• load_abilities_from_json(json_path) — Загрузка способностей из JSON
• _unlock_all_abilities_for_test() — Временная разблокировка всех способностей для теста
• get_ability(ability_id) — Получение способности по ID
• is_ability_unlocked(ability_id) — Проверка разблокировки способности
• unlock_ability(ability_id) — Разблокировка способности
• get_unlocked_abilities() — Получение списка разблокированных способностей
• save_data() — Сохранение данных
• load_data(data) — Загрузка данных

# ------------------------------------------------------------------------------
# Scripts/autoloads/BalanceConfig.gd
# class_name: BalanceConfig
# ------------------------------------------------------------------------------
[Ресурс с экспортируемыми параметрами баланса: доверие, перемещение, бой, прогрессия]

# ------------------------------------------------------------------------------
# Scripts/autoloads/CombatManager.gd
# Signals: combat_started, combat_ended
# ------------------------------------------------------------------------------
• _ready() — Инициализация менеджера боя
• _setup_connections() — Настройка подключений событий
• start_combat(enemies, marker_point) — Начало боя с врагами
• end_combat(victory, transition_to_dialogue, dialogue_target) — Завершение боя
• _initialize_enemy(enemy) — Инициализация врага в бою
• _on_enemy_died(enemy) — Обработчик смерти врага
• _on_enemy_spared(enemy) — Обработчик пощады врага
• _on_transition_to_dialogue(enemy, timeline) — Переход в диалог
• _calculate_experience(victory) — Расчёт полученного опыта
• _on_combat_started(enemies) — Обработчик начала боя
• _on_dialogue_start_battle(npc_id) — Запрос боя из диалога
• start_combat_with_npc(npc) — Начало боя с NPC
• _find_npc_by_id(npc_id) — Поиск NPC по ID
• _on_entity_died(entity) — Обработчик смерти сущности
• is_in_combat() — Проверка активности боя
• get_active_enemies() — Получение активных врагов
• _perform_combat_start_jump(enemies, marker_point) — Отскок персонажей при начале боя
• _finalize_combat_start(enemies) — Завершение начала боя
• _get_combat_config_from_enemy(enemy) — Получение конфигурации боя от врага

# ------------------------------------------------------------------------------
# Scripts/autoloads/DecisionManager.gd
# Signals: decision_point_triggered, decision_made
# ------------------------------------------------------------------------------
• _ready() — Инициализация системы решений
• _setup_connections() — Настройка подключений событий
• force_end_decision_point() — Принудительное завершение точки решения
• is_decision_point_available() — Проверка доступности точки решения
• _on_decision_point_requested(enemy, trigger_data) — Запрос точки решения
• _trigger_decision_point(enemy, trigger_data) — Активация точки решения
• _exit_decision_point() — Выход из точки решения
• _on_dialogic_decision_made(choice) — Обработчик решения из Dialogic
• _calculate_experience_reward(enemy) — Расчёт награды за решение

# ------------------------------------------------------------------------------
# Scripts/autoloads/DialogicBridge.gd
# ------------------------------------------------------------------------------
• _ready() — Инициализация моста Dialogic
• _setup_event_bus_connections() — Настройка подключений EventBus
• _on_transition_to_dialogue_requested(timeline_name) — Запрос перехода к диалогу
• _setup_dialogic_connections() — Настройка подключений Dialogic
• _on_trust_changed(new_value, delta) — Обработчик изменения доверия
• _on_will_changed(new_value, delta) — Обработчик изменения воли
• _on_flag_changed(flag_name, value) — Обработчик изменения флага

# ------------------------------------------------------------------------------
# Scripts/autoloads/GameFlags.gd
# Signal: flag_debug_updated
# ------------------------------------------------------------------------------
• _ready() — Инициализация системы флагов
• set_flag(flag_name, value, source) — Установка флага
• get_flag(flag_name, default) — Получение значения флага
• get_flag_data(flag_name) — Получение данных флага
• has_flag(flag_name) — Проверка наличия флага
• is_flag_true(flag_name) — Проверка истинности флага
• is_flag_false(flag_name) — Проверка ложности флага
• clear_flag(flag_name) — Очистка флага
• toggle_flag(flag_name, source) — Переключение флага

# ------------------------------------------------------------------------------
# Scripts/autoloads/GameStateManager.gd
# ------------------------------------------------------------------------------
• _ready() — Инициализация менеджера состояний игры
• _setup_event_bus_connections() — Настройка подключений EventBus
• change_state(new_state, force) — Изменение состояния игры
• _is_transition_allowed(from_state, to_state) — Проверка допустимости перехода
• _handle_state_change_effects(new_state, old_state) — Обработка эффектов смены состояния

# ------------------------------------------------------------------------------
# Scripts/autoloads/ItemRegistry.gd
# Signal: registry_updated
# ------------------------------------------------------------------------------
• _ready() — Инициализация реестра предметов
• _register_all_items() — Регистрация всех предметов
• _is_item_file(file_name) — Проверка файла предмета
• _register_item_from_file(path) — Регистрация предмета из файла
• get_item(item_id) — Получение предмета по ID
• has_item(item_id) — Проверка наличия предмета
• get_all_items() — Получение всех предметов
• get_items_by_type(item_type) — Получение предметов по типу
• get_item_count() — Получение количества предметов

# ------------------------------------------------------------------------------
# Scripts/autoloads/PlayerManager.gd
# ------------------------------------------------------------------------------
• _ready() — Инициализация менеджера игрока
• _find_components() — Поиск компонентов игрока
• _bind_player_data() — Привязка данных игрока
• _setup_connections() — Настройка подключений
• _restore_inventory_from_save(inventory_data) — Восстановление инвентаря из сохранения
• _on_trust_changed(new_value, _delta) — Обработчик изменения доверия
• add_experience(amount, source) — Добавление опыта
• heal(amount, _source) — Лечение игрока
• get_effective_stat(stat_name) — Получение эффективного значения стата
• _load_inventory_from_data() — Загрузка инвентаря из данных

# ------------------------------------------------------------------------------
# Scripts/autoloads/RelationshipManager.gd
# Signals: trust_changed, will_changed
# ------------------------------------------------------------------------------
• _ready() — Инициализация менеджера отношений
• can_force_action() — Проверка возможности принудительного действия
• use_will(amount) — Использование воли
• force_action() — Принудительное действие
• add_will(amount) — Добавление воли
• change_trust(amount, source) — Изменение доверия
• get_combat_modifier(modifier_name) — Получение модификатора боя
• get_refusal_chance() — Получение шанса отказа
• get_trust_level() — Получение уровня доверия
• get_will_power() — Получение текущей воли
• get_trust_status() — Получение статуса доверия

# ------------------------------------------------------------------------------
# Scripts/autoloads/SaveManager.gd
# ------------------------------------------------------------------------------
• _ready() — Инициализация менеджера сохранений
• save_game(slot_name) — Сохранение игры в слот
• load_game(slot_name) — Загрузка игры из слота
• delete_save(slot_name) — Удаление сохранения
• reset_game() — Сброс игры
• get_save_list() — Получение списка сохранений

# ------------------------------------------------------------------------------
# Scripts/autoloads/SettingManager.gd
# ------------------------------------------------------------------------------
• _ready() — Инициализация менеджера настроек
• get_resolution_index() — Получение индекса разрешения
• set_resolution_index(index) — Установка разрешения
• get_window_mode_index() — Получение режима окна
• set_window_mode_index(index) — Установка режима окна
• get_vsync() — Получение статуса VSync
• set_vsync(enabled) — Установка VSync
• get_volume(bus_name) — Получение громкости шины
• set_volume(bus_name, value) — Установка громкости шины
• apply_audio_settings() — Применение аудио настроек
• _apply_video_settings() — Применение видео настроек

# ------------------------------------------------------------------------------
# Scripts/demo/VillageBorderArea.gd
# ------------------------------------------------------------------------------
• _ready() — Инициализация граничной области деревни
• _on_body_entered(body) — Обработчик входа тела в область
• _on_body_exited(body) — Обработчик выхода тела из области
• _handle_player_entered(player) — Обработка входа игрока
• _push_player_back(player) — Отталкивание игрока назад
• _lock_player_control(player) — Блокировка управления игроком
• _show_border_message() — Показ сообщения о границе

# ------------------------------------------------------------------------------
# Scripts/entitis/Actors/Actor.gd
# class_name: Actor
# ------------------------------------------------------------------------------
• _ready() — Инициализация актёра

# ------------------------------------------------------------------------------
# Scripts/entitis/Actors/Components/AI/AIBrain.gd
# class_name: AIBrain
# ------------------------------------------------------------------------------
• setup(actor_node, perception_node, combat_node) — Настройка мозга ИИ
• decide() — Принятие решения о действии
• _get_available_ability_slot() — Получение доступного слота способности

# ------------------------------------------------------------------------------
# Scripts/entitis/Actors/Components/AI/AICommand.gd
# ------------------------------------------------------------------------------
• _ready() — Инициализация команды ИИ
• _process(delta) — Обработка каждый кадр

# ------------------------------------------------------------------------------
# Scripts/entitis/Actors/Components/AI/AIController.gd
# class_name: AIController
# ------------------------------------------------------------------------------
• setup(actor_node) — Настройка контроллера ИИ
• set_active(active) — Установка активности ИИ
• _process(delta) — Обработка каждый кадр
• _execute_decision(decision, fsm) — Выполнение решения

# ------------------------------------------------------------------------------
# Scripts/entitis/Actors/Components/AI/AIPerception.gd
# class_name: AIPerception
# ------------------------------------------------------------------------------
• _ready() — Инициализация восприятия ИИ
• setup(actor_node) — Настройка восприятия
• _update_perception() — Обновление восприятия
• is_player_detected() — Проверка обнаружения игрока
• get_player_position() — Получение позиции игрока
• get_distance_to_player() — Получение дистанции до игрока

# ------------------------------------------------------------------------------
# Scripts/entitis/Actors/Components/ActorCombatComponent.gd
# class_name: ActorCombatComponent
# ------------------------------------------------------------------------------
• setup(actor, data) — Настройка боевого компонента актёра
• _find_components() — Поиск компонентов
• _setup_connections() — Настройка подключений
• set_desired_move(dir) — Установка желаемого направления движения
• get_move_vector() — Получение вектора движения
• enter_combat() — Вход в бой
• exit_combat() — Выход из боя
• set_active(value) — Установка активности
• is_in_combat() — Проверка нахождения в бою
• get_fsm() — Получение FSM
• get_combat_config() — Получение конфигурации боя
• _on_hurtbox_damage(damage_data, source) — Обработчик получения урона
• _apply_defense(damage, damage_data) — Применение защиты

# ------------------------------------------------------------------------------
# Scripts/entitis/Actors/Components/ActorInteractionComponent.gd
# class_name: ActorInteractionComponent
# Signals: player_entered_range, player_exited_range
# ------------------------------------------------------------------------------
• setup(actor) — Настройка компонента взаимодействия
• _setup_collision() — Настройка коллизии
• _on_body_entered(body) — Обработчик входа тела в область
• _on_body_exited(body) — Обработчик выхода тела из области
• is_player_in_range() — Проверка нахождения игрока в радиусе

# ------------------------------------------------------------------------------
# Scripts/entitis/Actors/Components/ActorPositionGuardComponent.gd
# class_name: ActorPositionGuardComponent
# ------------------------------------------------------------------------------
• setup(actor) — Настройка компонента охраны позиции
• process_physics(_delta) — Физическая обработка
• _check_if_pushed_away() — Проверка отталкивания
• _handle_pushed_away() — Обработка отталкивания
• _get_player_nearby() — Получение ближайшего игрока
• _face_toward_player(player_pos) — Поворот к игроку

# ------------------------------------------------------------------------------
# Scripts/entitis/Actors/Components/AnimationComponent.gd
# class_name: AnimationComponent
# ------------------------------------------------------------------------------
• setup(_actor) — Настройка анимационного компонента
• play_animation(anim_name, force) — Воспроизведение анимации
• update_facing_direction(velocity) — Обновление направления взгляда
• get_cardinal_direction() — Получение направления света
• play_movement_animation(velocity) — Воспроизведение анимации движения

# ------------------------------------------------------------------------------
# Scripts/entitis/Actors/Components/State/CastState.gd
# class_name: CastState
# ------------------------------------------------------------------------------
• enter() — Вход в состояние casts
• process(delta) — Обработка состояния
• physics_process(_delta) — Физическая обработка
• _finish_cast() — Завершение заклинания
• handle_command(command, data) — Обработка команд
• get_allowed_transitions() — Получение разрешённых переходов
• can_exit() — Проверка возможности выхода

# ------------------------------------------------------------------------------
# Scripts/entitis/Actors/Components/VisionComponent.gd
# class_name: VisionComponent
# Signals: target_entered, target_exited
# ------------------------------------------------------------------------------
• setup(actor) — Настройка компонента зрения
• _setup_collision() — Настройка коллизии
• get_closest_target() — Получение ближайшей цели
• get_all_targets() — Получение всех целей
• _on_body_entered(body) — Обработчик входа тела
• _on_body_exited(body) — Обработчик выхода тела
• _on_area_entered(area) — Обработчик входа области
• _on_area_exited(area) — Обработчик выхода области
• _add_target(node) — Добавление цели
• _remove_target(node) — Удаление цели

# ------------------------------------------------------------------------------
# Scripts/entitis/CombatComponent.gd
# class_name: CombatComponent
# ------------------------------------------------------------------------------
• _ready() — Инициализация боевого компонента
• _late_setup_ability_component() — Поздняя настройка компонента способностей
• _find_components() — Поиск компонентов
• _setup_fsm() — Настройка FSM
• _setup_connections() — Настройка подключений
• get_attack_params() — Получение параметров атаки
• get_dodge_params() — Получение параметров уклонения
• get_fsm() — Получение FSM
• _on_attack_requested() — Обработчик запроса атаки
• _on_dodge_requested(direction) — Обработчик запроса уклонения

# ------------------------------------------------------------------------------
# Scripts/entitis/CombatConfig.gd
# class_name: CombatConfig
# ------------------------------------------------------------------------------
[Ресурс с конфигурацией боевых параметров]

# ------------------------------------------------------------------------------
# Scripts/entitis/DecisionTriggerComponent.gd
# class_name: DecisionTriggerComponent
# Signal: trigger_activated
# ------------------------------------------------------------------------------
• _ready() — Инициализация компонента триггеров решений
• _setup_event_bus_connections() — Настройка подключений EventBus
• setup(entity, triggers) — Настройка компонента с триггерами
• _setup_component_connections() — Настройка подключений компонентов
• _on_combat_started(enemies) — Обработчик начала боя
• _on_combat_ended(victory) — Обработчик завершения боя
• start_combat_tracking() — Начало отслеживания боя
• stop_combat_tracking() — Остановка отслеживания боя

# ------------------------------------------------------------------------------
# Scripts/entitis/Entity.gd
# class_name: Entity
# ------------------------------------------------------------------------------
• _ready() — Инициализация сущности
• _find_components() — Поиск компонентов
• _setup_component_connections() — Настройка подключений компонентов
• _on_health_changed(new_value, old_value, max_value) — Обработчик изменения здоровья
• _on_died() — Обработчик смерти
• _play_death_effect() — Воспроизведение эффекта смерти
• apply_damage_flash(damage_type) — Применение вспышки урона

# ------------------------------------------------------------------------------
# Scripts/entitis/EntityCombatFSM.gd
# class_name: EntityCombatFSM
# Signal: state_changed
# ------------------------------------------------------------------------------
• setup(p_entity, p_stats, p_component, p_config) — Настройка FSM
• change_state(state_name) — Изменение состояния
• send_command(command, data) — Отправка команды

# ------------------------------------------------------------------------------
# Scripts/entitis/HealthComponent.gd
# class_name: HealthComponent
# Signals: health_changed, died, damage_taken, healed
# ------------------------------------------------------------------------------
• _ready() — Инициализация компонента здоровья
• _on_data_died() — Обработчик смерти из данных
• take_damage(amount, damage_type, source, is_critical) — Получение урона
• _apply_damage_flash(damage_type) — Применение вспышки урона
• heal(amount) — Лечение
• set_max_health(new_max) — Установка максимального здоровья
• is_alive() — Проверка жизни
• get_health_percentage() — Получение процента здоровья
• get_current_health() — Получение текущего здоровья
• get_max_health() — Получение максимального здоровья

# ------------------------------------------------------------------------------
# Scripts/entitis/Hitbox.gd
# class_name: Hitbox
# ------------------------------------------------------------------------------
• _ready() — Инициализация hitbox
• _apply_damage_to_overlapping() — Применение урона пересекающимся объектам
• _update_layers_from_source() — Обновление слоёв от источника
• _on_area_entered(area) — Обработчик входа в область
• get_damage_data() — Получение данных урона
• set_damage_data(data) — Установка данных урона

# ------------------------------------------------------------------------------
# Scripts/entitis/HitboxComponent.gd
# class_name: HitboxComponent
# Signal: hit_enemy
# ------------------------------------------------------------------------------
• _ready() — Инициализация компонента hitbox
• spawn_hitbox(...) — Создание hitbox
• spawn_area_hitbox(...) — Создание area hitbox
• clear_hitboxes() — Очистка hitbox
• _on_hitbox_removed(hitbox) — Обработчик удаления hitbox
• spawn_hitbox_with_damage(position, direction, damage_data) — Создание hitbox с уроном

# ------------------------------------------------------------------------------
# Scripts/entitis/Hurtbox.gd
# class_name: Hurtbox
# Signal: damage_taken
# ------------------------------------------------------------------------------
• set_entity_owner(owner_node) — Установка владельца сущности
• _ready() — Инициализация hurtbox
• update_layer_from_owner() — Обновление слоя от владельца
• _on_hitbox_entered(area) — Обработчик входа hitbox

# ------------------------------------------------------------------------------
# Scripts/entitis/InventoryComponent.gd
# class_name: InventoryComponent
# Signals: item_added, item_removed, inventory_changed, inventory_updated
# ------------------------------------------------------------------------------
• _ready() — Инициализация компонента инвентаря
• add_item(item, quantity) — Добавление предмета
• remove_item(slot_index, quantity) — Удаление предмета
• get_item_at_slot(slot_index) — Получение предмета в слоте

# ------------------------------------------------------------------------------
# Scripts/entitis/Player/Player.gd
# class_name: Player
# ------------------------------------------------------------------------------
• _ready() — Инициализация игрока
• _init_inventory() — Инициализация инвентаря
• _on_item_registry_ready(item_count) — Обработчик готовности реестра предметов
• _add_startup_items() — Добавление стартовых предметов

# ------------------------------------------------------------------------------
# Scripts/entitis/Player/PlayerCombatComponent.gd
# class_name: PlayerCombatComponent
# ------------------------------------------------------------------------------
• _setup_connections() — Настройка подключений
• _on_combo_window_opened() — Обработчик открытия окна комбо
• _on_combo_window_closed() — Обработчик закрытия окна комбо
• _on_attack_requested() — Обработчик запроса атаки
• _on_dodge_requested(direction) — Обработчик запроса уклонения
• _on_block_started() — Обработчик начала блока
• _on_block_ended() — Обработчик завершения блока
• _on_hurtbox_damage(damage_data, source) — Обработчик получения урона
• get_move_vector() — Получение вектора движения

# ------------------------------------------------------------------------------
# Scripts/entitis/Player/PlayerController.gd
# class_name: PlayerController
# ------------------------------------------------------------------------------
• _input(event) — Обработка ввода
• _handle_global_input(event) — Обработка глобального ввода
• _handle_combat_input(event) — Обработка боевого ввода
• _handle_interaction() — Обработка взаимодействия

# ------------------------------------------------------------------------------
# Scripts/entitis/Player/PlayerInteractionDetector.gd
# ------------------------------------------------------------------------------
• _ready() — Инициализация детектора взаимодействия
• _on_body_entered(body) — Обработчик входа тела
• _on_body_exited(body) — Обработчик выхода тела

# ------------------------------------------------------------------------------
# Scripts/entitis/Player/state/PlayerAimState.gd
# class_name: PlayerAimState
# ------------------------------------------------------------------------------
• enter() — Вход в состояние прицеливания
• _create_aiming_visual() — Создание визуала прицеливания
• _on_target_confirmed(target_data) — Обработчик подтверждения цели
• _on_target_cancelled() — Обработчик отмены цели
• _confirm_immediate() — Немедленное подтверждение
• exit() — Выход из состояния

# ------------------------------------------------------------------------------
# Scripts/entitis/Player/state/PlayerCastState.gd
# class_name: PlayerCastState
# ------------------------------------------------------------------------------
• enter() — Вход в состояние casts
• process(delta) — Обработка состояния
• _finish_cast() — Завершение заклинания
• _can_cast() — Проверка возможности casts
• exit() — Выход из состояния
• get_allowed_transitions() — Получение разрешённых переходов

# ------------------------------------------------------------------------------
# Scripts/entitis/ProgressionComponent.gd
# class_name: ProgressionComponent
# Signals: level_up, experience_gained, stat_changed
# ------------------------------------------------------------------------------
• _ready() — Инициализация компонента прогрессии
• add_experience(amount, source) — Добавление опыта
• _level_up() — Повышение уровня
• _calculate_next_level_exp() — Расчёт опыта для следующего уровня
• _apply_level_up_stats() — Применение статов при повышении уровня

# ------------------------------------------------------------------------------
# Scripts/entitis/ResourceComponent.gd
# class_name: ResourceComponent
# Signals: changed, depleted, replenished
# ------------------------------------------------------------------------------
• _ready() — Инициализация компонента ресурса
• _process(delta) — Обработка каждый кадр
• _on_resource_changed(new_value, old_value, max_value) — Обработчик изменения ресурса
• use(amount) — Использование ресурса
• can_afford(amount) — Проверка доступности ресурса
• add(amount) — Добавление ресурса
• set_max(value) — Установка максимума ресурса

# ------------------------------------------------------------------------------
# Scripts/entitis/states/AttackState.gd
# class_name: AttackState
# ------------------------------------------------------------------------------
• enter() — Вход в состояние атаки
• _get_attack_direction() — Получение направления атаки
• _open_combo_window() — Открытие окна комбо
• _on_combo_window_ready() — Обработчик готовности окна комбо
• process(delta) — Обработка состояния
• physics_process(delta) — Физическая обработка

# ------------------------------------------------------------------------------
# Scripts/entitis/states/BlockState.gd
# class_name: BlockState
# ------------------------------------------------------------------------------
• enter() — Вход в состояние блока
• physics_process(_delta) — Физическая обработка
• process(_delta) — Обработка состояния
• handle_command(command, data) — Обработка команд
• _has_stamina_for_block() — Проверка выносливости для блока
• _break_block() — Пролом блока
• _end_block() — Завершение блока
• exit() — Выход из состояния
• can_exit() — Проверка возможности выхода
• get_allowed_transitions() — Получение разрешённых переходов

# ------------------------------------------------------------------------------
# Scripts/entitis/states/CombatState.gd
# class_name: CombatState
# Signal: transition_requested
# ------------------------------------------------------------------------------
• setup_params() — Настройка параметров
• enter() — Вход в состояние
• exit() — Выход из состояния
• process(delta) — Обработка состояния
• physics_process(delta) — Физическая обработка
• can_exit() — Проверка возможности выхода
• get_allowed_transitions() — Получение разрешённых переходов
• handle_command(command, data) — Обработка команд
• set_battle_velocity(v) — Установка скорости боя
• apply_movement() — Применение движения
• get_attack_direction() — Получение направления атаки

# ------------------------------------------------------------------------------
# Scripts/entitis/states/DodgeState.gd
# class_name: DodgeState
# ------------------------------------------------------------------------------
• enter() — Вход в состояние уклонения
• physics_process(_delta) — Физическая обработка
• process(delta) — Обработка состояния
• handle_command(command, data) — Обработка команд
• exit() — Выход из состояния
• can_exit() — Проверка возможности выхода
• get_allowed_transitions() — Получение разрешённых переходов

# ------------------------------------------------------------------------------
# Scripts/entitis/states/IdleState.gd
# class_name: IdleState
# ------------------------------------------------------------------------------
• enter() — Вход в состояние бездействия
• _get_horizontal_direction() — Получение горизонтального направления
• physics_process(_delta) — Физическая обработка
• handle_command(command, data) — Обработка команд
• get_allowed_transitions() — Получение разрешённых переходов

# ------------------------------------------------------------------------------
# Scripts/entitis/states/StunState.gd
# class_name: StunState
# ------------------------------------------------------------------------------
• enter() — Вход в состояние оглушения
• set_knockback(direction, distance) — Установка отбрасывания
• process(delta) — Обработка состояния
• physics_process(delta) — Физическая обработка
• handle_command(_command, _data) — Обработка команд
• exit() — Выход из состояния
• can_exit() — Проверка возможности выхода
• get_allowed_transitions() — Получение разрешённых переходов
• _apply_stun_effect() — Применение эффекта оглушения

# ------------------------------------------------------------------------------
# Scripts/entitis/states/WalkState.gd
# class_name: WalkState
# ------------------------------------------------------------------------------
• physics_process(delta) — Физическая обработка
• handle_command(command, data) — Обработка команд
• get_allowed_transitions() — Получение разрешённых переходов
• _handle_movement(input_vector, delta) — Обработка движения
• _handle_stop_movement(delta) — Обработка остановки
• _get_horizontal_direction(input_vector) — Получение горизонтального направления

# ------------------------------------------------------------------------------
# Scripts/resources/AbilityResource.gd
# class_name: AbilityResource
# ------------------------------------------------------------------------------
• load_assets() — Загрузка ассетов способности
• get_damage_data() — Получение данных урона
• can_afford(health, mana, stamina) — Проверка доступности ресурсов
• get_aiming_visual_scene() — Получение сцены визуала прицеливания

# ------------------------------------------------------------------------------
# Scripts/resources/ActorData.gd
# class_name: ActorData
# ------------------------------------------------------------------------------
• add_decision_trigger(trigger) — Добавление триггера решения
• remove_decision_trigger(trigger) — Удаление триггера решения
• clear_decision_triggers() — Очистка триггеров решений
• has_decision_triggers() — Проверка наличия триггеров
• get_save_data() — Получение данных для сохранения
• load_save_data(data) — Загрузка данных сохранения

# ------------------------------------------------------------------------------
# Scripts/resources/DamageData.gd
# class_name: DamageData
# Signals: damage_calculated, damage_crit
# ------------------------------------------------------------------------------
• duplicate_data() — Дублирование данных урона
• get_damage_type_name() — Получение названия типа урона
• is_physical() — Проверка физического урона
• is_magical() — Проверка магического урона
• is_true_damage() — Проверка чистого урона
• _to_string() — Строковое представление

# ------------------------------------------------------------------------------
# Scripts/resources/DecisionTrigger.gd
# class_name: DecisionTrigger
# ------------------------------------------------------------------------------
• get_trigger_key() — Получение ключа триггера

# ------------------------------------------------------------------------------
# Scripts/resources/EntityData.gd
# class_name: EntityData
# Signals: health_changed, mana_changed, stamina_changed, stat_changed, level_changed, experience_changed, died
# ------------------------------------------------------------------------------
• set_current_hp(value) — Установка текущего HP
• set_current_mp(value) — Установка текущего MP
• set_current_stamina(value) — Установка текущей выносливости
• set_stat(stat_name, value) — Установка стата
• set_level(value) — Установка уровня
• set_experience(value) — Установка опыта
• use_stamina(amount) — Использование выносливости

# ------------------------------------------------------------------------------
# Scripts/resources/ItemResource.gd
# class_name: ItemResource
# ------------------------------------------------------------------------------
• _init(p_id, p_name) — Инициализация предмета

# ------------------------------------------------------------------------------
# Scripts/resources/PlayerData.gd
# class_name: PlayerData
# ------------------------------------------------------------------------------
• set_ability_slot_assignment(slot_index, ability_id) — Установка привязки способности к слоту
• can_dodge() — Проверка возможности уклонения
• calculate_blocked_damage(incoming_damage) — Расчёт заблокированного урона
• can_block() — Проверка возможности блока
• get_save_data() — Получение данных для сохранения
• _get_inventory_from_component() — Получение инвентаря из компонента
• load_save_data(data) — Загрузка данных сохранения
• _serialize_inventory() — Сериализация инвентаря

# ------------------------------------------------------------------------------
# Scripts/resources/RelationshipData.gd
# class_name: RelationshipData
# Signals: trust_changed, will_changed
# ------------------------------------------------------------------------------
• _init() — Инициализация данных отношений
• get_trust_percentage() — Получение процента доверия
• is_trust_positive() — Проверка положительности доверия
• is_trust_negative() — Проверка отрицательности доверия
• has_flag(flag_name) — Проверка наличия флага
• add_flag(flag_name) — Добавление флага
• remove_flag(flag_name) — Удаление флага

# ------------------------------------------------------------------------------
# Scripts/ui/GameMenu.gd
# ------------------------------------------------------------------------------
• _ready() — Инициализация игрового меню
• _input(event) — Обработка ввода
• _on_game_state_changed(new_state, old_state) — Обработчик изменения состояния игры
• _open_menu(previous_state) — Открытие меню
• _close_menu() — Закрытие меню
• _close_menu_immediate() — Немедленное закрытие меню
• show_main_menu() — Показ главного меню
• hide_all_panels() — Скрытие всех панелей
• _on_inventory_pressed() — Обработчик нажатия инвентаря

# ------------------------------------------------------------------------------
# Scripts/ui/InventoryPanel.gd
# ------------------------------------------------------------------------------
• _ready() — Инициализация панели инвентаря
• setup(inv) — Настройка панели с инвентарём
• refresh() — Обновление отображения
• _on_item_selected(index) — Обработчик выбора предмета
• _on_use_pressed() — Обработчик использования предмета
• _on_drop_pressed() — Обработчик выброса предмета
• _on_close_pressed() — Обработчик закрытия
• _on_back_pressed() — Обработчик возврата

# ------------------------------------------------------------------------------
# Scripts/ui/LoadMenu.gd
# ------------------------------------------------------------------------------
• _ready() — Инициализация меню загрузки
• refresh_save_list() — Обновление списка сохранений
• _on_item_selected(_index) — Обработчик выбора элемента
• _on_load_pressed() — Обработчик загрузки
• _on_delete_pressed() — Обработчик удаления
• _on_back_pressed() — Обработчик возврата

# ------------------------------------------------------------------------------
# Scripts/ui/MainMenu.gd
# ------------------------------------------------------------------------------
• _ready() — Инициализация главного меню
• _start_music() — Запуск музыки
• _fade_out_music() — Затухание музыки
• _on_new_game_pressed() — Обработчик новой игры
• _on_load_pressed() — Обработчик загрузки
• _on_settings_pressed() — Обработчик настроек
• _on_quit_pressed() — Обработчик выхода
• _on_quit_confirmed() — Обработчик подтверждения выхода
• show_main_menu() — Показ главного меню

# ------------------------------------------------------------------------------
# Scripts/ui/PauseMenu.gd
# ------------------------------------------------------------------------------
• _ready() — Инициализация меню паузы
• _unhandled_input(event) — Обработка необработанного ввода
• toggle_pause() — Переключение паузы
• show_menu() — Показ меню
• hide_menu() — Скрытие меню
• _center_panel() — Центрирование панели
• _on_resume_pressed() — Обработчик продолжения
• _on_settings_pressed() — Обработчик настроек
• _on_save_pressed() — Обработчик сохранения
• _on_load_pressed() — Обработчик загрузки
• _on_quit_pressed() — Обработчик выхода

# ------------------------------------------------------------------------------
# Scripts/ui/SettingsMenu.gd
# ------------------------------------------------------------------------------
• _ready() — Инициализация меню настроек
• _setup_controls() — Настройка элементов управления
• load_settings() — Загрузка настроек
• _on_master_volume_changed(value) — Обработчик изменения общей громкости
• _on_music_volume_changed(value) — Обработчик изменения громкости музыки
• _on_sfx_volume_changed(value) — Обработчик изменения громкости эффектов
• _on_apply_pressed() — Обработчик применения настроек

# ------------------------------------------------------------------------------
# Scripts/ui/Splash.gd
# ------------------------------------------------------------------------------
• _ready() — Инициализация заставки
• _input(event) — Обработка ввода
• _start_splash_sequence() — Запуск последовательности заставки
• _wait_with_skip(time) — Ожидание с возможностью пропуска
• _skip_splash() — Пропуск заставки
• _finish_and_exit() — Завершение и выход
• _resize_logo() — Изменение размера логотипа

# ------------------------------------------------------------------------------
# Scripts/ui/StatsPanel.gd
# ------------------------------------------------------------------------------
• _ready() — Инициализация панели статистики
• _on_visibility_changed() — Обработчик изменения видимости
• _find_player_components() — Поиск компонентов игрока
• _connect_component_signals() — Подключение сигналов компонентов
• _disconnect_component_signals() — Отключение сигналов компонентов
• update_data() — Обновление данных

# ================================================================================
# КОНЕЦ ДОКУМЕНТА
# ================================================================================
