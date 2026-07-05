@tool
extends Sprite2D
class_name AsepriteSprite2D

@export_file("*.json") var sprite_json_path: String:
	set(path):
		sprite_json_path = path
		if Engine.is_editor_hint() or is_inside_tree():
			_parse_json()
			call_deferred("_generate_animations")

@export_node_path var animation_player_path: NodePath = NodePath("../AnimationPlayer")

@export var regenerate_animations: bool:
	set(v):
		_parse_json()
		call_deferred("_generate_animations")

var parsed_frames: Array[Dictionary] = []
var parsed_tags: Dictionary = {}
var _is_parsed: bool = false

func _init():
	_setup_anim_defs()

func _setup_anim_defs():
	var defs = {
		"idle_down": { "tag_only": "Idle_down" },
		"idle_up": { "tag_only": "idle_up" },
		"idle_left": { "tag_only": "idle_left" },
		"idle_right": { "tag_only": "Idle_right" },
		"walk_down": { "tag_only": "walk_down" },
		"walk_up": { "tag_only": "Walk_up" },
		"walk_left": { "tag_only": "Walk_left" },
		"walk_right": { "tag_only": "Walk_right" },
		"blink_down": { "tag_only": "blincing_down" },
		"blink_left": { "tag_only": "blinking_left" },
		"blink_right": { "tag_only": "blinking_right" },
		"idle_battle_left": { "tag_only": "LeftBattle" },
		"idle_battle_right": { "tag_only": "RightBattle" },
		"aiming": { "tag_only": "Aiming" },
		"cast": { "tag_only": "Cast" },
		"attack_left_1": { "tag_only": "idle_left", "placeholder": true },
		"attack_left_2": { "tag_only": "idle_left", "placeholder": true },
		"attack_left_3": { "tag_only": "idle_left", "placeholder": true },
		"attack_right_1": { "tag_only": "Idle_right", "placeholder": true },
		"attack_right_2": { "tag_only": "Idle_right", "placeholder": true },
		"attack_right_3": { "tag_only": "Idle_right", "placeholder": true },
		"dodge": { "tag_only": "idle_left", "placeholder": true },
		"block": { "tag_only": "LeftBattle", "placeholder": true },
		"stun": { "tag_only": "LeftBattle", "placeholder": true },
	}
	for name in defs:
		_anim_defs[name] = defs[name]
var _anim_defs: Dictionary = {}

func _ready():
	if Engine.is_editor_hint():
		return
	_parse_json()
	if _is_parsed:
		region_enabled = true
		region_rect = parsed_frames[0].rect if parsed_frames.size() > 0 else Rect2()
		_generate_animations()

func _extract_frame_num(key: String) -> int:
	var dot_pos = key.rfind(".")
	var name_part = key.substr(0, dot_pos) if dot_pos > 0 else key
	var space_pos = name_part.rfind(" ")
	if space_pos >= 0:
		return int(name_part.substr(space_pos + 1))
	return 0

func _parse_json():
	if sprite_json_path.is_empty():
		return
	parsed_frames.clear()
	parsed_tags.clear()
	_is_parsed = false
	var file = FileAccess.open(sprite_json_path, FileAccess.READ)
	if file == null:
		push_error("AsepriteSprite2D: Cannot open ", sprite_json_path)
		return
	var text = file.get_as_text()
	file.close()
	var json = JSON.parse_string(text)
	if json == null:
		push_error("AsepriteSprite2D: Invalid JSON in ", sprite_json_path)
		return
	var frames_data = json.get("frames", {})
	var keys = frames_data.keys()
	keys.sort_custom(func(a, b): return _extract_frame_num(a) < _extract_frame_num(b))
	for key in keys:
		var f = frames_data[key]
		var fr = f.get("frame", {})
		parsed_frames.append({
			"rect": Rect2(fr.x, fr.y, fr.w, fr.h),
			"duration": f.get("duration", 100) / 1000.0
		})
	var meta = json.get("meta", {})
	for tag in meta.get("frameTags", []):
		var name: String = tag.get("name", "")
		if not name.is_empty():
			parsed_tags[name] = {
				"from": tag.get("from", 0),
				"to": tag.get("to", 0),
				"direction": tag.get("direction", "forward")
			}
	_is_parsed = true
	print_debug("=== AsepriteSprite2D: PARSE ===")
	print_debug("Frames: ", parsed_frames.size())
	for tag_name in parsed_tags:
		var t = parsed_tags[tag_name]
		print_debug("  Tag '", tag_name, "': ", t.from, "-", t.to, " (", t.direction, ")")

