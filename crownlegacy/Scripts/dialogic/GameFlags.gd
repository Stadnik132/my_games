#GameFlags
extends Node

var flags: Dictionary = {}

func _ready() -> void:
	# Ждём один кадр
	await get_tree().process_frame
	
	# Отправляем все существующие флаги
	for flag_name in flags:
		EventBus.Flags.flag_changed.emit(flag_name, flags[flag_name])

func set_flag(flag_name: String, value: Variant = true) -> void:
	flags[flag_name] = value
	EventBus.flag_changed.emit(flag_name, value)

func get_flag(flag_name: String, default: Variant = false) -> Variant:
	return flags.get(flag_name, default)

func has_flag(flag_name: String) -> bool:
	return flags.has(flag_name) and bool(flags[flag_name])

func clear_flag(flag_name: String) -> void:
	flags.erase(flag_name)

func get_all_flags() -> Dictionary:
	return flags.duplicate()
	
	
