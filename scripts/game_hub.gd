extends Control

# GameHub — Единый Хаб Интерфейсов
# Открывается клавишей I. Содержит вкладки:
# Персонажи | Экипировка | Перки | Журнал | Настройки
# Навигация: Q/E переключение вкладок, Esc закрыть

var CLASSES = {}
var CHARS = {}
var ITEMS = {}
var PERKS = {}

var tabs = ["Персонажи", "Экипировка", "Перки", "Журнал", "Настройки"]
var current_tab = 0
var selected_hero = 0

# UI nodes
var tab_bar: HBoxContainer
var party_panel: VBoxContainer
var content_panel: ScrollContainer
var content_vbox: VBoxContainer

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	CLASSES = _lj("res://data/classes.json")
	CHARS = _lj("res://data/chars.json")
	ITEMS = _lj("res://data/items.json")
	PERKS = _lj("res://data/perks.json")
	_build()

func _build():
	# Background overlay
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(_on_bg_click)
	add_child(bg)

	# Main container
	var main = VBoxContainer.new()
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	main.offset_left = 40
	main.offset_right = -40
	main.offset_top = 40
	main.offset_bottom = -40
	main.add_theme_constant_override("separation", 8)
	add_child(main)

	# Top bar: title + tab bar + close button
	var top_bar = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 12)
	main.add_child(top_bar)

	var title = Label.new()
	title.text = "ИНВЕНТАРЬ"
	title.add_theme_font_size_override("font_size", 28)
	top_bar.add_child(title)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	tab_bar = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	top_bar.add_child(tab_bar)

	var spacer2 = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer2)

	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.pressed.connect(_close)
	top_bar.add_child(close_btn)

	# Content area: party selector (left) + main content (right)
	var content_area = HBoxContainer.new()
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.add_theme_constant_override("separation", 12)
	main.add_child(content_area)

	# Party selector (left panel)
	party_panel = VBoxContainer.new()
	party_panel.custom_minimum_size = Vector2(200, 0)
	party_panel.add_theme_constant_override("separation", 4)
	content_area.add_child(party_panel)

	# Separator
	var sep = VSeparator.new()
	sep.custom_minimum_size = Vector2(2, 0)
	content_area.add_child(sep)

	# Main content (right)
	content_panel = ScrollContainer.new()
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.add_child(content_panel)

	content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 8)
	content_panel.add_child(content_vbox)

	_build_tabs()
	_refresh()

func _build_tabs():
	for ch in tab_bar.get_children():
		ch.queue_free()
	for i in tabs.size():
		var btn = Button.new()
		btn.text = tabs[i]
		btn.toggle_mode = true
		btn.button_pressed = (i == current_tab)
		btn.pressed.connect(_on_tab.bind(i))
		tab_bar.add_child(btn)

func _on_tab(i):
	current_tab = i
	_build_tabs()
	_refresh()

func _refresh():
	_refresh_party()
	_refresh_content()

func _refresh_party():
	for ch in party_panel.get_children():
		ch.queue_free()

	var lbl = Label.new()
	lbl.text = "ОТРЯД"
	lbl.add_theme_font_size_override("font_size", 16)
	party_panel.add_child(lbl)

	for i in Game.party.size():
		var m = Game.party[i]
		var cid = str(m.get("char", ""))
		var cd = CHARS.get(cid, {})
		var cls_id = str(m.get("cls", ""))
		var cls_data = CLASSES.get(cls_id, {})
		var name_str = str(cd.get("name", str(cls_data.get("name", cid))))
		var hp = int(m.get("hp", 0))
		var maxhp = int(m.get("maxhp", 0))
		var level = int(m.get("level", 1))
		var xp = int(m.get("xp", 0))
		var xp_next = StatsTools.xp_next(level)

		var btn = Button.new()
		btn.text = "%s (ур.%d) %d/%d HP" % [name_str, level, hp, maxhp]
		btn.toggle_mode = true
		btn.button_pressed = (i == selected_hero)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_hero_select.bind(i))
		party_panel.add_child(btn)

		# XP bar
		var xp_bar = ProgressBar.new()
		xp_bar.custom_minimum_size = Vector2(180, 6)
		xp_bar.max_value = xp_next
		xp_bar.value = xp
		xp_bar.show_percentage = false
		party_panel.add_child(xp_bar)

func _on_hero_select(i):
	selected_hero = i
	_refresh()

func _refresh_content():
	for ch in content_vbox.get_children():
		ch.queue_free()

	if Game.party.size() == 0:
		return
	var m = Game.party[selected_hero]

	match current_tab:
		0: _show_characters_tab(m)
		1: _show_equipment_tab(m)
		2: _show_perks_tab(m)
		3: _show_journal_tab()
		4: _show_settings_tab()

