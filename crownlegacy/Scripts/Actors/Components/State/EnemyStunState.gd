# enemy_stun_state.gd
class_name EnemyStunState extends EnemyCombatState

@export var stun_duration: float = 0.5
@export var stun_color: Color = Color.WHITE  # Цвет во время стана (белый)

var stun_timer: float = 0.0
var original_modulate: Color  # Запоминаем исходный цвет

func enter() -> void:
	stun_timer = 0.0
	actor.velocity = Vector2.ZERO
	
	# Сохраняем исходный цвет и меняем на белый
	if actor.sprite:
		original_modulate = actor.sprite.modulate
		actor.sprite.modulate = stun_color

func process(delta: float) -> void:
	stun_timer += delta
	
	# Возвращаем исходный цвет перед выходом
	if stun_timer >= stun_duration - 0.1 and actor.sprite:
		actor.sprite.modulate = original_modulate
	
	if stun_timer >= stun_duration:
		transition_requested.emit("IDLE")

func exit() -> void:
	# На всякий случай возвращаем цвет при выходе
	if actor.sprite:
		actor.sprite.modulate = original_modulate
