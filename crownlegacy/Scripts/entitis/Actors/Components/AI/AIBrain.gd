# AIBrain.gd
extends Node
class_name AIBrain

# ==================== ТИПЫ РЕШЕНИЙ ====================
enum CombatDecision { 
	IDLE,    # Ничего не делать
	WALK,    # Двигаться к цели (было CHASE)
	ATTACK,  # Атаковать
	CAST     # Использовать способность (было ABILITY)
}

# ==================== ЭКСПОРТ ====================
@export var attack_range: float = 30.0           # Дистанция для атаки
@export var ability_usage_chance: float = 0.2    # Шанс использовать способность вместо атаки

# ==================== ССЫЛКИ ====================
var actor: Actor
var perception: AIPerception
var combat_component: ActorCombatComponent

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func setup(actor_node: Actor, perception_node: AIPerception, combat_node: ActorCombatComponent) -> void:
	actor = actor_node
	perception = perception_node
	combat_component = combat_node

# ==================== ОСНОВНАЯ ЛОГИКА ====================
func decide() -> Dictionary:
	"""
	Принимает решение на основе текущей ситуации.
	Возвращает словарь с полем "type" и дополнительными данными.
	"""
	# Если игрок не обнаружен - стоим
	if not perception.is_player_detected():
		return {"type": CombatDecision.IDLE}
	
	var dist = perception.get_distance_to_player()
	var player_pos = perception.get_player_position()
	
	# Если игрок дальше дистанции атаки - идем к нему
	if dist > attack_range:
		return {
			"type": CombatDecision.WALK,
			"target": player_pos
		}
	
	# Если игрок в радиусе атаки - решаем, что делать
	# Случайно выбираем: атака или способность
	if randf() < ability_usage_chance and combat_component.ability_component:
		# Пытаемся найти доступный слот со способностью
		var slot = _get_available_ability_slot()
		if slot >= 0:
			# Нашли - используем способность
			return {
				"type": CombatDecision.CAST,
				"slot": slot,
				"target": player_pos
			}
	
	# Если не выпала способность или нет доступных слотов - обычная атака
	return {
		"type": CombatDecision.ATTACK,
		"target": player_pos
	}

# ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ====================
func _get_available_ability_slot() -> int:
	if not combat_component.ability_component:
		print_debug("AIBrain: нет ability_component")
		return -1
	
	var ability_comp = combat_component.ability_component
	var available = []
	
	for i in range(ability_comp.slots.size()):
		var can_cast = ability_comp.can_cast_ability(i)
		if can_cast:
			available.append(i)
	
	if available.is_empty():
		print_debug("AIBrain: нет доступных слотов")
		return -1
	
	var chosen = available[randi() % available.size()]
	return chosen