# ==================== TAB: ПЕРСОНАЖИ ====================

func _show_characters_tab(m):
	var cid = str(m.get("char", ""))
	var cd = CHARS.get(cid, {})
	var cls_id = str(m.get("cls", ""))
	var cls_data = CLASSES.get(cls_id, {})
	var level = int(m.get("level", 1))
	var xp = int(m.get("xp", 0))
	var xp_next = StatsTools.xp_next(level)
	var name_str = str(cd.get("name", str(cls_data.get("name", cid))))
	var perks = m.get("perks", [])
	var equip = m.get("equip", {})

	# Header
	_add_label(name_str, 24)
	_add_label("Класс: %s  |  Уровень: %d  |  XP: %d / %d" % [
		str(cls_data.get("name", cls_id)), level, xp, xp_next])

	# Derived stats (uses equip_agg + perks)
	var d = StatsTools.derived(cls_data, level, perks, equip)
	_add_separator()
	_add_label("Характеристики", 18)

	var stats_grid = GridContainer.new()
	stats_grid.columns = 3
	stats_grid.add_theme_constant_override("h_separation", 20)
	stats_grid.add_theme_constant_override("v_separation", 4)
	content_vbox.add_child(stats_grid)

	_add_stat_row(stats_grid, "HP", "%d / %d" % [int(m.get("hp", 0)), int(d.get("hp", 2))])
	_add_stat_row(stats_grid, "Урон", str(int(d.get("dmg_bonus", 0)) + 1))
	_add_stat_row(stats_grid, "Защита", str(int(d.get("armor", 0))))
	_add_stat_row(stats_grid, "Дальность", str(int(d.get("ar", 1))))
	_add_stat_row(stats_grid, "Движение", str(int(d.get("move", 3))))
	_add_stat_row(stats_grid, "Крит (спереди)", "%d%%" % [int(d.get("cf", 0.6) * 100)])
	_add_stat_row(stats_grid, "Крит (сзади)", "%d%%" % [int(d.get("cb", 0.6) * 100)])
	_add_stat_row(stats_grid, "Бонус попадания", "+%d%%" % [int(d.get("hit_bonus", 0) * 100)])

	# Perks
	if perks.size() > 0:
		_add_separator()
		_add_label("Изученные перки:", 16)
		for pid in perks:
			var pd = PERKS.get(pid, {})
			_add_label("• %s — %s" % [str(pd.get("name", pid)), str(pd.get("desc", ""))])

	# Skills
	if d.get("skills", []).size() > 0:
		_add_separator()
		_add_label("Навыки:", 16)
		for sk in d.get("skills", []):
			_add_label("• %s" % sk)

# ==================== TAB: ЭКИПИРОВКА ====================

