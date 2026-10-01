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
	var bt = Button.new()
	bt.text = "+ строка"
	bt.position = Vector2(0, 0)
	bt.pressed.connect(_add_line)
	add_child(bt)
	var bl = Button.new()
	bl.text = "авторасклад"
	bl.position = Vector2(90, 0)
	bl.pressed.connect(_auto_layout)
	add_child(bl)
	var bc = Button.new()
	bc.text = "панель"
	bc.position = Vector2(210, 0)
	bc.pressed.connect(_toggle_panel)
	add_child(bc)
	scheme = load("res://scripts/dialog_scheme.gd").new()
	scheme.anchor_right = 1.0
	scheme.anchor_bottom = 1.0
	scheme.offset_top = 30
	scheme.offset_bottom = -230
	scheme.lines = data["lines"]
	scheme.sel = sel_line
	scheme.selected.connect(_sel_line)
	scheme.changed.connect(_save)
	add_child(scheme)
	insp_root = ScrollContainer.new()
	insp_root.anchor_left = 0.0
	insp_root.anchor_right = 0.45
	insp_root.anchor_top = 1.0
	insp_root.offset_top = -222
	insp_root.anchor_bottom = 1.0
	insp_root.offset_bottom = -4
	add_child(insp_root)
	insp_box = VBoxContainer.new()
	insp_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	insp_root.add_child(insp_box)
	_build_inspector()
	_build_rename()

func _toggle_panel():
	collapsed = not collapsed
	if insp_root != null:
		insp_root.visible = not collapsed
	scheme.offset_bottom = -4 if collapsed else -230

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
		data["lines"][i]["px"] = 15 + d * 165
		data["lines"][i]["py"] = 15 + r * 55
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
	var lw = Label.new()
	lw.text = "Кто"
	lw.custom_minimum_size = Vector2(60, 24)
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
	wo.item_selected.connect(_set_who)
	rw.add_child(wo)
	insp_box.add_child(rw)
	var rt = HBoxContainer.new()
	var lt = Label.new()
	lt.text = "Текст"
	lt.custom_minimum_size = Vector2(60, 24)
	rt.add_child(lt)
	var te = LineEdit.new()
	te.text = str(L.get("text", ""))
	te.custom_minimum_size = Vector2(260, 26)
	te.text_changed.connect(_set_text)
	rt.add_child(te)
	insp_box.add_child(rt)
	var rn = HBoxContainer.new()
	var ln2 = Label.new()
	ln2.text = "Далее"
	ln2.custom_minimum_size = Vector2(60, 24)
	rn.add_child(ln2)
	var ns = SpinBox.new()
	ns.min_value = -1
	ns.max_value = 99
	ns.value = int(L.get("next", -1))
	ns.custom_minimum_size = Vector2(90, 26)
	ns.value_changed.connect(_set_next)
	rn.add_child(ns)
	var lh = Label.new()
	lh.text = "-1 = след.; номер = переход"
	rn.add_child(lh)
	insp_box.add_child(rn)
	var lc = Label.new()
	lc.text = "Выборы:"
	insp_box.add_child(lc)
	var ci = 0
	for ch in L.get("choices", []):
		var hb = HBoxContainer.new()
		var ce = LineEdit.new()
		ce.text = str(ch.get("t", ""))
		ce.custom_minimum_size = Vector2(160, 26)
		ce.text_changed.connect(_set_choice_t.bind(ci))
		hb.add_child(ce)
		var to = Label.new()
		to.text = "→"
		hb.add_child(to)
		var sb = SpinBox.new()
		sb.max_value = 99
		sb.value = int(ch.get("to", 0))
		sb.value_changed.connect(_set_choice_to.bind(ci))
		hb.add_child(sb)
		var dl = Button.new()
		dl.text = "X"
		dl.pressed.connect(_del_choice.bind(ci))
		hb.add_child(dl)
		insp_box.add_child(hb)
		ci += 1
	var ac = Button.new()
	ac.text = "+ выбор"
	ac.pressed.connect(_add_choice)
	insp_box.add_child(ac)
	var bd = Button.new()
	bd.text = "удалить строку"
	bd.pressed.connect(_del_line)
	insp_box.add_child(bd)
	var lf = Label.new()
	lf.text = "Эффекты:"
	insp_box.add_child(lf)
	var fx = L.get("fx", {})
	var f1 = HBoxContainer.new()
	var lg = Label.new()
	lg.text = "дать"
	lg.custom_minimum_size = Vector2(60, 24)
	f1.add_child(lg)
	var ge = LineEdit.new()
	ge.text = str(fx.get("give", ""))
	ge.custom_minimum_size = Vector2(100, 26)
	ge.text_changed.connect(_set_fx.bind("give"))
	f1.add_child(ge)
	var lgl = Label.new()
	lgl.text = "золото"
	f1.add_child(lgl)
	var gs = SpinBox.new()
	gs.max_value = 9999
	gs.value = int(fx.get("gold", 0))
	gs.value_changed.connect(_set_fx_int.bind("gold"))
	f1.add_child(gs)
	insp_box.add_child(f1)
	var f2 = HBoxContainer.new()
	var lfl = Label.new()
	lfl.text = "флаг (мир: paid_bandits)"
	lfl.custom_minimum_size = Vector2(60, 24)
	f2.add_child(lfl)
	var fe = LineEdit.new()
	fe.text = str(fx.get("flag", ""))
	fe.custom_minimum_size = Vector2(100, 26)
	fe.text_changed.connect(_set_fx.bind("flag"))
	f2.add_child(fe)
	var lq = Label.new()
	lq.text = "квест"
	f2.add_child(lq)
	var qe = LineEdit.new()
	qe.text = str(fx.get("quest", ""))
	qe.custom_minimum_size = Vector2(80, 26)
	qe.text_changed.connect(_set_fx.bind("quest"))
	f2.add_child(qe)
	insp_box.add_child(f2)
	var pv = Button.new()
	pv.text = "▶ просмотр"
	pv.pressed.connect(_preview)
	insp_box.add_child(pv)

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

func _build_rename():
	if ren != null and is_instance_valid(ren):
		return
	var rh = HBoxContainer.new()
	rh.position = Vector2(8, 660)
	var rl = Label.new()
	rl.text = "имя файла:"
	rh.add_child(rl)
	ren = LineEdit.new()
	ren.text = id
	ren.custom_minimum_size = Vector2(160, 26)
	rh.add_child(ren)
	var rb = Button.new()
	rb.text = "переименовать"
	rb.pressed.connect(_rename)
	rh.add_child(rb)
	add_child(rh)
