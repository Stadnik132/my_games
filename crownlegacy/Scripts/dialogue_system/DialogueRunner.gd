extends Node

signal started(timeline_name)
signal finished()
signal node_reached(node_id, node_type)

var _nodes: Dictionary = {}
var _current_id: String = ""
var _is_running: bool = false
var _ui_scene: PackedScene = null
var _ui_instance: Node = null
var _pause_mode_backup: int = -1
var _player_level: int = 1

func _ready():
	_ui_scene = preload("res://Scenes/UI/dialogue/DialogueUI.tscn")
	EventBus.Game.dialogue_requested.connect(_on_dialogue_requested)
	EventBus.Player.level_up.connect(_on_player_level_up)

func _on_dialogue_requested(timeline_name: String) -> void:
	start(timeline_name)

func _on_player_level_up(new_level: int, _stat_increases: Dictionary) -> void:
	_player_level = new_level

func start(timeline_name: String) -> void:
	if _is_running:
		return

	var path = "res://dialogues/" + timeline_name + ".json"
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("DialogueRunner: cannot open ", path)
		return

	var text = file.get_as_text()
	file.close()

	var json = JSON.parse_string(text)
	if not json or not json.has("nodes"):
		push_error("DialogueRunner: invalid JSON in ", path)
		return

	_nodes = {}
	for n in json.nodes:
		_nodes[n.id] = n

	_is_running = true
	_show_ui()
	started.emit(timeline_name)
	EventBus.Dialogue.started.emit(timeline_name, null)

	var entry_id = _find_entry_node()
	if entry_id.is_empty():
		push_error("DialogueRunner: no entry point in ", timeline_name)
		_stop()
		return

	_execute(entry_id)

func _find_entry_node() -> String:
	for id in _nodes:
		if _nodes[id].get("is_entry_point", false):
			return id
	for id in _nodes:
		if _nodes[id].type == "start":
			return id
	return ""

func _execute(node_id: String) -> void:
	if not _is_running or not _nodes.has(node_id):
		_stop()
		return

	_current_id = node_id
	var node = _nodes[node_id]
	var type = node.type

	node_reached.emit(node_id, type)

	match type:
		"start":
			_follow_or_choose(node)
		"end":
			_stop()
		"line":
			_show_line(node)
		"choice":
			_follow_or_choose(node)
		"command":
			_execute_command(node)
			if _is_running:
				_follow_or_choose(node)
		"condition":
			_evaluate_condition(node)
		"event":
			var event_name = node.get("event_name", "")
			if not event_name.is_empty():
				EventBus.Dialogue.custom_event.emit(event_name)
			_follow_or_choose(node)
		_:
			push_warning("DialogueRunner: unknown node type ", type)
			_follow_or_choose(node)

func _show_line(node: Dictionary) -> void:
	var char_name = node.get("character", "")
	var text = node.get("text", "")
	var emotion = node.get("emotion", "default")
	if not _ui_instance:
		_follow_or_choose(node)
		return
	_ui_instance.show_line(char_name, text, emotion)
	var ui = _ui_instance
	await ui.confirmed
	if not is_instance_valid(ui) or ui != _ui_instance:
		return
	ui.hide_text()
	_follow_or_choose(node)

func _show_choices(node: Dictionary) -> void:
	var targets = node.get("connections", [])
	var options = []
	var found_showable = false
	for target_id in targets:
		if _nodes.has(target_id):
			var n = _nodes[target_id]
			if n.type == "choice" or n.type == "line":
				options.append(n)
				found_showable = true
	if not found_showable:
		for target_id in targets:
			if _nodes.has(target_id):
				options.append(_nodes[target_id])

	if _ui_instance and options.size() > 0:
		var ui = _ui_instance
		ui.show_choices(options)
		var idx = await ui.choice_selected
		if not is_instance_valid(ui) or ui != _ui_instance:
			return
		ui.hide_choices()
		if not _is_running:
			return
		var label = options[idx].get("choice_text", "") if idx >= 0 and idx < options.size() else ""
		EventBus.Dialogue.choice_selected.emit(idx, label)
		if idx >= 0 and idx < targets.size():
			_execute(targets[idx])
			return

	_follow_connections(node, 0)

func _evaluate_condition(node: Dictionary) -> void:
	var expr = node.get("condition", "")
	var is_true = _check_condition(expr)

	var true_targets = node.get("connections_true", [])
	var false_targets = node.get("connections_false", [])
	var all_connections = node.get("connections", [])

	if is_true:
		if true_targets.size() > 0:
			_execute(true_targets[0])
			return
	elif false_targets.size() > 0:
		_execute(false_targets[0])
		return

	if all_connections.size() > 0:
		_follow_connections(node, 0)
	else:
		_stop()