func _show_equipment_tab(m):
	var cid = str(m.get("char", ""))
	var cd = CHARS.get(cid, {})
	var cls_id = str(m.get("cls", ""))
	var cls_data = CLASSES.get(cls_id, {})
	var name_str = str(cd.get("name", str(cls_data.get("name", cid))))
	var equip = m.get("equip", {})
	var level = int(m.get("level", 1))
	var perks = m.get("perks", [])

	_add_label(name_str + " — Экипировка", 24)

	var slots = ["weapon", "armor", "trinket"]
	var slot_names = ["⚔️ Оружие", "🛡️ Броня", "💎 Аксессуар"]

	var equip_grid = GridContainer.new()
	equip_grid.columns = 3
	equip_grid.add_theme_constant_override("h_separation", 12)
	equip_grid.add_theme_constant_override("v_separation", 8)
	content_vbox.add_child(equip_grid)

	for i in slots.size():
		var slot_id = slots[i]
		var item_id = str(equip.get(slot_id, ""))
		var item_data = ITEMS.get(item_id, {})
		var item_name = str(item_data.get("name", "(пусто)"))

		var slot_box = VBoxContainer.new()
		slot_box.custom_minimum_size = Vector2(200, 80)
		equip_grid.add_child(slot_box)

		var slot_label = Label.new()
		slot_label.text = slot_names[i]
		slot_label.add_theme_font_size_override("font_size", 14)
		slot_box.add_child(slot_label)

		var item_label = Label.new()
		item_label.text = item_name
		item_label.add_theme_font_size_override("font_size", 16)
		if item_id != "":
			item_label.add_theme_color_override("font_color", Color(0.4, 1, 0.6))
		else:
			item_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		slot_box.add_child(item_label)

		# Show item stats if equipped
		if item_id != "" and item_data.has("mods"):
			var mods = item_data["mods"]
			for k in mods:
				var mod_label = Label.new()
				var val = mods[k]
				mod_label.text = "  %s: %+d" % [k, int(val)]
				mod_label.add_theme_font_size_override("font_size", 12)
				mod_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
				slot_box.add_child(mod_label)

	# Current derived stats
	_add_separator()
	_add_label("Итоговые характеристики (с учётом экипировки + перков):", 16)
	var d = StatsTools.derived(cls_data, level, perks, equip)
	var stat_box = HBoxContainer.new()
	stat_box.add_theme_constant_override("separation", 20)
	content_vbox.add_child(stat_box)
	_add_stat_label(stat_box, "HP: %d" % int(d.get("hp", 2)))
	_add_stat_label(stat_box, "Урон: %d" % (int(d.get("dmg_bonus", 0)) + 1))
	_add_stat_label(stat_box, "Защита: %d" % int(d.get("armor", 0)))
	_add_stat_label(stat_box, "Движение: %d" % int(d.get("move", 3)))
	_add_stat_label(stat_box, "Крит: %d%%" % int(d.get("cf", 0.6) * 100))

	# Available items to equip
	_add_separator()
	_add_label("Доступные предметы:", 16)
	var inv_box = GridContainer.new()
	inv_box.columns = 4
	inv_box.add_theme_constant_override("h_separation", 8)
	inv_box.add_theme_constant_override("v_separation", 4)
	content_vbox.add_child(inv_box)

	var has_items = false
	for iid in Game.inventory:
		if Game.inventory[iid] <= 0:
			continue
		var it = ITEMS.get(iid, {})
		if not it.has("slot"):
			continue
		has_items = true
		var btn = Button.new()
		btn.text = "%s x%d" % [str(it.get("name", iid)), Game.inventory[iid]]
		btn.custom_minimum_size = Vector2(160, 30)
		btn.pressed.connect(_on_equip_item.bind(selected_hero, iid, str(it.get("slot", ""))))
		inv_box.add_child(btn)

	if not has_items:
		_add_label("(нет предметов для экипировки)")

func _on_equip_item(hero_idx, item_id, slot):
	if hero_idx < 0 or hero_idx >= Game.party.size():
		return
	var m = Game.party[hero_idx]
	if not m.has("equip"):
		m["equip"] = {}
	var old = str(m["equip"].get(slot, ""))
	if old != "":
		Game.add_item(old)
	if Game.remove_item(item_id):
		m["equip"][slot] = item_id
		# Recalculate maxhp from derived stats
		var cls_id = str(m.get("cls", ""))
		var cls_data = CLASSES.get(cls_id, {})
		var d = StatsTools.derived(cls_data, int(m.get("level", 1)), m.get("perks", []), m["equip"])
		m["maxhp"] = int(d.get("hp", 2))
		if int(m.get("hp", 0)) > m["maxhp"]:
			m["hp"] = m["maxhp"]
		Game.autosave()
		_refresh()

# ==================== TAB: ПЕРКИ ====================

func _show_perks_tab(m):
	var cid = str(m.get("char", ""))
	var cd = CHARS.get(cid, {})
	var cls_id = str(m.get("cls", ""))
	var cls_data = CLASSES.get(cls_id, {})
	var name_str = str(cd.get("name", str(cls_data.get("name", cid))))
	var level = int(m.get("level", 1))
	var perk_points = int(m.get("perk_points", 0))
	var owned_perks = m.get("perks", [])

	_add_label(name_str + " — Перки", 24)
	_add_label("Очки перков: %d" % perk_points)

	_add_separator()

	for pid in PERKS:
		var pd = PERKS[pid]
		var pd_name = str(pd.get("name", pid))
		var pd_desc = str(pd.get("desc", ""))
		var pd_cls = str(pd.get("cls", ""))
		var reqs = pd.get("req", [])

		# Check requirements
		var can_learn = true
		var missing = []
		for r in reqs:
			if not owned_perks.has(r):
				can_learn = false
				var rpd = PERKS.get(r, {})
				missing.append(str(rpd.get("name", r)))

		# Class restriction
		if pd_cls != "" and pd_cls != cls_id:
			can_learn = false

		var already_owned = owned_perks.has(pid)

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		content_vbox.add_child(hbox)

		var lbl = Label.new()
		lbl.text = "%s — %s" % [pd_name, pd_desc]
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if already_owned:
			lbl.add_theme_color_override("font_color", Color(0.4, 1, 0.4))
		hbox.add_child(lbl)

		if already_owned:
			var owned_label = Label.new()
			owned_label.text = "✓"
			owned_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4))
			hbox.add_child(owned_label)
		elif can_learn and perk_points > 0:
			var learn_btn = Button.new()
			learn_btn.text = "Изучить"
			learn_btn.pressed.connect(_on_learn_perk.bind(selected_hero, pid))
			hbox.add_child(learn_btn)

		if missing.size() > 0:
			var req_label = Label.new()
			req_label.text = "(требуется: %s)" % ", ".join(missing)
			req_label.add_theme_font_size_override("font_size", 11)
			req_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.3))
			content_vbox.add_child(req_label)

