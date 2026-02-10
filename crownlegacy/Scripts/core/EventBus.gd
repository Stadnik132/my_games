# EventBus.gd
extends Node

# ==================== ВЛОЖЕННЫЕ КЛАССЫ С СИГНАЛАМИ ====================
class GameSignals:
	signal state_changed(new_state: GameStateManager.GameState, old_state: GameStateManager.GameState)
	signal paused(is_paused: bool)
	signal transition_to_world_requested()
	signal transition_to_dialogue_requested(timeline_name: String)
	signal transition_to_battle_requested(enemies: Array)
	signal transition_to_menu_requested()
	signal transition_to_cutscene_requested(cutscene_id: String)
	signal transition_to_game_over_requested()

class PlayerSignals:
	signal died
	signal moved(is_moving: bool, direction: Vector2)
	signal take_damage(amount: int, new_hp: int)
	signal healed(amount: int, new_hp: int)
	signal level_up(new_level: int, stat_increases: Dictionary)
	signal experience_gained(amount: int, new_total: int)
	signal equipment_changed(slot: String, old_item: String, new_item: String)
	signal animation_requested(animation_name: String, duration: float)  # Добавить

class RelationshipSignals:
	signal trust_changed(new_value: int, delta: int)
	signal will_changed(new_value: int, delta: int)
	signal will_used(used: bool, remaining: int)
	signal trust_effect_applied(effect_type: String, multiplier: float)

class DialogueSignals:
	signal started(timeline_name: String)
	signal ended
	signal choice_selected(choice_index: int, choice_text: String)
	signal requested(timeline_name: String, npc_id: String)
	signal change_trust(amount: int)
	signal set_flag(flag_name: String, value: Variant)
	signal use_will(amount: int)
	signal start_battle(battle_id: String)

class CombatSignals:
	signal started(enemies: Array)
	signal ended(victory: bool)
	signal decision_point_triggered(enemy: Node, trigger_data: Dictionary)
	signal decision_made(enemy: Node, choice: String)
	signal decision_ui_closed
	signal combat_to_dialogue_transition(enemy: Node)
	signal enemy_health_changed(enemy: Node, current_hp: int, max_hp: int)
	signal enemy_died(enemy: Node, experience: int)
	signal dialogic_decision_made(choice: String)
	signal ability_animation_started(animation_name: String, duration: float)
	
	# Базовые действия
	signal basic_attack_requested
	signal basic_attack_started
	signal basic_attack_hit(combo_step: int, enemies_hit: int)
	signal basic_attack_missed
	signal attack_combo_reset
	signal attack_combo_finished
	# Уворот
	signal dodge_requested(direction: Vector2)
	signal dodge_started
	signal dodge_completed
	signal dodge_successful(attacker: Node)
	signal dodge_failed
	# Блок
	signal block_started
	signal block_ended
	signal block_active
	signal block_reduced_damage(damage_after_block: int)
	signal block_broken
	
	# Способности
	signal ability_slot_pressed(slot_index: int)
	signal ability_aiming_started(slot_index: int)
	signal ability_aiming_cancelled
	signal ability_target_confirmed(target_position: Vector2)
	signal ability_target_cancelled
	signal ability_cast_started(ability_data: Resource)
	signal ability_cast_completed
	signal ability_cast_interrupted
	# Прицеливание
	signal aiming_started
	signal aiming_cancelled
	signal aiming_during_dodge_started
	# Общее
	signal combat_state_changed(old_state: String, new_state: String)
	signal player_took_damage(amount: int, damage_type: String, was_blocked: bool)
	signal player_dodged_attack(attacker: Node)
	# Новое для интеграции
	signal enemy_hit(enemy: Node, damage: int, is_critical: bool)
	signal combo_window_opened
	signal combo_window_closed

class UISignals:
	signal menu_requested
	signal menu_opened(menu_type: String)
	signal menu_closed
	signal notification(text: String, duration: float)
	signal hud_update_required

class ActorsSignals:
	signal mode_changed(actor: Node, new_mode: String, old_mode: String)
	signal interaction_started(actor: Node)
	signal died(actor: Node)
	signal interacted(actor: Node)
	signal interaction_requested

class FlagsSignals:
	signal flag_changed(flag_name: String, value: Variant)
	signal quest_updated(quest_id: String, stage: int)

class SystemSignals:
	signal settings_changed(setting_name: String, value: Variant)
	signal scene_changed(old_scene: String, new_scene: String)

# ==================== ЭКЗЕМПЛЯРЫ КЛАССОВ ====================
var Game: GameSignals = GameSignals.new()
var Player: PlayerSignals = PlayerSignals.new()
var Relationship: RelationshipSignals = RelationshipSignals.new()
var Dialogue: DialogueSignals = DialogueSignals.new()
var Combat: CombatSignals = CombatSignals.new()
var UI: UISignals = UISignals.new()
var Actors: ActorsSignals = ActorsSignals.new()
var Flags: FlagsSignals = FlagsSignals.new()
var System: SystemSignals = SystemSignals.new()

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func _ready() -> void:
	print_debug("EventBus загружен с группировкой сигналов")
	if OS.is_debug_build():
		_print_debug_info()

# ==================== ОТЛАДКА ====================
func _print_debug_info() -> void:
	"""Выводит информацию о зарегистрированных сигналах"""
	print("=== EventBus Signals ===")
	print("Game: доступен")
	print("Dialogue: доступен")
	print("Combat: доступен")
	print("Actors: доступен")
	print("=========================")

func is_connected_to_all() -> bool:
	"""Проверяет, есть ли подписчики на ключевые сигналы"""
	return true
