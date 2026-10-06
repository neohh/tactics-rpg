extends Control
var id = ""
var data = {}
var sel_line = -1
var scheme = null
var insp_box: VBoxContainer
var insp_root: ScrollContainer
var collapsed = false
var ren: LineEdit
var prev_node = null

func setup(dlg_id):
	id = dlg_id
	_load()
	_build()


func _load():
	data = DataLoader.load_json("res://data/dialogs/%s.json" % id, {"lines": []})
	if data == null or not (data is Dictionary):
		data = {"lines": []}
	if not data.has("lines"):
		data["lines"] = []

func _save():
	DataLoader.save_json("res://data/dialogs/%s.json" % id, data)
	_upd_preview()

func _get_prev():
	return get_tree().root.get_node_or_null("DialogPreview")
func _upd_preview():
	var pn = _get_prev()
	if pn != null:
		pn.data = data
		pn.chars = _chars()
		if pn.idx >= data.get("lines", []).size():
			pn.idx = 0
		pn._show()

func _preview():
	var pn = _get_prev()
	if pn != null:
		pn.queue_free()
	else:
		var d = load("res://scripts/dialog.gd").new()
		d.name = "DialogPreview"
		get_tree().root.add_child(d)
		d.play_preview(data, _chars())

func _build():
	for c in get_children():
		c.queue_free()

	# Top toolbar
	var top_bar = HBoxContainer.new()
	top_bar.position = Vector2(0, 0)
	top_bar.add_theme_constant_override("separation", 6)
	add_child(top_bar)

	var bt = Button.new()
	bt.text = "+ строка"
	bt.pressed.connect(_add_line)
	top_bar.add_child(bt)

	var bl = Button.new()
	bl.text = "авторасклад"
	bl.pressed.connect(_auto_layout)
	top_bar.add_child(bl)

	var bc = Button.new()
	bc.text = "панель"
	bc.pressed.connect(_toggle_panel)
	top_bar.add_child(bc)

	var pv = Button.new()
	pv.text = "▶ тест"
	pv.pressed.connect(_preview)
	top_bar.add_child(pv)

	var sep = VSeparator.new()
	top_bar.add_child(sep)

	var rl = Label.new()
	rl.text = "Файл:"
	rl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	top_bar.add_child(rl)

	ren = LineEdit.new()
	ren.text = id
	ren.custom_minimum_size = Vector2(160, 26)
	top_bar.add_child(ren)

	var rb = Button.new()
	rb.text = "переименовать"
	rb.pressed.connect(_rename)
	top_bar.add_child(rb)

	scheme = load("res://scripts/dialog_scheme.gd").new()
	scheme.anchor_right = 1.0
	scheme.anchor_bottom = 1.0
	scheme.offset_top = 34
	scheme.offset_bottom = -210
	scheme.clip_contents = true
	scheme.lines = data["lines"]
	scheme.sel = sel_line
	scheme.selected.connect(_sel_line)
	scheme.changed.connect(_save)
	add_child(scheme)

	insp_root = ScrollContainer.new()
	insp_root.anchor_left = 0.0
	insp_root.anchor_right = 1.0
	insp_root.anchor_top = 1.0
	insp_root.offset_top = -204
	insp_root.anchor_bottom = 1.0
	insp_root.offset_bottom = -4

	var insp_st = StyleBoxFlat.new()
	insp_st.bg_color = Color(0.10, 0.11, 0.14, 0.96)
	insp_st.border_color = Color(0.3, 0.35, 0.45, 0.8)
	insp_st.set_border_width_all(1)
	insp_st.set_corner_radius_all(4)
	insp_st.content_margin_left = 8
	insp_st.content_margin_top = 6
	insp_st.content_margin_right = 8
	insp_st.content_margin_bottom = 6
	insp_root.add_theme_stylebox_override("panel", insp_st)
	add_child(insp_root)

	insp_box = VBoxContainer.new()
	insp_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	insp_root.add_child(insp_box)
	_build_inspector()

func _toggle_panel():
	collapsed = not collapsed
	if insp_root != null:
		insp_root.visible = not collapsed
	scheme.offset_bottom = -4 if collapsed else -210