func _on_learn_perk(hero_idx, pid):
	if hero_idx < 0 or hero_idx >= Game.party.size():
		return
	var m = Game.party[hero_idx]
	if int(m.get("perk_points", 0)) <= 0:
		return
	if m.get("perks", []).has(pid):
		return
	m["perk_points"] = int(m.get("perk_points", 0)) - 1
	if not m.has("perks"):
		m["perks"] = []
	m["perks"].append(pid)
	# Recalculate maxhp
	var cls_data = CLASSES.get(str(m.get("cls", "")), {})
	var d = StatsTools.derived(cls_data, int(m.get("level", 1)), m["perks"], m.get("equip", {}))
	m["maxhp"] = int(d.get("hp", 2))
	Game.autosave()
	_refresh()

# ==================== TAB: ЖУРНАЛ ====================

func _show_journal_tab():
	_add_label("Журнал заданий", 24)
	_add_separator()
	var any = false
	for q in Game.QUESTS:
		var st = int(Game.quests.get(q, 0))
		if st == 0:
			continue
		any = true
		var Q = Game.QUESTS[q]
		var sd = Q.get("stages", {}).get(str(st), {})
		var title = str(Q.get("title", q))
		if sd.get("done", false):
			_add_label("✔ %s — выполнено" % title)
		else:
			_add_label("• %s: %s" % [title, str(sd.get("text", ""))])
	if not any:
		_add_label("(нет активных заданий)")

# ==================== TAB: НАСТРОЙКИ ====================

func _show_settings_tab():
	_add_label("Настройки / Системное меню", 24)
	_add_separator()

	var btn_save = Button.new()
	btn_save.text = "💾 Сохранить игру"
	btn_save.custom_minimum_size = Vector2(200, 40)
	btn_save.pressed.connect(func():
		Game.save_game()
		_add_label("Сохранено!"))
	content_vbox.add_child(btn_save)

	var btn_load = Button.new()
	btn_load.text = "📂 Загрузить игру"
	btn_load.custom_minimum_size = Vector2(200, 40)
	btn_load.pressed.connect(func():
		if Game.load_game():
			_refresh()
			_add_label("Загружено!"))
	content_vbox.add_child(btn_load)

	var btn_map = Button.new()
	btn_map.text = "🗺️ На глобальную карту"
	btn_map.custom_minimum_size = Vector2(200, 40)
	btn_map.pressed.connect(func():
		get_tree().change_scene_to_file("res://overworld3d.tscn"))
	content_vbox.add_child(btn_map)

	var btn_menu = Button.new()
	btn_menu.text = "🏠 В главное меню"
	btn_menu.custom_minimum_size = Vector2(200, 40)
	btn_menu.pressed.connect(func():
		get_tree().change_scene_to_file("res://menu.tscn"))
	content_vbox.add_child(btn_menu)

# ==================== HELPERS ====================

func _add_label(text: String, size: int = 14):
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(lbl)

func _add_separator():
	var sep = HSeparator.new()
	content_vbox.add_child(sep)

func _add_stat_row(grid: GridContainer, label: String, value: String):
	var l = Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 14)
	grid.add_child(l)
	var v = Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", 14)
	v.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	grid.add_child(v)
	var spacer = Control.new()
	grid.add_child(spacer)

func _add_stat_label(parent: Control, text: String):
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	parent.add_child(lbl)

func _close():
	queue_free()

func _on_bg_click(ev):
	if ev is InputEventMouseButton and ev.pressed:
		_close()

func _unhandled_input(ev):
	if ev is InputEventKey and ev.pressed:
		if ev.keycode == KEY_ESCAPE:
			_close()
		elif ev.keycode == KEY_Q:
			current_tab = (current_tab - 1 + tabs.size()) % tabs.size()
			_build_tabs()
			_refresh()
		elif ev.keycode == KEY_E:
			current_tab = (current_tab + 1) % tabs.size()
			_build_tabs()
			_refresh()

func _lj(p):
	var f = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var j = JSON.parse_string(f.get_as_text())
	f.close()
	return {} if j == null else j
