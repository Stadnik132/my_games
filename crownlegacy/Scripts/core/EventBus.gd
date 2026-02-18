extends Node

class GameSignals:
	signal state_changed(new_state: int, old_state: int)
	signal paused(is_paused: bool)
	signal world_requested()
	signal dialogue_requested(timeline_name: String)
	signal menu_requested()
	signal cutscene_requested(cutscene_id: String)
	signal game_over_requested()



class PlayerSignals:
	signal died
	signal moved(is_moving: bool, direction: Vector2)
	signal level_up(new_level: int, stat_increases: Dictionary)
	signal experience_gained(amount: int, new_total: int)
	signal equipment_changed(slot: String, old_item: String, new_item: String)
	signal animation_requested(animation_name: String, duration: float)
	signal damage_taken(amount: int, damage_type: String, source: Node, was_blocked: bool, is_critical: bool)
	signal hp_changed(new_hp: int, old_hp: int)
	signal mp_changed(new_mp: int, old_mp: int)
	signal stamina_changed(new_stamina: int, old_stamina: int)
	signal healed(amount: int, new_hp: int)

class RelationshipSignals:
	signal trust_changed(new_value: int, delta: int)
	signal will_changed(new_value: int, delta: int)
	signal will_used(amount: int, remaining: int)
	signal trust_effect_applied(effect_type: String, multiplier: float)


class DialogueSignals:
	signal started(timeline_name: String)
	signal ended
	signal choice_selected(choice_index: int, choice_text: String)
	signal requested(timeline_name: String, npc_id: String)
	signal change_trust(amount: int)
	signal set_flag(flag_name: String, value: Variant)
	signal use_will(amount: int)
	signal start_battle(npc_id: String)


class CombatSignals:
	signal started(enemies: Array)
	signal ended(victory: bool)
	signal decision_point_triggered(enemy: Node, trigger_data: Dictionary)
	signal decision_made(enemy: Node, choice: String)
	signal decision_ui_closed
	signal combat_to_dialogue_requested(enemy: Node)
	signal enemy_health_changed(enemy: Node, current_hp: int, max_hp: int)
	signal enemy_died(enemy: Node, experience: int)
	signal enemy_hit(enemy: Node, damage: int, is_critical: bool)
	signal dialogic_decision_made(choice: String)
	signal ability_animation_started(animation_name: String, duration: float)
	
	signal basic_attack_requested
	signal basic_attack_started
	signal basic_attack_hit(combo_step: int, enemies_hit: int)
	signal attack_combo_reset
	
	signal dodge_requested(direction: Vector2)
	signal dodge_started
	signal dodge_completed
	signal dodge_failed(reason: String)  # "insufficient_stamina", "cooldown", и т.д.
	
	signal block_started
	signal block_ended
	signal block_active
	signal block_reduced_damage(damage_after_block: int)
	signal block_broken
	
	signal ability_slot_pressed(slot_index: int)
	signal ability_aiming_started(slot_index: int)
	signal ability_target_confirmed(target_position: Vector2)
	signal ability_cast_started(ability: AbilityResource)
	signal ability_cast_completed()
	
	signal aiming_started
	signal aiming_cancelled
	
	signal combat_state_changed(old_state: String, new_state: String)
	signal player_stunned(is_stunned: bool)
	
	signal combo_window_opened
	signal combo_window_closed


class UISignals:
	signal menu_opened(menu_type: String)
	signal menu_closed
	signal notification(text: String, duration: float)
	signal hud_update_required


class ActorsSignals:
	signal mode_changed(actor: Node, new_mode: String, old_mode: String)
	signal interaction_started(actor: Node)
	signal died(actor: Node)
	signal interaction_requested


class FlagsSignals:
	signal flag_changed(flag_name: String, value: Variant)


class SystemSignals:
	signal settings_changed(setting_name: String, value: Variant)
	signal scene_changed(old_scene: String, new_scene: String)


var Game: GameSignals = GameSignals.new()
var Player: PlayerSignals = PlayerSignals.new()
var Relationship: RelationshipSignals = RelationshipSignals.new()
var Dialogue: DialogueSignals = DialogueSignals.new()
var Combat: CombatSignals = CombatSignals.new()
var UI: UISignals = UISignals.new()
var Actors: ActorsSignals = ActorsSignals.new()
var Flags: FlagsSignals = FlagsSignals.new()
var System: SystemSignals = SystemSignals.new()


func _ready() -> void:
	_clear_all_connections()
	
	print_debug("EventBus: инициализирован")
	if OS.is_debug_build():
		_print_debug_info()


func _clear_all_connections() -> void:
	var signal_groups = [
		Game, Player, Relationship, Dialogue,
		Combat, UI, Actors, Flags, System
	]
	
	for group in signal_groups:
		var signals_dict = group.get_signal_list()
		for signal_info in signals_dict:
			var signal_name = signal_info["name"] as StringName
			var connections = group.get_signal_connection_list(signal_name)
			for conn in connections:
				var method = conn["callable"]
				if group.is_connected(signal_name, method):
					group.disconnect(signal_name, method)


func _print_debug_info() -> void:
	print("=== EventBus [Активен] ===")
	print("Группы сигналов: Game, Player, Relationship, Dialogue, Combat, UI, Actors, Flags, System")
	print("============================")


# TODO: Система квестов — добавить сигнал quest_updated(quest_id, stage)
# TODO: Система крафта/инвентаря — добавить сигналы inventory_changed, item_used
# TODO: Система сохранений — добавить сигнал save_requested, load_completed
# TODO: Система достижений — добавить сигнал achievement_unlocked
# TODO: Полноценная система промахов/уклонений — добавить сигналы attack_missed, dodge_failed
# TODO: Система усилений/баффов — добавить сигнал buff_applied, buff_expired
