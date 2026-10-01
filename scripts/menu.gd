extends Control
func _ready():
	var t = Label.new()
	t.text = "ПОШАГОВАЯ ТАКТИКА"
	t.position = Vector2(180, 80)
	t.add_theme_font_size_override("font_size", 24)
	add_child(t)
	var i = 0
	for name in ["ИГРАТЬ", "КОНСТРУКТОР", "3D ТЕСТ", "ТЕСТ ЛЕСТН"]:
		var b = Button.new()
		b.text = name
		b.position = Vector2(200, 150 + i * 50)
		b.size = Vector2(200, 40)
		b.pressed.connect(_go.bind(name))
		add_child(b)
		i += 1
func _go(name):
	if name == "КОНСТРУКТОР":
		ConHotkey.open()
		return
	if name == "ТЕСТ ЛЕСТН":
		Game.cur_loc = "stairs_test"
		get_tree().change_scene_to_file("res://world3d.tscn")
		return
	Game.clear_transient_state()
	var sc = "res://overworld3d.tscn" if name == "ИГРАТЬ" else "res://world3d.tscn"
	get_tree().change_scene_to_file(sc)
