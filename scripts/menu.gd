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
	if name == "ИГРАТЬ":
		Game.party = []
		Game.party_pool = []
		Game.gold = 50
		Game.food = 3
		# Стартуем с Каэла (мечник), остальных нанимаем в таверне по ходу пролога
		var leader = PartyTools.new_member("kael", "swordsman", 1)
		leader["equip"]["weapon"] = "iron_sword"
		leader["equip"]["armor"] = "leather_armor"
		PartyTools.ensure_hp(leader)
		Game.party.append(leader)
		Game.cur_loc = "village"
		Game.flags.erase("tut_village_done")
		Game.flags.erase("clear_bandit_road")
		Game.flags.erase("tut_prologue_rewarded")
		if Game.QUESTS.has("q_intro"):
			Game.quests["q_intro"] = 1

		var pro = load("res://scripts/prologue_2d.gd").new()
		add_child(pro)
		await pro.finished
		get_tree().change_scene_to_file("res://overworld3d.tscn")
		return

	get_tree().change_scene_to_file("res://world3d.tscn")
