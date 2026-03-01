# PlayerInteractionDetector.gd
extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body is Actor:
		body.set_player_in_range(true)

func _on_body_exited(body: Node) -> void:
	if body is Actor:
		body.set_player_in_range(false)
