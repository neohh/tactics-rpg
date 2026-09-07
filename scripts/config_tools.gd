class_name ConfigTools
extends RefCounted

static func all() -> Dictionary:
	var f = FileAccess.open("res://data/config.json", FileAccess.READ)
	if f == null:
		return {}
	var j = JSON.parse_string(f.get_as_text())
	f.close()
	return j if j is Dictionary else {}

static func get_val(key: String, default = null):
	var d = all()
	if d.has(key):
		return d[key]
	return default
