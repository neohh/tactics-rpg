class_name DataLoader
extends RefCounted

## DataLoader - Единый менеджер загрузки и сохранения JSON данных.
## Обеспечивает безопасное чтение/запись, логирование ошибок,
## бекапы критических файлов и нормализацию типов чисел (int vs float).

const INT_KEYS = [
	"team", "to", "next", "gold", "day", "hour", "food", "fatigue",
	"slot", "price", "gw", "gh", "sub", "ox", "oy",
	"level", "hp", "max_hp", "mp", "max_mp", "exp"
]

## Загрузка JSON с обработкой ошибок и возвратом дефолтного значения
static func load_json(path: String, default_value: Variant = {}) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("DataLoader.load_json: File not found: '%s'" % path)
		return default_value
	
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("DataLoader.load_json: Cannot open file '%s', error: %d" % [path, FileAccess.get_open_error()])
		return default_value
	
	var text = f.get_as_text()
	f.close()
	
	if text.strip_edges().is_empty():
		push_error("DataLoader.load_json: File '%s' is empty!" % path)
		return default_value
	
	var json = JSON.new()
	var err = json.parse(text)
	if err != OK:
		push_error("DataLoader.load_json: JSON parse error in '%s' at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return default_value
	
	if json.data == null:
		return default_value
		
	return json.data


## Безопасное сохранение данных в JSON с защитой и нормализацией
static func save_json(path: String, data: Variant, indent: String = "") -> bool:
	if data == null:
		push_error("DataLoader.save_json: Refusing to save null data to '%s'" % path)
		return false

	var is_locations = path.ends_with("locations.json")
	var is_terrain = path.ends_with("world_terrain.json")

	# Защита от слепой перезаписи locations.json пустыми или неполными данными
	if is_locations:
		if not (data is Dictionary) or (data as Dictionary).is_empty():
			push_error("DataLoader.save_json: Refusing to overwrite '%s' with empty dictionary!" % path)
			return false
		if FileAccess.file_exists(path) and (data as Dictionary).size() < 2:
			push_error("DataLoader.save_json: Refusing to overwrite '%s' with suspiciously few locations (%d)" % [path, (data as Dictionary).size()])
			return false

	# Защита world_terrain.json
	if is_terrain:
		if not (data is Dictionary) or (data as Dictionary).is_empty():
			push_error("DataLoader.save_json: Refusing to overwrite '%s' with empty terrain data!" % path)
			return false

	# Создание бекапа (.bak) в user://backups/ и user://
	if FileAccess.file_exists(path):
		_create_backup(path)

	# Нормализация чисел (team, cell, to, gold и др. к int)
	var clean_data = sanitize_numbers(data)
	var text = JSON.stringify(clean_data, indent)

	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("DataLoader.save_json: Cannot open file '%s' for writing, error: %d" % [path, FileAccess.get_open_error()])
		return false

	f.store_string(text)
	f.close()
	return true


## Нормализация числовых полей: приведение float, представляющих целые числа, к int
static func sanitize_numbers(value: Variant, key: String = "") -> Variant:
	if value is Dictionary:
		var res: Dictionary = {}
		for k in value:
			res[k] = sanitize_numbers(value[k], str(k))
		return res
	elif value is Array:
		if key == "cell":
			var res: Array = []
			for item in value:
				if item is float or item is int:
					res.append(int(round(item)))
				else:
					res.append(item)
			return res
		elif key == "rocks":
			var res: Array = []
			for item in value:
				if item is Array:
					var coords: Array = []
					for c in item:
						if c is float or c is int:
							coords.append(int(round(c)))
						else:
							coords.append(c)
					res.append(coords)
				else:
					res.append(item)
			return res
		elif key == "pos":
			var res: Array = []
			for item in value:
				if (item is float or item is int) and is_equal_approx(float(item), round(float(item))):
					res.append(int(round(float(item))))
				else:
					res.append(item)
			return res
		else:
			var res: Array = []
			for item in value:
				res.append(sanitize_numbers(item, key))
			return res
	elif value is float:
		if key in INT_KEYS:
			return int(round(value))
		if (key == "px" or key == "py") and is_equal_approx(value, round(value)):
			return int(round(value))
		return value
	return value


## Создание резервной копии существующего файла
static func _create_backup(path: String) -> void:
	var file_name = path.get_file()
	var backup_dir = "user://backups"
	if not DirAccess.dir_exists_absolute(backup_dir):
		DirAccess.make_dir_recursive_absolute(backup_dir)

	var backup_path = backup_dir.path_join(file_name + ".bak")
	
	var src = FileAccess.open(path, FileAccess.READ)
	if src == null:
		return
	var bytes = src.get_buffer(src.get_length())
	src.close()
	
	if bytes.is_empty():
		return

	var dst = FileAccess.open(backup_path, FileAccess.WRITE)
	if dst != null:
		dst.store_buffer(bytes)
		dst.close()
		var user_bak = "user://" + file_name + ".bak"
		var dst_user = FileAccess.open(user_bak, FileAccess.WRITE)
		if dst_user != null:
			dst_user.store_buffer(bytes)
			dst_user.close()
		print("DataLoader: Created backup for '%s' at '%s'" % [path, backup_path])
	else:
		push_warning("DataLoader: Failed to write backup to '%s'" % backup_path)
