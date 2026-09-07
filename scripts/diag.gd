extends Node
func _ready():
	var txt = "DIAG BOOT\n"
	txt += "game started at: %s\n" % str(Time.get_datetime_string_from_system())
	txt += "work3d.gd mtime: %s\n" % str(FileAccess.get_modified_time("res://scripts/work3d.gd"))
	var f = FileAccess.open("res://scripts/work3d.gd", FileAccess.READ)
	var s = f.get_as_text() if f != null else ""
	if f != null:
		f.close()
	txt += "file has 'var light_mode': %s\n" % str(s.find("var light_mode") >= 0)
	txt += "file has 'blight': %s\n" % str(s.find("blight.text") >= 0)
	txt += "file has '_diag_ui': %s\n" % str(s.find("func _diag_ui") >= 0)
	var w = FileAccess.open("res://diag_boot.txt", FileAccess.WRITE)
	if w != null:
		w.store_string(txt)
		w.close()
	print(txt)
