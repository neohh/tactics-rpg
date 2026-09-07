extends CanvasLayer

func _ready():
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var box = VBoxContainer.new()
	box.position = Vector2(300, 200)
	root.add_child(box)
	var t = Label.new()
	t.text = "ПРИВАЛ"
	box.add_child(t)
	var b = Button.new()
	b.text = "Отдохнуть: +1 HP всем, +6 часов, -1 еда"
	b.pressed.connect(_rest)
	box.add_child(b)
	var x = Button.new()
	x.text = "Закрыть"
	x.pressed.connect(func(): queue_free())
	box.add_child(x)

func _rest():
	Game.hour += 6
	if Game.hour >= 24:
		Game.hour -= 24
		Game.day += 1
	if Game.food > 0:
		Game.food -= 1
	else:
		Game.fatigue += 1
	for m in Game.party:
		var cap = int(m.get("maxhp", 2))
		m["hp"] = mini(cap, int(m.get("hp", 0)) + 1)
	queue_free()
