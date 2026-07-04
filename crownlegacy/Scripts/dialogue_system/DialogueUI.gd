extends CanvasLayer

signal confirmed
signal choice_selected(index: int)

var _typing_timer: Timer
var _current_text: String = ""
var _typing_char_index: int = 0
var _typing_speed: float = 0.03
var _punctuation_pause_long: float = 0.6
var _punctuation_pause_short: float = 0.25
var _can_confirm: bool = false
var _choice_buttons: Array = []

@onready var name_bg: Panel = $DialoguePanel/NameBg
@onready var name_label: RichTextLabel = $DialoguePanel/NameBg/NameLabel
@onready var text_label: RichTextLabel = $DialoguePanel/TextLabel
@onready var choices_container: VBoxContainer = $DialoguePanel/ChoicesContainer
@onready var continue_hint: Label = $DialoguePanel/ContinueHint


func _ready():
	hide_all()
	_typing_timer = Timer.new()
	_typing_timer.timeout.connect(_on_typing_tick)
	_typing_timer.one_shot = false
	add_child(_typing_timer)
	process_mode = ProcessMode.PROCESS_MODE_WHEN_PAUSED

func _input(event):
	if not _can_confirm:
		return
	if event.is_action_pressed("dialogue_confirm") or event.is_action_pressed("ui_select"):
		get_viewport().set_input_as_handled()
		if _typing_timer.is_stopped() == false:
			_complete_typing()
		else:
			_can_confirm = false
			continue_hint.hide()
			confirmed.emit()

func show_line(char_name: String, text: String, _emotion: String = "default"):
	hide_all()
	if not char_name.is_empty():
		name_label.text = "[b]" + char_name + "[/b]"
		name_bg.show()
	else:
		name_bg.hide()
	_current_text = text
	_typing_char_index = 0
	text_label.text = ""
	text_label.show()
	_can_confirm = false
	continue_hint.hide()
	_typing_timer.start(_typing_speed)

func _on_typing_tick():
	if _typing_char_index < _current_text.length():
		text_label.text += _current_text[_typing_char_index]
		_typing_char_index += 1
		var ch = _current_text[_typing_char_index - 1]
		if ch in ".!?":
			_typing_timer.start(_punctuation_pause_long)
		elif ch in ",;:—\n":
			_typing_timer.start(_punctuation_pause_short)
		else:
			_typing_timer.start(_typing_speed)
	else:
		_typing_timer.stop()
		_can_confirm = true
		continue_hint.show()

func _complete_typing():
	_typing_timer.stop()
	text_label.text = _current_text
	_typing_char_index = _current_text.length()
	_can_confirm = true
	continue_hint.show()

func show_choices(choice_nodes: Array):
	hide_all()
	for child in choices_container.get_children():
		child.queue_free()
	_choice_buttons.clear()
	for i in range(choice_nodes.size()):
		var node = choice_nodes[i]
		var btn = Button.new()
		btn.text = node.get("choice_text", "Choice " + str(i + 1))
		btn.pressed.connect(_on_choice_pressed.bind(i))
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.custom_minimum_size = Vector2(400, 36)
		btn.add_theme_font_size_override("font_size", 20)
		btn.add_theme_color_override("font_color", Color(0.88, 0.88, 0.95))
		btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		btn.add_theme_color_override("font_pressed_color", Color(0.6, 0.8, 1))
		btn.add_theme_stylebox_override("normal", _make_choice_style(Color(0.08, 0.08, 0.12, 0.8), Color(0.3, 0.3, 0.4)))
		btn.add_theme_stylebox_override("hover", _make_choice_style(Color(0.12, 0.12, 0.18, 0.9), Color(0.5, 0.6, 0.8)))
		btn.add_theme_stylebox_override("pressed", _make_choice_style(Color(0.06, 0.06, 0.1, 0.9), Color(0.3, 0.5, 0.7)))
		choices_container.add_child(btn)
		_choice_buttons.append(btn)
	choices_container.show()

func _make_choice_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color = border
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_right = 4
	s.corner_radius_bottom_left = 4
	s.content_margin_left = 16
	s.content_margin_top = 6
	s.content_margin_right = 16
	s.content_margin_bottom = 6
	return s

func _on_choice_pressed(index: int):
	hide_all()
	choice_selected.emit(index)

func hide_text():
	name_bg.hide()
	text_label.hide()
	continue_hint.hide()
	if _typing_timer:
		_typing_timer.stop()

func hide_choices():
	for child in choices_container.get_children():
		child.queue_free()
	_choice_buttons.clear()
	choices_container.hide()

func hide_all():
	name_bg.hide()
	text_label.hide()
	continue_hint.hide()
	choices_container.hide()
