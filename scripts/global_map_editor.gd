extends Control
var DATA = {}
var sel_id = ""
var canvas = null
var link_mode = false
var link_lab: Label
var cat_stat: Label
var last_cat = 0
var insp: VBoxContainer
var cat_box: OptionButton
var tman: VBoxContainer
var sel_type = ""
func setup(d):
	DATA = d
	_build()
func _build():
	for c in get_children():
		c.queue_free()
	var tb = HBoxContainer.new()
	tb.position = Vector2(0, 0)
	var b1 = Button.new()
	b1.text = "+ локация"
	b1.pressed.connect(_new_loc)
	tb.add_child(b1)
	var b2 = Button.new()
	b2.text = "связь"
	b2.pressed.connect(_toggle_link)
	tb.add_child(b2)
	var b3 = Button.new()
	b3.text = "удалить"
	b3.pressed.connect(_del_loc)
	tb.add_child(b3)
	var cat_tb = OptionButton.new()
	cat_tb.add_item("(каталог)")
	var cnames = []
	var catd0 = _lj("res://data/locations.json")
	for cid in catd0:
		cat_tb.add_item(_lib_label(catd0[cid], cid))
		cnames.append(cid)
	cat_tb.set_meta("names", cnames)
	cat_box = cat_tb
	tb.add_child(cat_tb)
	var b5 = Button.new()
	b5.text = "→ в точку"
	b5.pressed.connect(_apply_cat_to_sel)
	tb.add_child(b5)
	var b4 = Button.new()
	b4.text = "+ из каталога"
	b4.pressed.connect(_new_from_cat.bind(cat_tb))
	tb.add_child(b4)
	link_lab = Label.new()
	link_lab.text = ""
	tb.add_child(link_lab)
	var b3d = Button.new()
	b3d.text = "→ в 3D"
	b3d.pressed.connect(_open_3d)
	tb.add_child(b3d)
	add_child(tb)
	canvas = load("res://scripts/map_canvas.gd").new()
	canvas.position = Vector2(0, 30)
	canvas.DATA = DATA
	canvas.sel = sel_id
	canvas.picked.connect(_pick)
	canvas.moved.connect(_save)
	canvas.link_req.connect(_link)
	add_child(canvas)
	insp = VBoxContainer.new()
	insp.position = Vector2(0, 460)
	add_child(insp)
	tman = VBoxContainer.new()
	tman.position = Vector2(400, 460)
	add_child(tman)
	_types_ui()
func _pick(id):
	sel_id = id
	canvas.sel = id
	canvas.queue_redraw()
	_insp_ui()
func _toggle_link():
	link_mode = not link_mode
	canvas.link_mode = link_mode
	link_lab.text = "связь: ВКЛ — кликни две локации" if link_mode else ""
func _link(a, b):
	var la = DATA[a].get("links", [])
	if la.has(b):
		la.erase(b)
		DATA[b].get("links", []).erase(a)
	else:
		la.append(b)
		if not DATA[b].has("links"):
			DATA[b]["links"] = []
		DATA[b]["links"].append(a)
	_save()
	canvas.queue_redraw()
func _new_loc():
	var id = "loc_" + str(DATA.size() + 1)
	while DATA.has(id):
		id += "x"
	DATA[id] = {"name": "новая", "type": "field", "pos": [600, 400], "links": [], "map": {"rocks": [], "objects": [], "units": []}, "loot": [], "dlg": {}}
	sel_id = id
	_save()
	canvas.DATA = DATA
	canvas.sel = id
	canvas.queue_redraw()
	_insp_ui()
func _del_loc():
	if sel_id == "":
		return
	DATA.erase(sel_id)
	for id in DATA:
		DATA[id].get("links", []).erase(sel_id)
	sel_id = ""
	_save()
	canvas.DATA = DATA
	canvas.sel = ""
	canvas.queue_redraw()
	_insp_ui()
