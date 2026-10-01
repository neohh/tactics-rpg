extends CanvasLayer
var root: Control
var box: VBoxContainer
var CHARS = {}

func _ready():
	CHARS = DataLoader.load_json("res://data/chars.json")
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
	t.text = "ТАВЕРНА | Золото: %d | Отряд %d/%d" % [Game.gold, Game.party.size(), PartyTools.max_size()]
	box.add_child(t)
	for cid in CHARS:
		var ch = CHARS[cid]
		if not ch.has("hire"):
			continue
		if _in_party(cid):
			continue
		var cls = str(ch.get("class", "swordsman"))
		var cd = _cls(cls)
		var row = HBoxContainer.new()
		box.add_child(row)
		var nm = Label.new()
		nm.text = "%s — %s | HP %d | цена %d" % [str(ch.get("name", cid)), str(cd.get("name", cls)), int(cd.get("hp", 2)), int(ch.get("hire", {}).get("price", 0))]
		nm.custom_minimum_size = Vector2(430, 24)
		row.add_child(nm)
		var b = Button.new()
		b.text = "нанять"
		b.pressed.connect(_hire.bind(cid, cls, int(ch.get("hire", {}).get("price", 0))))
		row.add_child(b)
	var x = Button.new()
	x.text = "Закрыть"
	x.pressed.connect(func(): queue_free())
	box.add_child(x)

func _cls(cls):
	var j = DataLoader.load_json("res://data/classes.json")
	return j.get(cls, {})

func _in_party(cid):
	for m in Game.party:
		if str(m.get("char", "")) == cid:
			return true
	for m in Game.party_pool:
		if str(m.get("char", "")) == cid:
			return true
	return false

func _hire(cid, cls, price):
	if PartyTools.hire(cid, cls, price):
		Game._notify("Нанят: %s" % str(CHARS.get(cid, {}).get("name", cid)))
	refresh()
