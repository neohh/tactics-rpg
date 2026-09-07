extends CanvasLayer
var root: Control
var box: VBoxContainer

func _ready():
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			queue_free())
	root.add_child(bg)
	box = VBoxContainer.new()
	box.position = Vector2(60, 40)
	root.add_child(box)
	refresh()

func refresh():
	for c in box.get_children():
		c.queue_free()
	var t = Label.new()
	t.text = "ОТРЯД (%d/%d) | P — закрыть" % [Game.party.size(), PartyTools.max_size()]
	box.add_child(t)
	var i = 0
	for m in Game.party:
		var row = HBoxContainer.new()
		box.add_child(row)
		var nm = Label.new()
		var cid = str(m.get("char", ""))
		nm.text = "%s [%s] ур.%d HP %d/%d XP %d/%d PP %d" % [str(Game.resolve_char(cid).get("name", cid)), str(m.get("cls", "")), int(m.get("level", 1)), int(m.get("hp", 0)), int(m.get("maxhp", 0)), int(m.get("xp", 0)), StatsTools.xp_next(int(m.get("level", 1))), int(m.get("perk_points", 0))]
		nm.custom_minimum_size = Vector2(460, 24)
		row.add_child(nm)
		if i > 0:
			var bl = Button.new()
			bl.text = "лидер"
			bl.pressed.connect(_lead.bind(i))
			row.add_child(bl)
		var bd = Button.new()
		bd.text = "выгнать"
		bd.pressed.connect(_dismiss.bind(i))
		row.add_child(bd)
		if int(m.get("perk_points", 0)) > 0:
			for pid in _avail(m):
				var bp = Button.new()
				bp.text = "+ " + str(StatsTools.perks_data().get(pid, {}).get("name", pid))
				bp.pressed.connect(_learn.bind(i, pid))
				row.add_child(bp)
		i += 1
	var tp = Label.new()
	tp.text = "ПУЛ (выгнанные):"
	box.add_child(tp)
	var pi = 0
	for m in Game.party_pool:
		var row = HBoxContainer.new()
		box.add_child(row)
		var nm = Label.new()
		nm.text = "%s [%s] ур.%d" % [str(Game.resolve_char(str(m.get("char", ""))).get("name", str(m.get("char", "")))), str(m.get("cls", "")), int(m.get("level", 1))]
		nm.custom_minimum_size = Vector2(460, 24)
		row.add_child(nm)
		var br = Button.new()
		br.text = "вернуть"
		br.pressed.connect(_ret.bind(pi))
		row.add_child(br)
		pi += 1
	var x = Button.new()
	x.text = "Закрыть"
	x.pressed.connect(func(): queue_free())
	box.add_child(x)

func _avail(m):
	var res = []
	var P = StatsTools.perks_data()
	for pid in P:
		var pd = P.get(pid, {})
		var cls_ok = str(pd.get("cls", "")) == "" or str(pd.get("cls", "")) == str(m.get("cls", ""))
		var req_ok = true
		for r in pd.get("req", []):
			if not m.get("perks", []).has(r):
				req_ok = false
		if cls_ok and req_ok and not m.get("perks", []).has(pid):
			res.append(pid)
	return res

func _learn(mi, pid):
	var m = Game.party[mi]
	if int(m.get("perk_points", 0)) <= 0:
		return
	m["perk_points"] = int(m.get("perk_points", 0)) - 1
	if not m.has("perks"):
		m["perks"] = []
	m["perks"].append(pid)
	var d = StatsTools.derived(_cls_of(m), int(m.get("level", 1)), m.get("perks", []), m.get("equip", {}))
	var old = int(m.get("maxhp", 0))
	m["maxhp"] = d["hp"]
	m["hp"] = int(m.get("hp", 0)) + (d["hp"] - old)
	refresh()

func _cls_of(m):
	var f = FileAccess.open("res://data/classes.json", FileAccess.READ)
	if f == null:
		return {}
	var j = JSON.parse_string(f.get_as_text())
	f.close()
	return ({} if j == null else j).get(m.get("cls", ""), {})

func _lead(i):
	PartyTools.set_leader(i)
	refresh()

func _dismiss(i):
	PartyTools.dismiss(i)
	refresh()

func _ret(i):
	PartyTools.return_from_pool(i)
	refresh()

func _unhandled_input(ev):
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_P:
		queue_free()
		get_viewport().set_input_as_handled()
