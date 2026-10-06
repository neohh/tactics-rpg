extends CanvasLayer
var root: Control
var list_container: VBoxContainer
var CHARS = {}
var CLASSES = {}

func _ready():
	CHARS = DataLoader.load_json("res://data/chars.json")
	CLASSES = DataLoader.load_json("res://data/classes.json")
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			queue_free())
	root.add_child(bg)
	
	var main_panel = PanelContainer.new()
	main_panel.anchor_left = 0.5
	main_panel.anchor_right = 0.5
	main_panel.anchor_top = 0.5
	main_panel.anchor_bottom = 0.5
	main_panel.offset_left = -300
	main_panel.offset_right = 300
	main_panel.offset_top = -260
	main_panel.offset_bottom = 260
	
	var pstyle = StyleBoxFlat.new()
	pstyle.bg_color = Color(0.08, 0.09, 0.11, 0.95)
	pstyle.border_color = Color(0.78, 0.48, 0.22, 1.0)
	pstyle.set_border_width_all(2)
	pstyle.set_corner_radius_all(8)
	pstyle.content_margin_left = 16
	pstyle.content_margin_right = 16
	pstyle.content_margin_top = 14
	pstyle.content_margin_bottom = 14
	main_panel.add_theme_stylebox_override("panel", pstyle)
	root.add_child(main_panel)
	
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	main_panel.add_child(vb)
	
	var head = HBoxContainer.new()
	vb.add_child(head)
	var t = Label.new()
	t.text = "🍺 ТАВЕРНА"
	t.add_theme_font_size_override("font_size", 16)
	t.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	head.add_child(t)
	
	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	
	var g_lbl = Label.new()
	g_lbl.name = "GoldLabel"
	g_lbl.text = "🪙 Золото: %d | Отряд %d/%d" % [Game.gold, Game.party.size(), PartyTools.max_size()]
	g_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	head.add_child(g_lbl)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	
	list_container = VBoxContainer.new()
	list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_container.add_theme_constant_override("separation", 8)
	scroll.add_child(list_container)
	
	var close_btn = Button.new()
	close_btn.text = "Закрыть [Esc]"
	close_btn.pressed.connect(func(): queue_free())
	vb.add_child(close_btn)
	
	refresh()

func refresh():
	for c in list_container.get_children():
		c.queue_free()
		
	var g_lbl = root.find_child("GoldLabel", true, false)
	if g_lbl != null:
		g_lbl.text = "🪙 Золото: %d | Отряд %d/%d" % [Game.gold, Game.party.size(), PartyTools.max_size()]
		
	var has_hire = false
	for cid in CHARS:
		var ch = CHARS[cid]
		if not ch.has("hire"):
			continue
		if _in_party(cid):
			continue
		has_hire = true
		break
		
	if has_hire:
		var sec1 = Label.new()
		sec1.text = "ДОСТУПНЫ ДЛЯ НАЙМА:"
		sec1.add_theme_font_size_override("font_size", 12)
		sec1.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		list_container.add_child(sec1)
		
		for cid in CHARS:
			var ch = CHARS[cid]
			if not ch.has("hire"):
				continue
			if _in_party(cid):
				continue
			var cls = str(ch.get("class", "swordsman"))
			var cd = _cls(cls)
			var price = int(ch.get("hire", {}).get("price", 0))
			var hp = int(cd.get("hp", 2))
			var row = _create_card(cid, cls, hp, hp, "Нанять (%d з.)" % price, func(): _hire(cid, cls, price), price)
			list_container.add_child(row)
			
	if Game.party_pool.size() > 0:
		var sec2 = Label.new()
		sec2.text = "РАНЕНЫЕ И ОТДЫХАЮЩИЕ:"
		sec2.add_theme_font_size_override("font_size", 12)
		sec2.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
		list_container.add_child(sec2)
		
		for pi in range(Game.party_pool.size()):
			var pm = Game.party_pool[pi]
			var pcid = str(pm.get("char", ""))
			var pcls = str(pm.get("cls", "swordsman"))
			var cur_hp = int(pm.get("hp", 0))
			var max_hp = maxi(1, int(pm.get("maxhp", 1)))
			var row2 = _create_card(pcid, pcls, cur_hp, max_hp, "Вылечить и вернуть (20 з.)", func(): _revive_pool(pi), 20)
			list_container.add_child(row2)

