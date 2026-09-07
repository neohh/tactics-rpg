extends CanvasLayer
var stock = ["potion", "food"]
var ITEMS = {}
var root: Control
var box: VBoxContainer
func _ready():
	ITEMS = _lj("res://data/items.json")
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	box = VBoxContainer.new()
	box.position = Vector2(60, 60)
	root.add_child(box)
	refresh()
func _lj(p):
	var f = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var s = f.get_as_text()
	f.close()
	var j = JSON.parse_string(s)
	return {} if j == null else j
func refresh():
	for c in box.get_children():
		c.queue_free()
	var t = Label.new()
	t.text = "ЛАВКА | Золото: %d | Зелья: %d | Еда: %d" % [Game.gold, Game.inventory.get("potion", 0), Game.food]
	box.add_child(t)
	for id in stock:
		var it = ITEMS.get(id, {})
		var b = Button.new()
		b.text = "Купить: %s — %d зол." % [it.get("name", id), int(it.get("price", 0))]
		b.pressed.connect(_buy.bind(id))
		box.add_child(b)
	if Game.has_item("potion"):
		var s = Button.new()
		s.text = "Продать зелье — 10 зол."
		s.pressed.connect(_sell_potion)
		box.add_child(s)
	var x = Button.new()
	x.text = "Закрыть"
	x.pressed.connect(_close)
	box.add_child(x)
func _buy(id):
	var it = ITEMS.get(id, {})
	var pr = int(it.get("price", 0))
	if Game.gold < pr:
		return
	Game.gold -= pr
	if id == "food":
		Game.food += int(it.get("food", 2))
	else:
		Game.add_item(id)
	refresh()
func _sell_potion():
	if Game.remove_item("potion"):
		Game.gold += 10
	refresh()
func _close():
	visible = false

func _unhandled_input(ev):
	if not visible:
		return
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_H:
		visible = false
		get_viewport().set_input_as_handled()
