extends Control
const CATS = ["chars", "items", "classes", "objects", "mats", "locs", "catalog", "map", "dialogs", "quests"]
const SCHEMAS = {"chars": [["name","text","Имя"],["title","text","Титул"],["color","color","Цвет"],["img","image","Портрет"],["img_scale","slider","Размер",0.2,3.0],["img_ox","slider","Смещ X",-200.0,200.0],["img_oy","slider","Смещ Y",-200.0,200.0]], "items": [["name","text","Название"],["img","image","Иконка"],["price","int","Цена",0,999],["heal","int","Лечение",0,9],["food","int","Еда",0,9]], "classes": [["name","text","Имя"],["hp","int","HP",1,10],["move","int","Шаги",1,8],["ar","int","Атака",1,8],["cf","slider","Лоб",0.0,1.0],["cb","slider","Спина",0.0,1.0],["db","check","Дистанц."],["img","image","Иконка"],["scale","slider","Размер",0.5,2.0],["col","check","Колизия"],["yoff","slider","Высота",-1.0,2.0],["render3d","check","3D"],["model","image","Модель"],["mscale","slider","Масштаб",0.1,3.0],["myoff","slider","Высота модели",-1.0,2.0]], "objects": [["name","text","Название"],["img","image","Картинка"],["render3d","check","3D"],["model","image","Модель"],["mscale","slider","Масштаб",0.1,3.0],["myoff","slider","Высота модели",-1.0,2.0]], "mats": [["name","text","Имя"],["color","color","Цвет"],["tex","image","Текстура"]]}
const CAT_FILES = {"chars": "res://data/chars.json", "items": "res://data/items.json", "classes": "res://data/classes.json", "objects": "res://data/objects.json", "locs": "res://data/locations.json", "dialogs": "res://data/dialogs", "quests": "res://data/quests.json", "catalog": "res://data/loc_catalog.json", "map": "res://data/locations.json", "mats": "res://data/materials.json"}
var cat = "chars"
var folder = ""
var sel_id = ""
var DATA = {}
var GROUPS = {}
var cat_box: VBoxContainer
var folder_opt: OptionButton
var list_box: VBoxContainer
var insp_box: VBoxContainer
var fname_edit: LineEdit
var fd: FileDialog
var img_field = ""
var embedded = false
var preview = null
var editor_node = null
var bn: Button
var bdel: Button
var edit_mode = false
var edit_dirty = false
var edit_backup = {}
var edit_box: VBoxContainer
var conf: ConfirmationDialog
var conf2: ConfirmationDialog
var pending_id = ""
func _ready():
	add_to_group("con")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var top = HBoxContainer.new()
	top.position = Vector2(8, 2)
	top.add_theme_constant_override("separation", 6)
	add_child(top)
	var title = Label.new()
	title.text = "КОНСТРУКТОР (Esc — закрыть)"
	top.add_child(title)
	var spc = Control.new()
	spc.custom_minimum_size = Vector2(120, 10)
	top.add_child(spc)
	fname_edit = LineEdit.new()
	fname_edit.placeholder_text = "имя папки"
	fname_edit.custom_minimum_size = Vector2(120, 26)
	top.add_child(fname_edit)
	var bf = Button.new()
	bf.text = "создать папку"
	bf.pressed.connect(_new_folder)
	top.add_child(bf)
	var bd = Button.new()
	bd.text = "удалить папку"
	bd.pressed.connect(_del_folder)
	top.add_child(bd)
	folder_opt = OptionButton.new()
	folder_opt.custom_minimum_size = Vector2(140, 26)
	folder_opt.item_selected.connect(_folder_sel)
	top.add_child(folder_opt)
	cat_box = VBoxContainer.new()
	cat_box.position = Vector2(8, 40)
	add_child(cat_box)
	for c in CATS:
		var b = Button.new()
		b.text = c
		b.custom_minimum_size = Vector2(90, 30)
		b.pressed.connect(_set_cat.bind(c))
		cat_box.add_child(b)
	edit_box = VBoxContainer.new()
	edit_box.position = Vector2(8, 400)
	edit_box.visible = false
	add_child(edit_box)
	var bsav = Button.new()
	bsav.text = "сохранить"
	bsav.custom_minimum_size = Vector2(90, 30)
	bsav.pressed.connect(_edit_save)
	edit_box.add_child(bsav)
	var bdis = Button.new()
	bdis.text = "отменить"
	bdis.custom_minimum_size = Vector2(90, 30)
	bdis.pressed.connect(_edit_discard)
	edit_box.add_child(bdis)
	var bback = Button.new()
	bback.text = "назад"
	bback.custom_minimum_size = Vector2(90, 30)
	bback.pressed.connect(_edit_back)
	edit_box.add_child(bback)
	conf = ConfirmationDialog.new()
	add_child(conf)
	conf.confirmed.connect(_edit_save_then_exit)
	conf.canceled.connect(_exit_edit_restore)
	conf2 = ConfirmationDialog.new()
	add_child(conf2)
	conf2.confirmed.connect(func(): _write_cat_file(); _start_edit(pending_id))
	conf2.canceled.connect(func(): _start_edit(pending_id))
	bn = Button.new()
	bn.text = "+ создать"
	bn.anchor_left = 0.14
	bn.anchor_right = 0.14
	bn.position = Vector2(8, 40)
	bn.size = Vector2(90, 26)
	bn.pressed.connect(_new_entry)
	add_child(bn)
	bdel = Button.new()
	bdel.text = "удалить"
	bdel.anchor_left = 0.14
	bdel.anchor_right = 0.14
	bdel.position = Vector2(108, 40)
	bdel.size = Vector2(80, 26)
	bdel.pressed.connect(_del_entry)
	add_child(bdel)
	list_box = VBoxContainer.new()
	list_box.anchor_left = 0.14
	list_box.anchor_right = 0.14
	list_box.anchor_bottom = 1
	list_box.offset_bottom = -8
	list_box.position = Vector2(8, 72)
	add_child(list_box)
	var sc = ScrollContainer.new()
	sc.anchor_left = 0.42
	sc.anchor_right = 0.99
	sc.anchor_top = 0
	sc.anchor_bottom = 1
	sc.offset_top = 40
	sc.offset_bottom = -8
	add_child(sc)
	insp_box = VBoxContainer.new()
	insp_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(insp_box)
	fd = FileDialog.new()
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_selected.connect(_file_pick)
	add_child(fd)
	preview = load("res://scripts/preview.gd").new()
	preview.position = Vector2(8, 220)
	add_child(preview)
	_set_cat("chars")