func _create_card(cid: String, cls: String, cur_hp: int, max_hp: int, btn_title: String, btn_action: Callable, cost: int) -> Control:
	var row_panel = PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(530, 84)
	
	var rstyle = StyleBoxFlat.new()
	rstyle.bg_color = Color(0.06, 0.07, 0.09, 0.85)
	rstyle.border_color = Color(0.68, 0.42, 0.20, 0.8) # Copper border
	rstyle.set_border_width_all(2)
	rstyle.set_corner_radius_all(6)
	rstyle.content_margin_left = 6
	rstyle.content_margin_right = 10
	rstyle.content_margin_top = 6
	rstyle.content_margin_bottom = 6
	row_panel.add_theme_stylebox_override("panel", rstyle)
	
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	row_panel.add_child(hb)
	
	# Portrait card on the left
	var port_box = VBoxContainer.new()
	port_box.custom_minimum_size = Vector2(64, 72)
	port_box.add_theme_constant_override("separation", 2)
	hb.add_child(port_box)
	
	var img_cont = Control.new()
	img_cont.custom_minimum_size = Vector2(64, 56)
	port_box.add_child(img_cont)
	
	var tr = TextureRect.new()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img_cont.add_child(tr)
	
	var img = str(CHARS.get(cid, {}).get("img", ""))
	if img == "":
		img = str(CLASSES.get(cls, {}).get("img", ""))
	var t = _tex(img)
	if t != null:
		tr.texture = t
		
	var hp_overlay = Label.new()
	hp_overlay.anchor_left = 1.0
	hp_overlay.anchor_right = 1.0
	hp_overlay.anchor_top = 1.0
	hp_overlay.anchor_bottom = 1.0
	hp_overlay.offset_left = -54
	hp_overlay.offset_top = -18
	hp_overlay.offset_right = -2
	hp_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_overlay.text = "%d/%d" % [cur_hp, max_hp]
	hp_overlay.add_theme_font_size_override("font_size", 10)
	hp_overlay.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	hp_overlay.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	hp_overlay.add_theme_constant_override("shadow_offset_x", 1)
	hp_overlay.add_theme_constant_override("shadow_offset_y", 1)
	img_cont.add_child(hp_overlay)
	
	var hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(64, 8)
	hp_bar.show_percentage = false
	var hp_bg = StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.2, 0.05, 0.05, 1.0)
	hp_bg.set_corner_radius_all(2)
	hp_bar.add_theme_stylebox_override("background", hp_bg)
	var hp_fill = StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.88, 0.12, 0.12, 1.0)
	hp_fill.set_corner_radius_all(2)
	hp_bar.add_theme_stylebox_override("fill", hp_fill)
	hp_bar.max_value = max_hp
	hp_bar.value = cur_hp
	port_box.add_child(hp_bar)
	
	# Middle info
	var info_vb = VBoxContainer.new()
	info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(info_vb)
	
	var cname = str(CHARS.get(cid, {}).get("name", cid))
	var cdesc = str(CLASSES.get(cls, {}).get("name", cls))
	var nl = Label.new()
	nl.text = "%s (%s)" % [cname, cdesc]
	nl.add_theme_font_size_override("font_size", 13)
	nl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	info_vb.add_child(nl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = "Здоровье: %d/%d | Стоимость: %d золота" % [cur_hp, max_hp, cost]
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.72, 0.75))
	info_vb.add_child(desc_lbl)
	
	# Action button
	var btn = Button.new()
	btn.text = btn_title
	btn.custom_minimum_size = Vector2(170, 34)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(btn_action)
	if Game.gold < cost or (cost == 20 and not PartyTools.can_recruit()):
		btn.disabled = true
	hb.add_child(btn)
	
	return row_panel

func _tex(path):
	if path == "" or not FileAccess.file_exists(path):
		return null
	var im = Image.new()
	if im.load(path) != OK:
		return null
	return ImageTexture.create_from_image(im)

func _cls(cls):
	return CLASSES.get(cls, {})

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
		get_tree().call_group("live", "_upd_hint")
	refresh()

func _revive_pool(idx):
	if idx < 0 or idx >= Game.party_pool.size():
		return
	if not PartyTools.can_recruit():
		Game._notify("Отряд полон!")
		return
	var cost = 20
	if Game.gold < cost:
		Game._notify("Недостаточно золота (нужно 20)")
		return
	Game.gold -= cost
	var m = Game.party_pool[idx]
	Game.party_pool.remove_at(idx)
	PartyTools.ensure_hp(m)
	m["hp"] = m["maxhp"]
	Game.party.append(m)
	var nm = str(CHARS.get(str(m.get("char", "")), {}).get("name", str(m.get("char", ""))))
	Game._notify("Вылечен и вернулся в строй: %s" % nm)
	refresh()