func _auto_layout():
	var n = data["lines"].size()
	var depth = {}
	var queue = [0] if n > 0 else []
	if n > 0:
		depth[0] = 0
	while queue.size() > 0:
		var i = queue.pop_front()
		var L = data["lines"][i]
		var outs = []
		if L.has("next"):
			outs.append(int(L["next"]))
		elif i + 1 < n:
			outs.append(i + 1)
		for ch in L.get("choices", []):
			outs.append(int(ch.get("to", i + 1)))
		for o in outs:
			if o >= 0 and o < n and not depth.has(o):
				depth[o] = depth[i] + 1
				queue.append(o)
	var colcount = {}
	for i in n:
		var d = depth.get(i, 0)
		var r = colcount.get(d, 0)
		colcount[d] = r + 1
		data["lines"][i]["px"] = 20 + d * 210
		data["lines"][i]["py"] = 20 + r * 90
	if scheme != null:
		scheme.pan = Vector2(20, 20)
		scheme.zoom = 1.0
	_save()
	_sync_scheme()

func _sync_scheme():
	if scheme != null:
		scheme.lines = data["lines"]
		scheme.sel = sel_line
		scheme.queue_redraw()

func _sel_line(i):
	sel_line = i
	_sync_scheme()
	_build_inspector()

func _add_line():
	var at = sel_line + 1 if sel_line >= 0 else data["lines"].size()
	data["lines"].insert(at, {"who": "", "text": ""})
	sel_line = at
	_save()
	_sync_scheme()
	_build_inspector()

func _line():
	if sel_line < 0 or sel_line >= data["lines"].size():
		return null
	return data["lines"][sel_line]

