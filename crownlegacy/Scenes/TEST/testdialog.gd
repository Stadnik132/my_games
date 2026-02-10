# TestDialog.gd
extends Node2D

func _ready():
	print("=== ТЕСТОВАЯ СЦЕНА ===")
	
	# Ждём полной загрузки
	await get_tree().create_timer(1.0).timeout
	
	# 1. Проверяем Dialogic
	print("1. Dialogic:", "ЕСТЬ" if Dialogic else "НЕТ")
	
	if Dialogic:
		# 2. Пробуем запустить
		print("2. Запускаю 'guard_encounter'...")
		Dialogic.start("guard_encounter")
		
		# 3. Проверяем через время
		await get_tree().create_timer(2.0).timeout
		
		print("3. Проверка CanvasLayer:")
		var found = false
		for node in get_tree().root.get_children():
			if node is CanvasLayer:
				print("   - ", node.name)
				found = true
		
		if found:
			print("✅ CanvasLayer создан!")
		else:
			print("❌ CanvasLayer НЕ создан!")
			
			# 4. Проверяем директорию Dialogic
			print("4. Проверка файлов Dialogic:")
			var dir = DirAccess.open("res://dialogic/")
			if dir:
				dir.list_dir_begin()
				var file = dir.get_next()
				while file != "":
					print("   - ", file)
					file = dir.get_next()