func _set_cat(c):
	Game.log_scene("set_cat " + c)
	cat = c
	folder = ""
	if (c == "locs" or c == "catalog") and Game.edit_loc != "":
		sel_id = Game.edit_loc
	else:
		sel_id = ""
	DATA = {} if cat == "dialogs" else DataLoader.load_json(CAT_FILES[cat])
	var in_loc_edit = edit_mode and (c == "locs" or c == "catalog")
	bn.visible = not in_loc_edit
	bdel.visible = not in_loc_edit
	list_box.visible = true
	if edit_box != null:
		edit_box.visible = edit_mode
	if (c == "locs" or c == "catalog") and Game.edit_loc != "" and Game.edit_data != null:
		_ensure_work()
	_refresh_folders()
	_refresh_list()
	_build_inspector()
func _refresh_folders():
	GROUPS = DataLoader.load_json("res://data/groups.json")
	folder_opt.clear()
	folder_opt.add_item("все")
	for g in GROUPS.get(cat, []):
		folder_opt.add_item(g)
func _folder_sel(i):
	folder = "" if i == 0 else folder_opt.get_item_text(i)
	_refresh_list()
func _dlg_files():
	var res = []
	var d = DirAccess.open("res://data/dialogs")
	if d == null:
		return res
	d.list_dir_begin()
	var fn = d.get_next()
	while fn != "":
		if fn.ends_with(".json"):
			res.append(fn.trim_suffix(".json"))
		fn = d.get_next()
	return res