func _generate_animations():
	if not _is_parsed or parsed_frames.is_empty():
		return
	var anim_player = get_node(animation_player_path) as AnimationPlayer
	if anim_player == null:
		return
	var lib: AnimationLibrary
	if anim_player.has_animation_library(""):
		lib = anim_player.get_animation_library("")
	else:
		lib = AnimationLibrary.new()
		anim_player.add_animation_library("", lib)
	var sprite_name = name
	print_debug("=== AsepriteSprite2D: GENERATE ===")
	for anim_name in _anim_defs:
		var def = _anim_defs[anim_name]
		var frames = _resolve_frames(def)
		if frames.is_empty():
			print_debug("  SKIP '", anim_name, "': no frames")
			continue
		print_debug("  Anim '", anim_name, "': frames ", frames, " (", def, ")")
		var anim = _create_animation(frames, sprite_name)
		if lib.has_animation(anim_name):
			lib.remove_animation(anim_name)
		lib.add_animation(anim_name, anim)
	# RESET animation — just first frame
	var reset = Animation.new()
	reset.length = 0.01
	if parsed_frames.size() > 0:
		var rt = reset.add_track(Animation.TYPE_VALUE)
		reset.track_set_path(rt, NodePath("%s:region_rect" % sprite_name))
		reset.track_insert_key(rt, 0.0, parsed_frames[0].rect)
	if lib.has_animation("RESET"):
		lib.remove_animation("RESET")
	lib.add_animation("RESET", reset)

func _resolve_frames(def_dict: Dictionary) -> Array:
	if def_dict.has("tag_only"):
		var tag_name: String = def_dict["tag_only"]
		if parsed_tags.has(tag_name):
			var tag = parsed_tags[tag_name]
			return _build_sequence(tag.from, tag.to, tag.direction)
		return []
	if def_dict.has("single_frame"):
		var idx = def_dict["single_frame"]
		if idx >= 0 and idx < parsed_frames.size():
			return [idx]
		return []
	var parent_name: String = def_dict.get("parent", "")
	var child_name: String = def_dict.get("child", "")
	if not parsed_tags.has(parent_name) or not parsed_tags.has(child_name):
		if def_dict.get("placeholder", false) and parsed_tags.has(parent_name):
			var tag = parsed_tags[parent_name]
			return _build_sequence(tag.from, tag.to, tag.direction)
		return []
	var parent = parsed_tags[parent_name]
	var child = parsed_tags[child_name]
	var from_idx = maxi(parent.from, child.from)
	var to_idx = mini(parent.to, child.to)
	if from_idx > to_idx:
		return []
	return _build_sequence(from_idx, to_idx, child.direction)

func _build_sequence(from_idx: int, to_idx: int, direction: String) -> Array:
	var frames: Array = []
	for i in range(from_idx, to_idx + 1):
		frames.append(i)
	match direction:
		"reverse":
			frames.reverse()
		"pingpong":
			var rev = frames.duplicate()
			rev.reverse()
			if frames.size() > 1:
				frames += rev.slice(1, rev.size() - 1)
	return frames

func _create_animation(frame_indices: Array, sprite_node_name: String) -> Animation:
	var anim = Animation.new()
	var track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath("%s:region_rect" % sprite_node_name))
	anim.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST)
	var elapsed: float = 0.0
	for idx in frame_indices:
		if idx < 0 or idx >= parsed_frames.size():
			continue
		var fd = parsed_frames[idx]
		elapsed += fd.duration
		var key = anim.track_insert_key(track, elapsed, fd.rect)
		anim.track_set_key_transition(track, key, 0.0)
	anim.length = elapsed
	anim.loop_mode = Animation.LOOP_LINEAR if frame_indices.size() > 1 else Animation.LOOP_NONE
	return anim

func get_frame_count() -> int:
	return parsed_frames.size()

func get_frame_rect(index: int) -> Rect2:
	if index >= 0 and index < parsed_frames.size():
		return parsed_frames[index].rect
	return Rect2()

func get_frame_duration(index: int) -> float:
	if index >= 0 and index < parsed_frames.size():
		return parsed_frames[index].duration
	return 0.0

func play(anim_name: String) -> void:
	var ap = get_node(animation_player_path) as AnimationPlayer
	if ap and ap.has_animation(anim_name):
		ap.play(anim_name)
