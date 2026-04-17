extends Node

var _items: Dictionary = {}

signal registry_updated(item_count: int)

func _ready() -> void:
	await get_tree().process_frame
	_register_all_items()

func _register_all_items() -> void:
	_items.clear()
	
	var items_path = "res://Scripts/resources/Items/"
	
	if not DirAccess.dir_exists_absolute(items_path):
		push_warning("ItemRegistry: папка не найдена: ", items_path)
		return
	
	var dir = DirAccess.open(items_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if _is_item_file(file_name):
				var full_path = items_path + file_name
				_register_item_from_file(full_path)
			file_name = dir.get_next()
		
		registry_updated.emit(_items.size())

func _is_item_file(file_name: String) -> bool:
	return file_name.ends_with(".tres") or file_name.ends_with(".res")

func _register_item_from_file(path: String) -> void:
	var item = load(path) as ItemResource
	
	if not item:
		push_warning("ItemRegistry: файл не является ItemResource: ", path)
		return
	
	if not item.id or item.id.is_empty():
		push_warning("ItemRegistry: предмет без ID: ", path)
		return
	
	if _items.has(item.id):
		var existing = _items[item.id]
		push_warning("ItemRegistry: дубликат ID '", item.id, "'!\n",
					"  Первый: ", existing.resource_path, "\n",
					"  Второй: ", path)
		return
	
	_items[item.id] = item

func get_item(item_id: String) -> ItemResource:
	if _items.has(item_id):
		return _items[item_id]
	
	push_error("ItemRegistry: предмет не найден: ", item_id)
	return null

func has_item(item_id: String) -> bool:
	return _items.has(item_id)

func get_all_items() -> Array[ItemResource]:
	return _items.values()

func get_items_by_type(item_type: ItemResource.ItemType) -> Array[ItemResource]:
	var result = []
	for item in _items.values():
		if item.item_type == item_type:
			result.append(item)
	return result

func get_item_count() -> int:
	return _items.size()