func _refresh_list():
	for c in list_box.get_children():
		c.queue_free()
	if cat == "dialogs":
		for fn in _dlg_files():
			var b2 = Button.new()
			b2.text = fn
			b2.custom_minimum_size = Vector2(160, 28)
			b2.pressed.connect(_select.bind(fn))
			list_box.add_child(b2)
		return
	for id in DATA:
		var e = DATA[id]
		if folder != "" and e.get("group", "") != folder:
			continue
		var b = Button.new()
		b.text = str(e.get("name", e.get("title", id)))
		b.custom_minimum_size = Vector2(160, 28)
		b.pressed.connect(_select.bind(id))
		if Game.edit_loc != "" and id == Game.edit_loc and (cat == "locs" or cat == "catalog"):
			b.modulate = Color(1, 0.85, 0.4)
		list_box.add_child(b)
func _select(id):
	sel_id = id
	if cat == "locs" or cat == "catalog":
		_pick_loc_edit(id)
	else:
		_build_inspector()
func _new_entry_dialog():
	var id2 = "dlg_" + str(_dlg_files().size() + 1)
	while FileAccess.file_exists("res://data/dialogs/%s.json" % id2):
		id2 += "x"
	var f = FileAccess.open("res://data/dialogs/%s.json" % id2, FileAccess.WRITE)
	f.store_string("{\"lines\":[{\"who\":\"\",\"text\":\"\"}]}")
	f.close()
	_refresh_list()
	_select(id2)
func _new_entry():
	if cat == "dialogs":
		_new_entry_dialog()
		return
	if cat == "quests":
		var qid = "q" + str(DATA.size() + 1)
		while DATA.has(qid):
			qid += "x"
		DATA[qid] = {"title": "новый", "stages": {"1": {"type": "clear", "loc": "", "text": ""}}, "reward": {"gold": 0}}
		_save()
		_refresh_list()
		_select(qid)
		return
	var id = cat + "_" + str(DATA.size() + 1)
	while DATA.has(id):
		id += "x"
	var def = {"name": "новый", "group": folder}
	if cat == "dialogs":
		var de = load("res://scripts/dialog_editor.gd").new()
		de.setup(sel_id)
		_mount_editor(de)
		if preview != null:
			preview.visible = false
		return
	if cat == "locs":
		def.merge({"type": "field", "pos": [200, 200], "links": [], "map": {"rocks": [], "objects": [], "units": []}, "loot": [], "dlg": {}})
	if c_at(cat):
		def.merge({"hp": 2, "move": 3, "ar": 1, "cf": 0.6, "cb": 0.6, "db": false, "scale": 1.0})
	DATA[id] = def
	_save()
	_select(id)
func _del_entry_dialog():
	DirAccess.remove_absolute("res://data/dialogs/%s.json" % sel_id)
	sel_id = ""
	_refresh_list()
	_build_inspector()
	Game.edit_data = null
	get_tree().change_scene_to_file(Game.return_scene)
func _del_entry():
	if sel_id == "":
		return
	if edit_mode:
		return
	if cat == "dialogs":
		_del_entry_dialog()
		return
	DATA.erase(sel_id)
	sel_id = ""
	_save()
	_build_inspector()
func _new_folder():
	var n = fname_edit.text.strip_edges()
	if n == "":
		return
	if not GROUPS.has(cat):
		GROUPS[cat] = []
	if not GROUPS[cat].has(n):
		GROUPS[cat].append(n)
		_save_groups()
		_refresh_folders()
func _del_folder():
	var n = fname_edit.text.strip_edges()
	if GROUPS.get(cat, []).has(n):
		GROUPS[cat].erase(n)
		_save_groups()
		_refresh_folders()