func _build_inspector():
	for c in insp_box.get_children():
		c.queue_free()
	var L = _line()
	if L == null:
		return
	var rw = HBoxContainer.new()
	rw.add_theme_constant_override("separation", 8)
	var lw = Label.new()
	lw.text = "Кто:"
	lw.custom_minimum_size = Vector2(50, 24)
	rw.add_child(lw)
	var wo = OptionButton.new()
	wo.add_item("(автор)")
	var chars = _chars()
	var k = 0
	var cur = 0
	for cid in chars:
		k += 1
		wo.add_item(str(chars[cid].get("name", cid)))
		if cid == L.get("who", ""):
			cur = k
	wo.selected = cur
	wo.custom_minimum_size = Vector2(160, 26)
	wo.item_selected.connect(_set_who)
	rw.add_child(wo)

	var sp1 = Control.new()
	sp1.custom_minimum_size = Vector2(16, 0)
	rw.add_child(sp1)

	var ln2 = Label.new()
	ln2.text = "Далее:"
	rw.add_child(ln2)
	var ns = SpinBox.new()
	ns.min_value = -1
	ns.max_value = 99
	ns.value = int(L.get("next", -1))
	ns.custom_minimum_size = Vector2(80, 26)
	ns.value_changed.connect(_set_next)
	rw.add_child(ns)
	var lh = Label.new()
	lh.text = "(-1 = след.)"
	lh.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	rw.add_child(lh)

	var sp2 = Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rw.add_child(sp2)

	var bd = Button.new()
	bd.text = "удалить строку"
	var bd_st = StyleBoxFlat.new()
	bd_st.bg_color = Color(0.22, 0.12, 0.12, 0.95)
	bd_st.border_color = Color(0.8, 0.35, 0.35, 0.8)
	bd_st.set_border_width_all(1)
	bd_st.set_corner_radius_all(4)
	bd.add_theme_stylebox_override("normal", bd_st)
	bd.pressed.connect(_del_line)
	rw.add_child(bd)
	insp_box.add_child(rw)

	var rt = HBoxContainer.new()
	rt.add_theme_constant_override("separation", 8)
	var lt = Label.new()
	lt.text = "Текст:"
	lt.custom_minimum_size = Vector2(50, 24)
	rt.add_child(lt)
	var te = LineEdit.new()
	te.text = str(L.get("text", ""))
	te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	te.custom_minimum_size = Vector2(400, 26)
	te.text_changed.connect(_set_text)
	rt.add_child(te)
	insp_box.add_child(rt)

	var rbg = HBoxContainer.new()
	rbg.add_theme_constant_override("separation", 8)
	var lbg = Label.new()
	lbg.text = "Фон:"
	lbg.custom_minimum_size = Vector2(50, 24)
	rbg.add_child(lbg)
	var bg_opt = OptionButton.new()
	bg_opt.add_item("3D (по умолчанию)")
	var art_files = _art_files()
	var cur_bg = str(L.get("bg", ""))
	var sel_opt = 0
	for i in range(art_files.size()):
		var fpath = "res://art/" + art_files[i]
		bg_opt.add_item(art_files[i])
		if cur_bg == fpath or cur_bg == art_files[i]:
			sel_opt = i + 1
	bg_opt.selected = sel_opt
	bg_opt.custom_minimum_size = Vector2(180, 26)
	rbg.add_child(bg_opt)
	var bge = LineEdit.new()
	bge.placeholder_text = "или свой путь..."
	bge.text = cur_bg
	bge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bge.custom_minimum_size = Vector2(200, 26)
	bge.text_changed.connect(_set_bg)
	bg_opt.item_selected.connect(func(idx):
		if idx == 0:
			bge.text = ""
			_set_bg("")
		else:
			var chosen = "res://art/" + art_files[idx - 1]
			bge.text = chosen
			_set_bg(chosen)
	)
	rbg.add_child(bge)
	insp_box.add_child(rbg)

	var lc = Label.new()
	lc.text = "Выборы:"
	lc.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	insp_box.add_child(lc)
	var ci = 0
	for ch in L.get("choices", []):
		var hb = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		var num_l = Label.new()
		num_l.text = "%d." % (ci + 1)
		hb.add_child(num_l)
		var ce = LineEdit.new()
		ce.text = str(ch.get("t", ""))
		ce.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ce.custom_minimum_size = Vector2(280, 26)
		ce.text_changed.connect(_set_choice_t.bind(ci))
		hb.add_child(ce)
		var to = Label.new()
		to.text = "→ переход:"
		hb.add_child(to)
		var sb = SpinBox.new()
		sb.max_value = 99
		sb.value = int(ch.get("to", 0))
		sb.custom_minimum_size = Vector2(80, 26)
		sb.value_changed.connect(_set_choice_to.bind(ci))
		hb.add_child(sb)
		var dl = Button.new()
		dl.text = "✕"
		dl.custom_minimum_size = Vector2(28, 26)
		dl.pressed.connect(_del_choice.bind(ci))
		hb.add_child(dl)
		insp_box.add_child(hb)
		ci += 1
	var ac = Button.new()
	ac.text = "+ выбор"
	ac.custom_minimum_size = Vector2(100, 26)
	ac.pressed.connect(_add_choice)
	insp_box.add_child(ac)

	var lf = Label.new()
	lf.text = "Эффекты:"
	lf.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	insp_box.add_child(lf)
	var fx = L.get("fx", {})
	var f_row = HBoxContainer.new()
	f_row.add_theme_constant_override("separation", 8)
	var lg = Label.new()
	lg.text = "дать:"
	f_row.add_child(lg)
	var ge = LineEdit.new()
	ge.text = str(fx.get("give", ""))
	ge.custom_minimum_size = Vector2(120, 26)
	ge.text_changed.connect(_set_fx.bind("give"))
	f_row.add_child(ge)
	var lgl = Label.new()
	lgl.text = "золото:"
	f_row.add_child(lgl)
	var gs = SpinBox.new()
	gs.max_value = 9999
	gs.value = int(fx.get("gold", 0))
	gs.custom_minimum_size = Vector2(90, 26)
	gs.value_changed.connect(_set_fx_int.bind("gold"))
	f_row.add_child(gs)
	var lfl = Label.new()
	lfl.text = "флаг:"
	f_row.add_child(lfl)
	var fe = LineEdit.new()
	fe.text = str(fx.get("flag", ""))
	fe.custom_minimum_size = Vector2(120, 26)
	fe.text_changed.connect(_set_fx.bind("flag"))
	f_row.add_child(fe)
	var lq = Label.new()
	lq.text = "квест:"
	f_row.add_child(lq)
	var qe = LineEdit.new()
	qe.text = str(fx.get("quest", ""))
	qe.custom_minimum_size = Vector2(100, 26)
	qe.text_changed.connect(_set_fx.bind("quest"))
	f_row.add_child(qe)
	insp_box.add_child(f_row)

