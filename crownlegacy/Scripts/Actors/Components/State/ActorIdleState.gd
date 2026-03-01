# enemy_idle_state.gd
class_name ActorIdleState extends ActorCombatState
## Состояние ожидания. Враг стоит на месте и ждёт.

func enter() -> void:
	# Останавливаем движение
	actor.velocity = Vector2.ZERO
	
	# Здесь можно проиграть анимацию idle, если есть
	# Например: actor.play_animation("idle")

# EnemyIdleState.gd
func process(delta: float) -> void:
	if not brain:
		print_debug("IdleState: brain is null")
		return
	
	var should_move = brain.should_move_to_player()
	var should_attack = brain.should_attack()
	
	print_debug("IdleState: should_move=", should_move, " should_attack=", should_attack)
	
	if should_move:
		print_debug("IdleState: ЗАПРАШИВАЮ переход в MOVE")
		transition_requested.emit("MOVE")
	elif should_attack:
		print_debug("IdleState: ЗАПРАШИВАЮ переход в ATTACK")
		transition_requested.emit("ATTACK")