func _save_groups():
	DataLoader.save_json("res://data/groups.json", GROUPS)
	get_tree().call_group("live", "live_reload")
func _save():
	DataLoader.save_json(CAT_FILES[cat], DATA)
	_refresh_list()
	if not edit_mode:
		get_tree().call_group("live", "live_reload")
	get_tree().call_group("work", "load_edit")
func _build_inspector():
	for c in insp_box.get_children():
		c.queue_free()
	if editor_node != null:
		editor_node.queue_free()
		editor_node = null
	if sel_id == "":
		return
	if cat != "dialogs" and not DATA.has(sel_id):
		return
	if cat == "quests":
		var qe = load("res://scripts/quest_editor.gd").new()
		qe.setup(DATA, sel_id)
		_mount_editor(qe)
		if preview != null:
			preview.visible = false
		return
	if cat == "dialogs":
		var de = load("res://scripts/dialog_editor.gd").new()
		de.setup(sel_id)
		_mount_editor(de)
		if preview != null:
			preview.visible = false
		return
	if cat == "locs" or cat == "catalog":
		var le = load("res://scripts/loc_editor.gd").new()
		le.setup(DATA, sel_id, CAT_FILES[cat], edit_mode)
		le.dirty.connect(_on_edit_dirty)
		le.save_req.connect(_write_cat_file)
		_mount_editor(le)
		return
	if cat == "map":
		var me = load("res://scripts/global_map_editor.gd").new()
		me.setup(DATA)
		_mount_editor(me)
		return
	var e = DATA[sel_id]
	for fld in SCHEMAS[cat]:
		var key = fld[0]
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var lab = Label.new()
		lab.text = fld[2]
		lab.custom_minimum_size = Vector2(80, 26)
		row.add_child(lab)
		if fld[1] == "text":
			var le = LineEdit.new()
			le.text = str(e.get(key, ""))
			le.custom_minimum_size = Vector2(220, 28)
			le.text_changed.connect(_set_field.bind(key))
			row.add_child(le)
		elif fld[1] == "int":
			var sb = SpinBox.new()
			sb.min_value = fld[3]
			sb.max_value = fld[4]
			sb.value = int(e.get(key, 0))
			sb.custom_minimum_size = Vector2(120, 28)
			sb.value_changed.connect(_set_field_int.bind(key))
			row.add_child(sb)
		elif fld[1] == "color":
			var cb = ColorPickerButton.new()
			cb.color = Color(str(e.get(key, "#ffffff")))
			cb.custom_minimum_size = Vector2(90, 28)
			cb.color_changed.connect(_set_field_color.bind(key))
			row.add_child(cb)
		elif fld[1] == "check":
			var ck = CheckBox.new()
			ck.button_pressed = bool(e.get(key, false))
			ck.toggled.connect(_set_field_b.bind(key))
			row.add_child(ck)
		elif fld[1] == "slider":
			var sl = HSlider.new()
			sl.min_value = fld[3]
			sl.max_value = fld[4]
			sl.step = 0.05
			sl.value = float(e.get(key, fld[5] if fld.size() > 5 else 1.0))
			sl.custom_minimum_size = Vector2(240, 28)
			sl.value_changed.connect(_set_field_f.bind(key))
			row.add_child(sl)
			var vl = Label.new()
			vl.text = str(roundf(float(e.get(key, fld[5] if fld.size() > 5 else 1.0)) * 100) / 100)
			row.add_child(vl)
		elif fld[1] == "image":
			var ib = Button.new()
			ib.text = e.get(key, "") if e.get(key, "") != "" else "выбрать…"
			ib.pressed.connect(_pick_img.bind(key))
			row.add_child(ib)
		insp_box.add_child(row)
	if cat == "chars":
		_char_extra_rows(e)
	var grow = HBoxContainer.new()
	var gl = Label.new()
	gl.text = "Папка"
	gl.custom_minimum_size = Vector2(80, 26)
	grow.add_child(gl)
	var go = OptionButton.new()
	go.add_item("(без папки)")
	var gi = 0
	var cur = 0
	for g in GROUPS.get(cat, []):
		gi += 1
		go.add_item(g)
		if g == e.get("group", ""):
			cur = gi
	go.selected = cur
	go.custom_minimum_size = Vector2(160, 28)
	go.item_selected.connect(_set_group)
	grow.add_child(go)
	insp_box.add_child(grow)
	_update_preview()