func _del_line():
	if sel_line < 0:
		return
	data["lines"].remove_at(sel_line)
	sel_line = -1
	_save()
	_sync_scheme()
	_build_inspector()

func _set_who(i):
	var L = _line()
	if L == null:
		return
	if i == 0:
		L["who"] = ""
	else:
		L["who"] = _chars().keys()[i - 1]
	_save()
	_sync_scheme()

func _set_text(v):
	var L = _line()
	if L == null:
		return
	L["text"] = v
	_save()
	_sync_scheme()

func _set_bg(v):
	var L = _line()
	if L == null:
		return
	if str(v).strip_edges() == "":
		L.erase("bg")
	else:
		L["bg"] = str(v).strip_edges()
	_save()
	_sync_scheme()

func _set_next(v):
	var L = _line()
	if L == null:
		return
	if int(v) < 0 or int(v) == sel_line:
		L.erase("next")
	else:
		L["next"] = int(v)
	_save()
	_sync_scheme()

func _set_choice_t(v, i):
	var L = _line()
	if L == null:
		return
	L["choices"][i]["t"] = v
	_save()
	_sync_scheme()

func _set_choice_to(v, i):
	var L = _line()
	if L == null:
		return
	L["choices"][i]["to"] = int(v)
	_save()
	_sync_scheme()

func _add_choice():
	var L = _line()
	if L == null:
		return
	if not L.has("choices"):
		L["choices"] = []
	L["choices"].append({"t": "", "to": sel_line + 1})
	_save()
	_sync_scheme()
	_build_inspector()

func _del_choice(i):
	var L = _line()
	if L == null:
		return
	L["choices"].remove_at(i)
	_save()
	_sync_scheme()
	_build_inspector()

func _set_fx(v, key):
	var L = _line()
	if L == null:
		return
	if not L.has("fx"):
		L["fx"] = {}
	if v == "":
		L["fx"].erase(key)
	else:
		L["fx"][key] = v
	_save()

func _set_fx_int(v, key):
	var L = _line()
	if L == null:
		return
	if not L.has("fx"):
		L["fx"] = {}
	if int(v) == 0:
		L["fx"].erase(key)
	else:
		L["fx"][key] = int(v)
	_save()

func _chars():
	return DataLoader.load_json("res://data/chars.json", {})

func _art_files():
	var res = []
	var da = DirAccess.open("res://art")
	if da != null:
		da.list_dir_begin()
		var fn = da.get_next()
		while fn != "":
			if not da.current_is_dir():
				var ext = fn.get_extension().to_lower()
				if ext in ["png", "jpg", "jpeg", "webp"]:
					res.append(fn)
			fn = da.get_next()
		da.list_dir_end()
	res.sort()
	return res

func _rename():
	var nn = ren.text.strip_edges().replace(" ", "_")
	if nn == "" or nn == id:
		return
	while FileAccess.file_exists("res://data/dialogs/%s.json" % nn):
		nn += "x"
	var f = FileAccess.open("res://data/dialogs/%s.json" % id, FileAccess.READ)
	if f == null:
		return
	var content = f.get_as_text()
	f.close()
	var w = FileAccess.open("res://data/dialogs/%s.json" % nn, FileAccess.WRITE)
	w.store_string(content)
	w.close()
	DirAccess.remove_absolute("res://data/dialogs/%s.json" % id)
	_update_refs(id, nn)
	id = nn
	get_tree().call_group("con", "_select", nn)

func _update_refs(old, new):
	for p in ["res://data/locations.json", "res://data/quests.json", "res://data/chars.json"]:
		var j = DataLoader.load_json(p, {})
		if j.is_empty():
			continue
		var changed = false
		if p.ends_with("locations.json"):
			for lid in j:
				var dg = j[lid].get("dlg", {})
				for k in dg:
					if dg[k] == old:
						dg[k] = new
						changed = true
		elif p.ends_with("quests.json"):
			for q in j:
				for sk in j[q].get("stages", {}):
					if j[q]["stages"][sk].get("dlg", "") == old:
						j[q]["stages"][sk]["dlg"] = new
						changed = true
		else:
			for c in j:
				if j[c].get("dlg", "") == old:
					j[c]["dlg"] = new
					changed = true
		if changed:
			DataLoader.save_json(p, j)
