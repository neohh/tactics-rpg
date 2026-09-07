@tool
extends EditorPlugin
var cmd_open = "res://locs_edit/_cmd_open.txt"
var cmd_save = "res://locs_edit/_cmd_save.txt"
var warmup = 120
func _process(_d):
	if warmup > 0:
		warmup -= 1
		return
	if FileAccess.file_exists(cmd_save):
		var f = FileAccess.open(cmd_save, FileAccess.READ)
		var p = f.get_as_text().strip_edges()
		f.close()
		var d = DirAccess.open("res://locs_edit")
		if d != null:
			d.remove("_cmd_save.txt")
		if p != "":
			var es = EditorInterface.get_edited_scene_root()
			if es == null or es.scene_file_path != p:
				EditorInterface.open_scene_from_path(p)
			var es2 = EditorInterface.get_edited_scene_root()
			if es2 != null and es2.scene_file_path == p:
				var err = EditorInterface.save_scene()
				print("BRIDGE: save_scene -> ", err)
		var fd = FileAccess.open("res://locs_edit/_save_done.txt", FileAccess.WRITE)
		fd.store_string("ok")
		fd.close()
	if FileAccess.file_exists(cmd_open):
		var f = FileAccess.open(cmd_open, FileAccess.READ)
		var p = f.get_as_text().strip_edges()
		f.close()
		var d = DirAccess.open("res://locs_edit")
		if d != null:
			d.remove("_cmd_open.txt")
		if p != "" and FileAccess.file_exists(p):
			print("BRIDGE: open+reload ", p)
			EditorInterface.open_scene_from_path(p)
			EditorInterface.reload_scene_from_path(p)
			var es = EditorInterface.get_edited_scene_root()
			if es != null:
				var sel = EditorInterface.get_selection()
				sel.clear()
				sel.add_node(es)
			print("BRIDGE: корень выделен — нажми F во вьюпорте")
