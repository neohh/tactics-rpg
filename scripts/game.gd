extends Node
var inventory = {}
var gold = 0
var food = 3
var day = 1
var hour = 8
var fatigue = 0
var quests = {}
var flags = {}
var party = []
var party_pool = []
var loc_state = {}
var explore_return = null
var explore_ground = null
var cur_loc = "village"
var edit_loc = ""
var edit_active = false
var return_scene = "res://menu.tscn"
var battle_snap = null
var edit_data = null
var edit_tool = "place"
var edit_what = "obj"
var edit_obj = "rock"
var edit_cls = "swordsman"
var edit_world = false
func add_item(id, n = 1):
	inventory[id] = inventory.get(id, 0) + n
func remove_item(id, n = 1):
	if inventory.get(id, 0) >= n:
		inventory[id] = inventory.get(id, 0) - n
		return true
	return false
func has_item(id):
	return inventory.get(id, 0) > 0
func roll_loot(table):
	var got = []
	if table == null:
		return got
	for e in table:
		if randf() * 100.0 < float(e.get("chance", 0)):
			add_item(e.get("item", ""))
			got.append(e.get("item", ""))
	return got

var CHARS_RAW = {}
var QUESTS = {}
var notice = ""
func _ready():
	add_to_group("live")
	QUESTS = DataLoader.load_json("res://data/quests.json")
	CHARS_RAW = DataLoader.load_json("res://data/chars.json")
func clear_hook(loc):
	for q in QUESTS:
		var st = int(quests.get(q, 0))
		if st == 0:
			continue
		var sd = QUESTS[q].get("stages", {}).get(str(st), {})
		if sd.get("type", "") == "clear" and sd.get("loc", "") == loc:
			quests[q] = st + 1
			_notify("Задание «%s» обновлено!" % QUESTS[q].get("title", q))
func dialog_hook(who):
	for q in QUESTS:
		var st = int(quests.get(q, 0))
		if st == 0:
			continue
		var Q = QUESTS[q]
		var sd = Q.get("stages", {}).get(str(st), {})
		if sd.get("type", "") == "talk" and sd.get("who", "") == who:
			quests[q] = st + 1
			var nd = Q.get("stages", {}).get(str(st + 1), {})
			if nd.get("done", false):
				_give_reward(Q)
				_notify("Задание «%s» ВЫПОЛНЕНО!" % Q.get("title", q))
			else:
				_notify("Задание «%s» обновлено." % Q.get("title", q))
func _give_reward(Q):
	var r = Q.get("reward", {})
	gold += int(r.get("gold", 0))
	for it in r.get("items", {}):
		add_item(it, int(r["items"][it]))
func _notify(t):
	notice = t
	print(t)
func journal_text():
	var s = "ЖУРНАЛ ЗАДАНИЙ\n"
	var any = false
	for q in QUESTS:
		var st = int(quests.get(q, 0))
		if st == 0:
			continue
		any = true
		var Q = QUESTS[q]
		var sd = Q.get("stages", {}).get(str(st), {})
		if sd.get("done", false):
			s += "✔ %s — выполнено\n" % Q.get("title", q)
		else:
			s += "• %s: %s\n" % [Q.get("title", q), sd.get("text", "")]
	if not any:
		s += "(пусто)\n"
	return s

func save_game(slot: int = 0):
	var d = {"v": 2, "slot": slot, "day": day, "hour": hour, "cur_loc": cur_loc, "gold": gold, "food": food, "fatigue": fatigue, "inventory": inventory, "quests": quests, "flags": flags, "party": party, "party_pool": party_pool, "loc_state": loc_state}
	var path = "user://save_%d.json" % slot
	if not DataLoader.save_json(path, d):
		print("Ошибка сохранения.")
		return
	print("Сохранено в слот %d." % slot)
func load_game(slot: int = -1) -> bool:
	# slot=-1 means load most recent
	var path = ""
	if slot >= 0:
		path = "user://save_%d.json" % slot
	else:
		var best = -1
		var best_time = 0
		for i in 10:
			var p = "user://save_%d.json" % i
			if FileAccess.file_exists(p):
				var f2 = FileAccess.open(p, FileAccess.READ)
				if f2 != null:
					var mod = FileAccess.get_modified_time(p)
					f2.close()
					if best < 0 or mod > best_time:
						best = i
						best_time = mod
						best = i
		if best < 0:
			# Fallback to old save
			path = "user://save.json"
		else:
			path = "user://save_%d.json" % best
	if not FileAccess.file_exists(path):
		print("Нет сохранения.")
		return false
	var j = DataLoader.load_json(path, {})
	if j.is_empty():
		return false
	inventory = j.get("inventory", {})
	gold = int(j.get("gold", 0))
	food = int(j.get("food", 0))
	day = int(j.get("day", 1))
	hour = int(j.get("hour", 8))
	fatigue = int(j.get("fatigue", 0))
	quests = j.get("quests", {})
	flags = j.get("flags", {})
	cur_loc = j.get("cur_loc", "village")
	party = j.get("party", [])
	party_pool = j.get("party_pool", [])
	loc_state = j.get("loc_state", {})
	print("Загружено из %s." % path)
	return true
