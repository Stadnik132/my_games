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