func _set_group(i):
	if sel_id == "":
		return
	DATA[sel_id]["group"] = "" if i == 0 else GROUPS[cat][i - 1]
	_save()
func _set_field(v, key):
	if sel_id == "":
		return
	DATA[sel_id][key] = v
	_save()
func _set_field_int(v, key):
	if sel_id == "":
		return
	DATA[sel_id][key] = int(v)
	_save()
func _set_field_f(v, key):
	if sel_id == "":
		return
	DATA[sel_id][key] = float(v)
	_save()
func _set_field_color(col, key):
	if sel_id == "":
		return
	DATA[sel_id][key] = "#" + col.to_html()
	_save()
func _pick_img(key):
	img_field = key
	fd.popup_centered(Vector2(700, 500))
func _file_pick(path):
	var fname = path.get_file()
	DirAccess.make_dir_recursive_absolute("res://art")
	var src = FileAccess.open(path, FileAccess.READ)
	if src == null:
		return
	var bytes = src.get_buffer(src.get_length())
	src.close()
	var dst = FileAccess.open("res://art/" + fname, FileAccess.WRITE)
	dst.store_buffer(bytes)
	dst.close()
	if sel_id != "":
		DATA[sel_id][img_field] = "res://art/" + fname
		_save()
		_build_inspector()

func _set_field_b(v, key):
	if sel_id == "":
		return
	DATA[sel_id][key] = v
	_save()
func _tex(path):
	if path == "" or not FileAccess.file_exists(path):
		return null
	var im = Image.new()
	if im.load(path) != OK:
		return null
	return ImageTexture.create_from_image(im)
func _update_preview():
	if preview == null:
		return
	if sel_id == "" or not DATA.has(sel_id):
		preview.visible = false
		return
	preview.visible = true
	preview.mode = "obj" if cat == "objects" else "class"
	preview.data = DATA[sel_id]
	preview.kind = sel_id
	var img = str(DATA[sel_id].get("img", ""))
	preview.tex = _tex(img) if img != "" else null
	preview.queue_redraw()

func c_at(c):
	return c == "classes"

func _mount_editor(n, left = 0.42):
	editor_node = n
	n.anchor_left = left
	n.anchor_right = 0.99
	n.anchor_top = 0
	n.anchor_bottom = 1
	n.offset_top = 40
	n.offset_bottom = -8
	add_child(n)

func _on_edit_dirty():
	edit_dirty = true
func _enter_edit():
	edit_backup = DATA.get(sel_id, {}).duplicate(true)
	edit_dirty = false
	edit_mode = true
	bn.visible = false
	bdel.visible = false
	list_box.visible = false
	edit_box.visible = true
	_build_inspector()
func _write_cat_file():
	if Game.edit_data != null and (cat == "locs" or cat == "catalog") and sel_id != "":
		DATA[sel_id] = Game.edit_data.duplicate(true)
	DataLoader.save_json(CAT_FILES[cat], DATA)
	if not edit_mode:
		get_tree().call_group("live", "live_reload")
	get_tree().call_group("work", "load_edit")
func _edit_save():
	_write_cat_file()
	edit_dirty = false
	edit_backup = DATA.get(sel_id, {}).duplicate(true)