func _insp_ui():
	for c in insp.get_children():
		c.queue_free()
	if sel_id == "" or not DATA.has(sel_id):
		return
	var L = DATA[sel_id]
	var rn = HBoxContainer.new()
	var ln = Label.new()
	ln.text = "Имя"
	rn.add_child(ln)
	var le = LineEdit.new()
	le.text = str(L.get("name", ""))
	le.custom_minimum_size = Vector2(140, 26)
	le.text_changed.connect(_set_name)
	rn.add_child(le)
	insp.add_child(rn)
	var rt = HBoxContainer.new()
	var lt = Label.new()
	lt.text = "Тип"
	rt.add_child(lt)
	var ty = OptionButton.new()
	var i = 0
	var cur = 0
	for t in _type_keys():
		ty.add_item(t)
		if t == str(L.get("type", "field")):
			cur = i
		i += 1
	ty.selected = cur
	ty.item_selected.connect(_set_type)
	rt.add_child(ty)
	insp.add_child(rt)
	var rc = HBoxContainer.new()
	var lc2 = Label.new()
	lc2.text = "Каталог"
	rc.add_child(lc2)
	var co = OptionButton.new()
	co.add_item("пусто")
	var catd = _lj("res://data/locations.json")
	var names = []
	for cid in catd:
		co.add_item(_lib_label(catd[cid], cid))
		names.append(cid)
	co.item_selected.connect(_apply_cat.bind(names))
	var si = 0
	var src_key = str(L.get("src", ""))
	if src_key != "":
		for k in names.size():
			if names[k] == src_key:
				si = k + 1
				break
	co.selected = si
	rc.add_child(co)
	insp.add_child(rc)
	var rg = HBoxContainer.new()
	var lg = Label.new()
	lg.text = "Категория"
	rg.add_child(lg)
	var go = OptionButton.new()
	go.add_item("(без группы)")
	var gi = 0
	var gsel = 0
	var L2 = DATA.get(sel_id, {})
	for g in _groups():
		go.add_item(g)
		gi += 1
		if str(L2.get("group", "")) == g:
			gsel = gi
	go.selected = gsel
	go.item_selected.connect(_set_group)
	rg.add_child(go)
	insp.add_child(rg)
	cat_stat = Label.new()
	cat_stat.text = ""
	insp.add_child(cat_stat)
	var rl = HBoxContainer.new()
	var ll = Label.new()
	ll.text = "id: %s | связи: %s" % [sel_id, ", ".join(PackedStringArray(L.get("links", [])))]
	rl.add_child(ll)
	insp.add_child(rl)
	var rm = HBoxContainer.new()
	var lm = Label.new()
	lm.text = "Модель"
	lm.custom_minimum_size = Vector2(60, 26)
	rm.add_child(lm)
	var mb = Button.new()
	mb.text = str(L.get("model", "")) if str(L.get("model", "")) != "" else "выбрать…"
	mb.custom_minimum_size = Vector2(220, 26)
	mb.pressed.connect(_pick_model)
	rm.add_child(mb)
	var mcl = Button.new()
	mcl.text = "сброс"
	mcl.pressed.connect(func():
		DATA[sel_id].erase("model")
		_save()
		_insp_ui())
	rm.add_child(mcl)
	var sm = HSlider.new()
	sm.min_value = 0.1
	sm.max_value = 5.0
	sm.step = 0.1
	sm.value = float(L.get("mscale", 1.0))
	sm.custom_minimum_size = Vector2(140, 26)
	sm.value_changed.connect(func(v):
		DATA[sel_id]["mscale"] = clampf(v, 0.1, 10.0)
		_write_silent()
		for n in get_tree().get_nodes_in_group("live"):
			if n.has_method("live_update_loc"):
				n.live_update_loc(sel_id))
	rm.add_child(sm)
	insp.add_child(rm)
func _set_name(v):
	DATA[sel_id]["name"] = v
	_save()
	canvas.queue_redraw()
func _set_type(i):
	DATA[sel_id]["type"] = _type_keys()[i]
	_save()
	canvas.queue_redraw()
