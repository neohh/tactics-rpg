extends Control

var combat_test_panel: PanelContainer = null

func _ready():
	var t = Label.new()
	t.text = "ПОШАГОВАЯ ТАКТИКА"
	t.position = Vector2(180, 70)
	t.add_theme_font_size_override("font_size", 24)
	add_child(t)
	
	var i = 0
	for name in ["ИГРАТЬ", "⚔️ ТЕСТ БОЯ", "КОНСТРУКТОР", "ГРАФИКА", "3D ТЕСТ", "ТЕСТ ЛЕСТН"]:
		var b = Button.new()
		b.text = name
		b.position = Vector2(190, 125 + i * 46)
		b.size = Vector2(240, 38)
		b.pressed.connect(_go.bind(name))
		add_child(b)
		i += 1

func _go(name):
	if name == "КОНСТРУКТОР":
		ConHotkey.open()
		return
	if name == "ГРАФИКА":
		ConHotkey.open_graphics_window()
		return
	if name == "ТЕСТ ЛЕСТН":
		Game.cur_loc = "stairs_test"
		get_tree().change_scene_to_file("res://world3d.tscn")
		return
	if name == "⚔️ ТЕСТ БОЯ":
		_open_combat_test_dialog()
		return

	Game.clear_transient_state()
	if name == "ИГРАТЬ":
		Game.is_combat_test = false
		Game.set_combat_mode(Game.CombatMode.TURN_BASED)
		Game.party = []
		Game.party_pool = []
		Game.gold = 50
		Game.food = 3
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

func _open_combat_test_dialog():
	if combat_test_panel != null and is_instance_valid(combat_test_panel):
		combat_test_panel.visible = true
		return

	combat_test_panel = PanelContainer.new()
	combat_test_panel.set_anchors_preset(Control.PRESET_CENTER)
	combat_test_panel.custom_minimum_size = Vector2(460, 380)
	combat_test_panel.offset_left = -230
	combat_test_panel.offset_top = -190
	combat_test_panel.offset_right = 230
	combat_test_panel.offset_bottom = 190

	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.12, 0.98)
	sb.border_color = Color(0.85, 0.55, 0.25, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 20
	sb.content_margin_top = 18
	sb.content_margin_right = 20
	sb.content_margin_bottom = 18
	combat_test_panel.add_theme_stylebox_override("panel", sb)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	combat_test_panel.add_child(vb)

	# Top header
	var top_hb = HBoxContainer.new()
	vb.add_child(top_hb)

	var title = Label.new()
	title.text = "⚔️ ТЕСТ БОЯ (ЛОКАЦИЯ С ВРАГАМИ)"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hb.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(func(): combat_test_panel.visible = false)
	top_hb.add_child(close_btn)

	var desc = Label.new()
	desc.text = "Телепорт на локацию bandit_road с врагами рядом со спавном.\nРежим боя можно переключать прямо в игре по нажатию [F6]."
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.7, 0.75, 0.82))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(desc)

	var sep1 = HSeparator.new()
	vb.add_child(sep1)

	# Combat mode toggle
	var mode_lbl = Label.new()
	mode_lbl.text = "Выбранный режим боя: " + Game.get_combat_mode_name()
	mode_lbl.add_theme_font_size_override("font_size", 13)
	mode_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	vb.add_child(mode_lbl)

	var btn_mode_toggle = Button.new()
	btn_mode_toggle.text = "🔄 Сменить режим боя (сейчас: %s)" % Game.get_combat_mode_short()
	btn_mode_toggle.custom_minimum_size = Vector2(0, 36)
	btn_mode_toggle.pressed.connect(func():
		Game.cycle_combat_mode()
		mode_lbl.text = "Выбранный режим боя: " + Game.get_combat_mode_name()
		btn_mode_toggle.text = "🔄 Сменить режим боя (сейчас: %s)" % Game.get_combat_mode_short()
	)
	vb.add_child(btn_mode_toggle)

	var sep2 = HSeparator.new()
	vb.add_child(sep2)

	# Launch buttons
	var btn_fp_explore = Button.new()
	btn_fp_explore.text = "🏃 В БОЙ НА ЛОКАЦИЮ (Исследование • bandit_road)"
	btn_fp_explore.custom_minimum_size = Vector2(0, 44)
	btn_fp_explore.pressed.connect(func(): _launch_combat_test(true))
	vb.add_child(btn_fp_explore)

	var btn_tactical = Button.new()
	btn_tactical.text = "♟️ В ТАКТИЧЕСКИЙ БОЙ НА СЕТКЕ (world3d)"
	btn_tactical.custom_minimum_size = Vector2(0, 36)
	btn_tactical.pressed.connect(func(): _launch_combat_test(false))
	vb.add_child(btn_tactical)

	add_child(combat_test_panel)

func _launch_combat_test(in_explore: bool):
	Game.clear_transient_state()
	Game.is_combat_test = true

	# Equip test hero with full HP
	Game.party = []
	Game.party_pool = []
	Game.gold = 100
	Game.food = 10
	var hero = PartyTools.new_member("kael", "swordsman", 1)
	hero["equip"]["weapon"] = "iron_sword"
	hero["equip"]["armor"] = "leather_armor"
	PartyTools.ensure_hp(hero)
	Game.party.append(hero)

	# Set location to bandit_road with active hostiles
	Game.cur_loc = "bandit_road"
	Game.flags.erase("clear_bandit_road")
	Game.flags.erase("peace_bandit_road")
	Game.flags.erase("paid_bandits_bandit_road")

	var ls = Game.loc_state_get("bandit_road")
	ls["cleared_day"] = -999

	# Guaranteed hostile enemies right near player spawn
	Game.enc = {
		"map": {
			"units": [
				{"cell": [6, 4], "team": 1, "cls": "swordsman"},
				{"cell": [7, 5], "team": 1, "cls": "assassin"},
				{"cell": [6, 6], "team": 1, "cls": "halberd"}
			]
		}
	}

	if in_explore:
		Game.set_combat_mode(Game.CombatMode.REALTIME_FP)
		get_tree().change_scene_to_file("res://explore3d.tscn")
	else:
		get_tree().change_scene_to_file("res://world3d.tscn")