func get_save_info(slot: int) -> Dictionary:
	var path = "user://save_%d.json" % slot
	if not FileAccess.file_exists(path):
		return {}
	var j = DataLoader.load_json(path, {})
	if j.is_empty():
		return {}
	var loc_name = cur_loc
	var locs = DataLoader.load_json("res://data/locations.json")
	if locs.has(str(j.get("cur_loc", ""))):
		loc_name = str(locs[str(j["cur_loc"])].get("name", j["cur_loc"]))
	var party_count = j.get("party", []).size()
	return {"slot": slot, "day": j.get("day", 1), "hour": j.get("hour", 8), "gold": j.get("gold", 0), "loc": loc_name, "party_size": party_count}

func live_reload():
	QUESTS = DataLoader.load_json("res://data/quests.json")
	CHARS_RAW = DataLoader.load_json("res://data/chars.json")

var enc = null

func log_scene(tag):
	var old = ""
	var r = FileAccess.open("res://scene_log.txt", FileAccess.READ)
	if r != null:
		old = r.get_as_text()
		r.close()
	var w = FileAccess.open("res://scene_log.txt", FileAccess.WRITE)
	if w == null:
		return
	w.store_string(old + "%s | scene=%s | active=%s loc=%s cur=%s data=%s\n" % [tag, str(get_tree().current_scene), str(edit_active), str(edit_loc), str(cur_loc), str(edit_data != null)])
	w.close()

func goto_hook(loc):
	for q in QUESTS:
		var st = int(quests.get(q, 0))
		if st == 0:
			continue
		var sd = QUESTS[q].get("stages", {}).get(str(st), {})
		if sd.get("type", "") == "goto" and sd.get("loc", "") == loc:
			quests[q] = st + 1
			var nd = QUESTS[q].get("stages", {}).get(str(st + 1), {})
			if nd.get("done", false):
				var rw = QUESTS[q].get("reward", {})
				gold += int(rw.get("gold", 0))
				for it in rw.get("items", {}):
					add_item(it, int(rw["items"][it]))
				print("Задание «%s» ВЫПОЛНЕНО!" % QUESTS[q].get("title", q))
			else:
				print("Задание «%s» обновлено!" % QUESTS[q].get("title", q))
func talk_dlg(who):
	for q in QUESTS:
		var st = int(quests.get(q, 0))
		if st == 0:
			continue
		var sd = QUESTS[q].get("stages", {}).get(str(st), {})
		if sd.get("type", "") == "talk" and sd.get("who", "") == who and str(sd.get("dlg", "")) != "":
			return sd.get("dlg")
	return ""
func arrive_dlg(loc, L2):
	for q in QUESTS:
		var st = int(quests.get(q, 0))
		if st == 0:
			continue
		var sd = QUESTS[q].get("stages", {}).get(str(st), {})
		if sd.get("type", "") == "goto" and sd.get("loc", "") == loc and str(sd.get("dlg", "")) != "":
			return sd.get("dlg")
	return L2.get(loc, {}).get("dlg", {}).get("arrive", "")

var explore_start = null

func resolve_char(id):
	var raw = CHARS_RAW.get(id, {})
	var chain = []
	var cur = raw
	var guard = 0
	while cur.size() > 0 and guard < 5:
		chain.push_front(cur)
		var b = str(cur.get("base", ""))
		cur = CHARS_RAW.get(b, {}) if b != "" else {}
		guard += 1
	var res = {}
	for c in chain:
		for k in c.keys():
			if k != "base":
				res[k] = c[k]
	var st = str(res.get("status", "hostile"))
	for rule in res.get("status_rules", []):
		if flags.get(str(rule.get("flag", "")), false):
			st = str(rule.get("status", st))
	res["status"] = st
	res["id"] = id
	return res

func autosave():
	if ConfigTools.get_val("autosave", true):
		save_game()

func loc_state_get(loc):
	if not loc_state.has(loc):
		loc_state[loc] = {}
	return loc_state[loc]

func ensure_party():
	PartyTools.fill_party()
	for m in party:
		PartyTools.ensure_hp(m)
	# Auto-start first quest if no quests active
	if quests.size() == 0 and QUESTS.has("q_intro"):
		quests["q_intro"] = 1
		_notify("Новое задание: Разговор со старостой")