func _apply_cat(i, names):
	var L = DATA[sel_id]
	if i <= 0:
		L["src"] = ""
		_save()
		_insp_ui()
		return
	var catd = _lj("res://data/locations.json")
	var src = catd.get(names[i - 1], {})
	L["map"] = src.get("map", {}).duplicate(true)
	L["loot"] = src.get("loot", []).duplicate(true)
	L["dlg"] = src.get("dlg", {}).duplicate(true)
	L["type"] = src.get("type", L.get("type", "field"))
	L["src"] = names[i - 1]
	last_cat = i
	_save()
	_insp_ui()
	if cat_stat != null:
		cat_stat.text = "Висит: %s | объектов %d, бойцов %d." % [str(src.get("name", names[i - 1])), src.get("map", {}).get("objects", []).size() + src.get("map", {}).get("rocks", []).size(), src.get("map", {}).get("units", []).size()]
	canvas.queue_redraw()
func _lj(p):
	var f = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var s = f.get_as_text()
	f.close()
	var j = JSON.parse_string(s)
	return {} if j == null else j
func _save():
	var f = FileAccess.open("res://data/locations.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(DATA))
	f.close()
	get_tree().call_group("live", "live_reload")

func _new_from_cat(ob):
	var i = ob.selected
	if i <= 0:
		return
	var names = ob.get_meta("names")
	var catd = _lj("res://data/locations.json")
	var src = catd.get(names[i - 1], {})
	var id = "loc_" + str(DATA.size() + 1)
	while DATA.has(id):
		id += "x"
	DATA[id] = {"name": str(src.get("name", "новая")), "type": str(src.get("type", "field")), "pos": [600, 400], "links": [], "map": src.get("map", {}).duplicate(true), "loot": src.get("loot", []).duplicate(true), "dlg": src.get("dlg", {}).duplicate(true)}
	sel_id = id
	_save()
	canvas.DATA = DATA
	canvas.sel = id
	canvas.queue_redraw()
	_insp_ui()


func _apply_cat_to_sel():
	if sel_id == "" or cat_box == null:
		return
	var i = cat_box.selected
	if i <= 0:
		return
	var names = cat_box.get_meta("names")
	var catd = _lj("res://data/locations.json")
	var src = catd.get(names[i - 1], {})
	if src.is_empty() or not DATA.has(sel_id):
		return
	var Ld = DATA[sel_id]
	Ld["map"] = src.get("map", {}).duplicate(true)
	Ld["loot"] = src.get("loot", []).duplicate(true)
	Ld["dlg"] = src.get("dlg", {}).duplicate(true)
	Ld["type"] = src.get("type", Ld.get("type", "field"))
	Ld["name"] = src.get("name", Ld.get("name", sel_id))
	Ld["src"] = names[i - 1]
	_save()
	_insp_ui()
func _lib_label(e, cid):
	var g = str(e.get("group", ""))
	return ("[" + g + "] " if g != "" else "") + str(e.get("name", cid))

func _groups():
	return _lj("res://data/groups.json").get("locs", [])
func _set_group(i):
	if sel_id == "":
		return
	if i <= 0:
		DATA[sel_id].erase("group")
	else:
		DATA[sel_id]["group"] = _groups()[i - 1]
	_save()
	_insp_ui()

func _pick_model():
	var fd2 = FileDialog.new()
	fd2.access = FileDialog.ACCESS_RESOURCES
	fd2.root_subfolder = "res://art"
	fd2.mode = FileDialog.FILE_MODE_OPEN_FILE
	fd2.add_filter("*.fbx")
	fd2.add_filter("*.glb")
	fd2.add_filter("*.tscn")
	fd2.add_filter("*.tres")
	fd2.file_selected.connect(func(p):
		DATA[sel_id]["model"] = p
		_save()
		_insp_ui())
	add_child(fd2)
	fd2.popup_centered(Vector2(700, 500))

func _type_keys():
	var k = _lj("res://data/loc_types.json").keys()
	if k.size() == 0:
		return ["field", "town", "camp", "cave"]
	return k
func _save_types(types):
	var f = FileAccess.open("res://data/loc_types.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(types))
	f.close()
	get_tree().call_group("live", "live_reload")
func _add_type():
	var types = _lj("res://data/loc_types.json")
	var id = "type_" + str(types.size() + 1)
	while types.has(id):
		id += "x"
	types[id] = {"name": "новый", "model": "", "mscale": 1.0}
	sel_type = id
	_save_types(types)
	_types_ui()
func _del_type():
	if sel_type == "":
		return
	var types = _lj("res://data/loc_types.json")
	types.erase(sel_type)
	sel_type = ""
	_save_types(types)
	_types_ui()
func _pick_type_model():
	if sel_type == "":
		return
	var tfd = FileDialog.new()
	tfd.access = FileDialog.ACCESS_FILESYSTEM
	tfd.file_selected.connect(func(p):
		var fname = p.get_file()
		DirAccess.make_dir_recursive_absolute("res://art")
		var src = FileAccess.open(p, FileAccess.READ)
		if src != null:
			var bytes = src.get_buffer(src.get_length())
			src.close()
			var dst = FileAccess.open("res://art/" + fname, FileAccess.WRITE)
			dst.store_buffer(bytes)
			dst.close()
			var types = _lj("res://data/loc_types.json")
			if types.has(sel_type):
				types[sel_type]["model"] = "res://art/" + fname
				_save_types(types)
			_types_ui())
	add_child(tfd)
	tfd.popup_centered(Vector2(700, 500))
func _types_ui():
	for c in tman.get_children():
		c.queue_free()
	var tt = Label.new()
	tt.text = "ТИПЫ ЛОКАЦИЙ"
	tman.add_child(tt)
	var types = _lj("res://data/loc_types.json")
	var hb = HBoxContainer.new()
	var bp = Button.new()
	bp.text = "+ тип"
	bp.pressed.connect(_add_type)
	hb.add_child(bp)
	var bd = Button.new()
	bd.text = "удалить"
	bd.pressed.connect(_del_type)
	hb.add_child(bd)
	tman.add_child(hb)
	var lb = VBoxContainer.new()
	for k in types.keys():
		var b = Button.new()
		b.text = str(k)
		if str(k) == sel_type:
			b.modulate = Color(1, 0.85, 0.4)
		b.pressed.connect(func():
			sel_type = str(k)
			_types_ui())
		lb.add_child(b)
	tman.add_child(lb)
	if sel_type != "" and types.has(sel_type):
		var td = types[sel_type]
		var rn = HBoxContainer.new()
		var ln = Label.new()
		ln.text = "Имя"
		rn.add_child(ln)
		var le = LineEdit.new()
		le.text = str(td.get("name", ""))
		le.custom_minimum_size = Vector2(120, 26)
		le.text_changed.connect(func(v):
			types[sel_type]["name"] = v
			_save_types(types))
		rn.add_child(le)
		tman.add_child(rn)
		var rm = HBoxContainer.new()
		var lm = Label.new()
		lm.text = "Модель"
		rm.add_child(lm)
		var mb = Button.new()
		mb.text = str(td.get("model", "")) if str(td.get("model", "")) != "" else "выбрать…"
		mb.custom_minimum_size = Vector2(160, 26)
		mb.pressed.connect(_pick_type_model)
		rm.add_child(mb)
		var mc = Button.new()
		mc.text = "сброс"
		mc.pressed.connect(func():
			types[sel_type]["model"] = ""
			_save_types(types)
			_types_ui())
		rm.add_child(mc)
		tman.add_child(rm)
		var rs = HBoxContainer.new()
		var ls = Label.new()
		ls.text = "Масштаб"
		rs.add_child(ls)
		var sl = HSlider.new()
		sl.min_value = 0.1
		sl.max_value = 5.0
		sl.step = 0.1
		sl.value = float(td.get("mscale", 1.0))
		sl.custom_minimum_size = Vector2(120, 26)
		sl.value_changed.connect(func(v):
			types[sel_type]["mscale"] = v
			_save_types(types))
		rs.add_child(sl)
		tman.add_child(rs)

func _write_silent():
	var f = FileAccess.open("res://data/locations.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(DATA))
	f.close()

func _open_3d():
	Game.edit_world = true
	get_tree().change_scene_to_file("res://overworld3d.tscn")

func sync_sel(id):
	sel_id = id
	if canvas != null:
		canvas.sel = id
		canvas.queue_redraw()
	_insp_ui()

func sync_data(d, keep_id):
	DATA = d
	if canvas != null:
		canvas.DATA = d
		canvas.queue_redraw()
	if keep_id != "" and DATA.has(keep_id):
		sel_id = keep_id
	_insp_ui()