func _edit_discard():
	if sel_id != "" and edit_backup.size() > 0:
		DATA[sel_id] = edit_backup.duplicate(true)
	Game.edit_data = DATA.get(sel_id, {}).duplicate(true)
	edit_dirty = false
	var cur2 = get_tree().current_scene
	if cur2 != null and cur2.is_in_group("work"):
		cur2.load_edit()
	_build_inspector()
func _edit_back():
	if edit_dirty:
		conf.dialog_text = "Сохранить изменения в «%s»?" % str(DATA.get(sel_id, {}).get("name", sel_id))
		conf.popup_centered()
	else:
		_exit_edit()
func _edit_save_then_exit():
	_write_cat_file()
	_exit_edit()
func _exit_edit_restore():
	if sel_id != "" and edit_backup.size() > 0:
		DATA[sel_id] = edit_backup.duplicate(true)
	_exit_edit()
func _exit_edit():
	Game.log_scene("exit_edit")
	Game.edit_active = false
	edit_mode = false
	edit_dirty = false
	bn.visible = true
	bdel.visible = true
	list_box.visible = true
	edit_box.visible = false
	_refresh_list()
	_build_inspector()
	Game.edit_data = null
	get_tree().change_scene_to_file(Game.return_scene)

func _open_locspace():
	var cur = get_tree().current_scene
	Game.return_scene = cur.scene_file_path if (cur != null and cur.scene_file_path != "") else "res://menu.tscn"
	if cur != null and cur.has_method("snapshot"):
		Game.battle_snap = cur.snapshot()
	Game.edit_loc = sel_id
	get_tree().change_scene_to_file("res://locspace.tscn")

func on_work_dirty():
	edit_dirty = true
func _pick_loc_edit(id):
	if Game.edit_loc == id and Game.edit_data != null:
		sel_id = id
		edit_mode = true
		_build_inspector()
		_refresh_list()
		_ensure_work()
		return
	if edit_dirty and Game.edit_loc != id:
		pending_id = id
		conf2.dialog_text = "Сохранить изменения в «%s»?" % str(DATA.get(Game.edit_loc, {}).get("name", Game.edit_loc))
		conf2.popup_centered()
	else:
		_start_edit(id)
func _start_edit(id):
	Game.log_scene("start_edit " + id)
	edit_backup = DATA.get(id, {}).duplicate(true)
	Game.edit_data = DATA.get(id, {}).duplicate(true)
	Game.edit_loc = id
	Game.edit_active = true
	edit_dirty = false
	edit_mode = true
	if edit_box != null:
		edit_box.visible = true
	bn.visible = false
	bdel.visible = false
	_build_inspector()
	var cur = get_tree().current_scene
	if cur != null:
		if cur.has_method("snapshot"):
			Game.battle_snap = cur.snapshot()
		Game.return_scene = cur.scene_file_path if cur.scene_file_path != "" else "res://menu.tscn"
	ConHotkey.show_work()
	_refresh_list()

func _ensure_work():
	Game.log_scene("ensure_work")
	if Game.edit_data != null:
		Game.edit_active = true
		ConHotkey.show_work()
		if ConHotkey.work_node != null:
			ConHotkey.work_node.load_edit()

func world_pick(id):
	if cat != "map":
		_set_cat("map")
	sel_id = id
	if editor_node != null and editor_node.has_method("sync_sel"):
		editor_node.sync_sel(id)

func world_changed():
	if cat != "map":
		return
	DATA = DataLoader.load_json(CAT_FILES[cat])
	if editor_node != null and editor_node.has_method("sync_data"):
		editor_node.sync_data(DATA, sel_id)

func _on_kind(i, kinds):
	_set_field(kinds[i], "kind")
func _on_base(i, ids):
	_set_field("" if i == 0 else ids[i - 1], "base")
func _on_status(i, sts):
	_set_field(sts[i], "status")
func _on_class(i, cls):
	_set_field(cls[i], "class")
