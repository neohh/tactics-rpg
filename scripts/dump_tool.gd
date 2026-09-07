extends Node

const OUT = "res://scripts_dump.txt"
const TAGS = ["# M2_WORLD", "# TURN_SAFE_V1", "# END_COORDINATOR_V1", "# INT1_WORLD", "# CLEANUP_V1", "# REPAIR_V1", "# PARTY_SPAWN_V2", "# UI_KEYS_V1", "# EXPLORE_ROUTE_V1", "# M2_GAME", "# M2_OV"]
const KEYS = ["func _end_turn_safe", "func _end_turn_old", "func _enemy_phase_old", "var _busy_time", "var coordinator", "var turn_state", "btn.pressed.connect(_end_turn)", "btn.pressed.connect(_end_turn_safe)", "func _leave_battle", "var party_pool", "func ensure_party", "func autosave", "func _party_bar", "players", "spawn"]

func _ready():
	collect()

func collect():
	var files = []
	_scan("res://scripts", files)
	_scan("res://addons", files)
	files.sort()
	var out = ""
	out += "=== SCRIPT DUMP FULL | %s ===\n" % Time.get_datetime_string_from_system()
	for path in files:
		var f = FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var s = f.get_as_text()
		f.close()
		var lc = s.split("\n").size()
		var mt = int(FileAccess.get_modified_time(path))
		var marks = []
		for t in TAGS:
			if s.find(t) >= 0:
				marks.append(t)
		for k in KEYS:
			if s.find(k) >= 0:
				marks.append(k)
		var cnt = 0
		var idx = s.find("var _busy_time")
		while idx >= 0:
			cnt += 1
			idx = s.find("var _busy_time", idx + 1)
		if cnt > 1:
			marks.append("DUP_var_busy=%d" % cnt)
		var seen = {}
		for L in s.split("\n"):
			var st = L.strip_edges()
			if st.begins_with("func "):
				var nm = st.substr(5).split("(")[0].split(":")[0].split(" ")[0]
				seen[nm] = seen.get(nm, 0) + 1
		var dups = []
		for nm in seen:
			if seen[nm] > 1:
				dups.append("%s x%d" % [nm, seen[nm]])
		if dups.size() > 0:
			marks.append("DUPFUNCS: " + ", ".join(dups))
		out += "\n##### FILE: %s #####\n" % path
		out += "# lines=%d | mtime=%d" % [lc, mt]
		if marks.size() > 0:
			out += " | " + ", ".join(marks)
		out += "\n"
		out += s
		if not s.ends_with("\n"):
			out += "\n"
	var w = FileAccess.open(OUT, FileAccess.WRITE)
	if w != null:
		w.store_string(out)
		w.close()
	print("DUMP TOOL FULL: ", OUT, " (", files.size(), " files, ", out.length(), " bytes)")

func _scan(path, out):
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fn = dir.get_next()
	while fn != "":
		if fn != "." and fn != "..":
			if dir.current_is_dir():
				if fn != ".godot" and fn != ".import":
					_scan(path + "/" + fn, out)
			elif fn.ends_with(".gd"):
				out.append(path + "/" + fn)
		fn = dir.get_next()