func _check_condition(expr: String) -> bool:
	if expr.is_empty():
		return true

	expr = expr.strip_edges()

	if " >= " in expr:
		var parts = expr.split(" >= ")
		return _get_value(parts[0]) >= int(parts[1])
	elif " <= " in expr:
		var parts = expr.split(" <= ")
		return _get_value(parts[0]) <= int(parts[1])
	elif " > " in expr:
		var parts = expr.split(" > ")
		return _get_value(parts[0]) > int(parts[1])
	elif " < " in expr:
		var parts = expr.split(" < ")
		return _get_value(parts[0]) < int(parts[1])
	elif " == " in expr:
		var parts = expr.split(" == ")
		return _get_value(parts[0]) == parts[1].strip_edges().trim_prefix('"').trim_suffix('"')
	elif " != " in expr:
		var parts = expr.split(" != ")
		return _get_value(parts[0]) != parts[1].strip_edges().trim_prefix('"').trim_suffix('"')
	elif expr.begins_with("flag:"):
		var flag_name = expr.substr(5).strip_edges()
		return GameFlags.is_flag_true(flag_name)
	elif expr.begins_with("!"):
		return not _check_condition(expr.substr(1))

	return _get_value(expr) as bool

func _get_value(key: String) -> Variant:
	key = key.strip_edges()
	match key:
		"trust":
			return RelationshipManager.get_trust_level()
		"will":
			return RelationshipManager.get_will_power()
		"level":
			return _player_level
		_:
			if key.begins_with("flag:"):
				return GameFlags.is_flag_true(key.substr(5).strip_edges())
			if key.is_valid_int():
				return int(key)
			if key.is_valid_float():
				return float(key)
			return key

func _execute_command(node: Dictionary) -> void:
	var cmd = node.get("command_name", "").strip_edges()
	var args = node.get("command_args", {})

	if cmd.is_empty():
		return

	match cmd:
		"trust":
			var amount = int(args.get("amount", 0))
			RelationshipManager.change_trust(amount, "dialogue")
			EventBus.Dialogue.change_trust.emit(amount)
		"will":
			var amount = int(args.get("amount", 1))
			RelationshipManager.use_will(amount)
			EventBus.Dialogue.use_will.emit(amount)
		"flag":
			var name = str(args.get("name", ""))
			var value = args.get("value", true)
			GameFlags.set_flag(name, value, "dialogue")
			EventBus.Dialogue.set_flag.emit(name, value)
		"battle", "combat":
			var npcs = args.get("npcs", [])
			EventBus.Dialogue.start_battle.emit(npcs)
			EventBus.Combat.decision.dialogue_decision.emit("to_combat")
		"world":
			EventBus.Game.world_requested.emit()
			_stop()
		"wait":
			var seconds = float(args.get("seconds", 1.0))
			var tween = create_tween()
			tween.tween_interval(seconds)
			await tween.finished
			if not is_instance_valid(self):
				return
			if not _is_running:
				return
		"goto":
			var timeline = str(args.get("timeline", ""))
			if not timeline.is_empty():
				_stop(false)
				start(timeline)
		"quest":
			var name = str(args.get("name", ""))
			var step = int(args.get("step", 1))
			EventBus.Dialogue.set_flag.emit("quest_" + name, step)
		"set_var":
			var name = str(args.get("name", ""))
			var value = args.get("value", "")
			EventBus.Dialogue.set_flag.emit(name, value)
		"fade_in":
			var duration = float(args.get("duration", 1.5))
			var fade_rect = _find_fade_rect()
			if fade_rect:
				var tween = create_tween()
				tween.tween_property(fade_rect, "color", Color(0, 0, 0, 0), duration)
				await tween.finished
				if not is_instance_valid(self):
					return
			_ui_instance.hide_all() if _ui_instance else null
		"game_over":
			EventBus.Game.game_over_requested.emit()
			_stop()
		"end":
			_stop()
		_:
			EventBus.Dialogue.custom_event.emit(cmd)

func _follow_or_choose(node: Dictionary) -> void:
	var connections = node.get("connections", [])
	if connections.size() <= 1:
		_follow_connections(node, 0)
	else:
		_show_choices(node)

func _follow_connections(node: Dictionary, index: int) -> void:
	var connections = node.get("connections", [])
	if index < connections.size():
		_execute(connections[index])
	else:
		_stop()

func _show_ui() -> void:
	if not _ui_instance and _ui_scene:
		_ui_instance = _ui_scene.instantiate()
		get_tree().current_scene.add_child(_ui_instance)
	_pause_mode_backup = get_tree().paused
	get_tree().paused = true

func _hide_ui() -> void:
	if _ui_instance:
		_ui_instance.queue_free()
		_ui_instance = null
	if _pause_mode_backup >= 0:
		get_tree().paused = _pause_mode_backup
		_pause_mode_backup = -1

func _stop(emit_finished: bool = true) -> void:
	_is_running = false
	_current_id = ""
	_nodes.clear()
	_hide_ui()
	if emit_finished:
		finished.emit()
		EventBus.Dialogue.ended.emit()

func is_running() -> bool:
	return _is_running

func get_current_node_id() -> String:
	return _current_id

func _find_fade_rect() -> ColorRect:
	var scene = get_tree().current_scene
	if not scene:
		return null
	var overlay = scene.get_node_or_null("OverlayUI")
	if overlay:
		return overlay.get_node_or_null("FadeRect") as ColorRect
	return null