func _set_rule_flag(v):
	if sel_id == "":
		return
	var e = DATA[sel_id]
	if not e.has("status_rules"):
		e["status_rules"] = []
	if e["status_rules"].size() == 0:
		e["status_rules"].append({"flag": "", "status": "neutral"})
	e["status_rules"][0]["flag"] = v
	_save()
func _set_rule_status(v):
	if sel_id == "":
		return
	var e = DATA[sel_id]
	if not e.has("status_rules"):
		e["status_rules"] = []
	if e["status_rules"].size() == 0:
		e["status_rules"].append({"flag": "", "status": "neutral"})
	e["status_rules"][0]["status"] = v
	_save()
func _char_extra_rows(e):
	var kinds = ["mob", "unique", "monster"]
	var rk = HBoxContainer.new()
	var lk = Label.new()
	lk.text = "Вид"
	lk.custom_minimum_size = Vector2(80, 26)
	rk.add_child(lk)
	var ko = OptionButton.new()
	var kc = 0
	for i in kinds.size():
		ko.add_item(kinds[i])
		if kinds[i] == str(e.get("kind", "unique")):
			kc = i
	ko.selected = kc
	ko.item_selected.connect(_on_kind.bind(kinds))
	rk.add_child(ko)
	insp_box.add_child(rk)
	var ids = []
	for cid in DATA:
		if cid != sel_id:
			ids.append(cid)
	var rb = HBoxContainer.new()
	var lb = Label.new()
	lb.text = "База"
	lb.custom_minimum_size = Vector2(80, 26)
	rb.add_child(lb)
	var bo = OptionButton.new()
	bo.add_item("(нет)")
	var bc = 0
	for i in ids.size():
		bo.add_item(ids[i])
		if ids[i] == str(e.get("base", "")):
			bc = i
	bo.selected = bc
	bo.item_selected.connect(_on_base.bind(ids))
	rb.add_child(bo)
	insp_box.add_child(rb)
	var sts = ["hostile", "neutral", "friendly"]
	var rs = HBoxContainer.new()
	var ls = Label.new()
	ls.text = "Статус"
	ls.custom_minimum_size = Vector2(80, 26)
	rs.add_child(ls)
	var so = OptionButton.new()
	var sc = 0
	for i in sts.size():
		so.add_item(sts[i])
		if sts[i] == str(e.get("status", "hostile")):
			sc = i
	so.selected = sc
	so.item_selected.connect(_on_status.bind(sts))
	rs.add_child(so)
	insp_box.add_child(rs)
	var cls = DataLoader.load_json("res://data/classes.json").keys()
	var rc = HBoxContainer.new()
	var lc = Label.new()
	lc.text = "Класс боя"
	lc.custom_minimum_size = Vector2(80, 26)
	rc.add_child(lc)
	var co = OptionButton.new()
	var cc = 0
	for i in cls.size():
		co.add_item(cls[i])
		if cls[i] == str(e.get("class", "swordsman")):
			cc = i
	co.selected = cc
	co.item_selected.connect(_on_class.bind(cls))
	rc.add_child(co)
	insp_box.add_child(rc)
	var rules = e.get("status_rules", [])
	var rr = HBoxContainer.new()
	var lr = Label.new()
	lr.text = "Статус если флаг"
	lr.custom_minimum_size = Vector2(80, 26)
	rr.add_child(lr)
	var fe = LineEdit.new()
	fe.text = str(rules[0].get("flag", "")) if rules.size() > 0 else ""
	fe.custom_minimum_size = Vector2(120, 26)
	fe.text_changed.connect(_set_rule_flag)
	rr.add_child(fe)
	var so2 = OptionButton.new()
	var sc2 = 0
	for i in sts.size():
		so2.add_item(sts[i])
		if rules.size() > 0 and sts[i] == str(rules[0].get("status", "neutral")):
			sc2 = i
	so2.selected = sc2
	so2.item_selected.connect(_set_rule_status.bind(sts))
	rr.add_child(so2)
	insp_box.add_child(rr)
