extends Node3D

var yaw_n: Node3D
var pitch_n: Node3D
var cam: Camera3D
var yaw = 0.0
var pitch = -0.9
var dist = 18.0
var target = Vector3(0, 0, 0)
var mid_drag = false
var right_drag = false
var token: MeshInstance3D
var traveling = false
var LOCS = {}
var CHARS = {}
var LOC_TYPES = {}
var S = 0.0171
var hint: Label
var last_arr = ""
var edit_mode = false
var terr = null
var DECOR = []
var w_sel = ""
var w_mode = "select"
var giz_mode = ""
var giz_start = {}
var gizmo_root = null
var sel_ring = null
var loc_roots = {}
var link_nodes = []
var sculpt_btn = ""
var paint_btn = false
var paint_mat = 0
var w_radius = 2.0
var decor_idx = 0
var decor_sub = "click"
var decor_radius = 2.0
var decor_brush_btn = false
var decor_panel: VBoxContainer = null
var decor_nodes = []
var OBJ3 = {}
var decor_per = 1
var decor_scale = 1.0
var decor_sel = -1
var light_mode = false
var light_sel = -1
var LIGHTS = []
var light_nodes = []
var light_gizmo_root = null
var light_panel: VBoxContainer = null
var sun_light: DirectionalLight3D = null
var fill_light: DirectionalLight3D = null
var world_env: Environment = null
var scene_panel: VBoxContainer = null
var sun_energy = 1.0
var sun_rot = 30.0
var sun_elev = 50.0
var sun_col = 0
var amb_energy = 0.6
var amb_col = 1
var fill_energy = 0.3
const SUN_PATH = "res://data/world_sun.json"
const LIGHT_PATH = "res://data/world_lights.json"
var brush_ind: MeshInstance3D = null
const DECOR_MIN = 1.5
var mat_opt: OptionButton
var mbtns = {}
var _prev_ms: float = -1.0
var _ms_timer: float = 0.0
var chunk_debug_ind: MeshInstance3D = null
const DECOR_KINDS = ["tree", "rock", "house", "tent", "crate"]
const W_PATH = "res://data/world_terrain.json"
const DECOR_PATH = "res://data/world_decor.json"
const W_GW = 96
const W_GH = 64
const W_SUB = 2
const OFFX = -36
const OFFY = -24
const W_LOC_SCALE = 0.5

func _ready():
	add_to_group("live")
	add_to_group("con")
	edit_mode = Game.edit_world
	LOCS = DataLoader.load_json("res://data/locations.json")
	CHARS = DataLoader.load_json("res://data/chars.json")
	LOC_TYPES = DataLoader.load_json("res://data/loc_types.json")
	OBJ3 = DataLoader.load_json("res://data/objects.json")
	print("OBJ3 keys: ", OBJ3.keys())
	_setup_cam()
	_load_terrain()
	DECOR = DataLoader.load_json(DECOR_PATH, [])
	LIGHTS = DataLoader.load_json(LIGHT_PATH, [])
	if edit_mode:
		_make_chunk_debug()
		_make_brush_ind()
	_build_world()
	if not edit_mode:
		var c = LOCS.get(Game.cur_loc, {}).get("pos", [400, 300])
		target = Vector3(c[0] * S, 0, c[1] * S)
	_apply()
	_ui()

func _ui():
	var ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	hint = Label.new()
	hint.position = Vector2(10, 10)
	ui.add_child(hint)
	if edit_mode:
		var evb = VBoxContainer.new()
		evb.position = Vector2(10, 40)
		evb.add_theme_constant_override("separation", 4)
		ui.add_child(evb)
		var bb = Button.new()
		bb.text = "← назад"
		bb.pressed.connect(_exit_edit)
		evb.add_child(bb)
		var b1 = Button.new()
		b1.text = "ВЫБОР [1]"
		b1.pressed.connect(func(): _set_wmode("select"))
		evb.add_child(b1)
		var b2 = Button.new()
		b2.text = "ТОЧКА [2]"
		b2.pressed.connect(func(): _set_wmode("point"))
		evb.add_child(b2)
		var b3 = Button.new()
		b3.text = "ДЕКОР [3]"
		b3.pressed.connect(func(): _set_wmode("decor"))
		evb.add_child(b3)
		var bs = Button.new()
		bs.text = "СКУЛЬПТ [T]"
		bs.pressed.connect(func(): _set_wmode("sculpt"))
		evb.add_child(bs)
		var bp = Button.new()
		bp.text = "КРАСКА [P]"
		bp.pressed.connect(func(): _set_wmode("paint"))
		evb.add_child(bp)
		var bl = Button.new()
		bl.text = "СВЕТ [L]"
		bl.pressed.connect(func(): _set_wmode("light"))
		evb.add_child(bl)
		var b4 = Button.new()
		b4.text = "ЧАНКИ [4]"
		b4.pressed.connect(func(): _set_wmode("chunk"))
		evb.add_child(b4)
		var br = Button.new()
		br.text = "ОБНОВИТЬ"
		br.pressed.connect(_refresh_map)
		evb.add_child(br)
		mbtns = {"select": b1, "point": b2, "decor": b3, "sculpt": bs, "paint": bp, "chunk": b4, "light": bl}
		mat_opt = OptionButton.new()
		var m = DataLoader.load_json("res://data/materials.json")
		for k in m:
			mat_opt.add_item(str(m[k].get("name", k)))
		mat_opt.item_selected.connect(func(i): paint_mat = i)
		evb.add_child(mat_opt)
		decor_panel = VBoxContainer.new()
		decor_panel.position = Vector2(10, 320)
		decor_panel.add_theme_constant_override("separation", 4)
		decor_panel.visible = false
		ui.add_child(decor_panel)
		var dt = Label.new()
		dt.text = "ДЕКОР: режим"
		decor_panel.add_child(dt)
		var db1 = Button.new()
		db1.text = "ТЫЧОК"
		db1.pressed.connect(func(): decor_sub = "click")
		decor_panel.add_child(db1)
		var db2 = Button.new()
		db2.text = "КИСТЬ"
		db2.pressed.connect(func(): decor_sub = "brush")
		decor_panel.add_child(db2)
		var db3 = Button.new()
		db3.text = "РАНДОМ ЧАНК"
		db3.pressed.connect(func(): decor_sub = "rand")
		decor_panel.add_child(db3)
		var dl = Label.new()
		dl.text = "Радиус кисти"
		decor_panel.add_child(dl)
		var dsl = HSlider.new()
		dsl.min_value = 0.5
		dsl.max_value = 6.0
		dsl.step = 0.5
		dsl.value = decor_radius
		dsl.custom_minimum_size = Vector2(160, 20)
		dsl.value_changed.connect(func(v): decor_radius = v)
		decor_panel.add_child(dsl)
		var dl2 = Label.new()
		dl2.text = "За раз (1-10)"
		decor_panel.add_child(dl2)
		var dsl2 = HSlider.new()
		dsl2.min_value = 1
		dsl2.max_value = 10
		dsl2.step = 1
		dsl2.value = decor_per
		dsl2.custom_minimum_size = Vector2(160, 20)
		dsl2.value_changed.connect(func(v): decor_per = int(v))
		decor_panel.add_child(dsl2)
		var dl3 = Label.new()
		dl3.text = "Размер (0.2-3)"
		decor_panel.add_child(dl3)
		var dsl3 = HSlider.new()
		dsl3.min_value = 0.2
		dsl3.max_value = 3.0
		dsl3.step = 0.1
		dsl3.value = decor_scale
		dsl3.custom_minimum_size = Vector2(160, 20)
		dsl3.value_changed.connect(func(v): decor_scale = v)
		decor_panel.add_child(dsl3)
		light_panel = VBoxContainer.new()
		light_panel.position = Vector2(300, 40)
		light_panel.add_theme_constant_override("separation", 4)
		light_panel.visible = false
		ui.add_child(light_panel)
		var lt = Label.new()
		lt.text = "ОСВЕЩЕНИЕ"
		light_panel.add_child(lt)
		var ll_color = Label.new()
		ll_color.text = "Цвет"
		light_panel.add_child(ll_color)
		var lcb = OptionButton.new()
		lcb.add_item("Тёплый", 0)
		lcb.add_item("Белый", 1)
		lcb.add_item("Холодный", 2)
		lcb.add_item("Красный", 3)
		lcb.add_item("Зелёный", 4)
		lcb.item_selected.connect(_light_color_changed)
		light_panel.add_child(lcb)
		var ll_range = Label.new()
		ll_range.text = "Радиус"
		light_panel.add_child(ll_range)
		var lsr = HSlider.new()
		lsr.min_value = 2.0
		lsr.max_value = 20.0
		lsr.step = 0.5
		lsr.value = 6.0
		lsr.custom_minimum_size = Vector2(160, 20)
		lsr.value_changed.connect(_light_range_changed)
		light_panel.add_child(lsr)
		var ll_energy = Label.new()
		ll_energy.text = "Сила"
		light_panel.add_child(ll_energy)
		var lse = HSlider.new()
		lse.min_value = 1.0
		lse.max_value = 20.0
		lse.step = 0.5
		lse.value = 8.0
		lse.custom_minimum_size = Vector2(160, 20)
		lse.value_changed.connect(_light_energy_changed)
		light_panel.add_child(lse)
		scene_panel = VBoxContainer.new()
		scene_panel.anchor_left = 1.0
		scene_panel.anchor_right = 1.0
		scene_panel.offset_left = -250
		scene_panel.offset_right = -8
		scene_panel.offset_top = 40
		scene_panel.add_theme_constant_override("separation", 4)
		ui.add_child(scene_panel)
		var t1 = Label.new()
		t1.text = "СЦЕНА"
		scene_panel.add_child(t1)
		var sc_l = Label.new()
		sc_l.text = "Солнце цвет"
		scene_panel.add_child(sc_l)
		var scb = OptionButton.new()
		scb.add_item("Тёплое", 0)
		scb.add_item("Нейтральное", 1)
		scb.add_item("Холодное", 2)
		scb.selected = sun_col
		scb.item_selected.connect(_sun_col_changed)
		scene_panel.add_child(scb)
		var l1 = Label.new()
		l1.text = "Солнце сила"
		scene_panel.add_child(l1)
		var s1 = HSlider.new()
		s1.min_value = 0.0
		s1.max_value = 3.0
		s1.step = 0.1
		s1.value = sun_energy
		s1.custom_minimum_size = Vector2(160, 20)
		s1.value_changed.connect(_sun_energy_changed)
		scene_panel.add_child(s1)
		var l2 = Label.new()
		l2.text = "Солнце поворот"
		scene_panel.add_child(l2)
		var s2 = HSlider.new()
		s2.min_value = 0.0
		s2.max_value = 360.0
		s2.step = 5.0
		s2.value = sun_rot
		s2.custom_minimum_size = Vector2(160, 20)
		s2.value_changed.connect(_sun_rot_changed)
		scene_panel.add_child(s2)
		var l3 = Label.new()
		l3.text = "Солнце высота"
		scene_panel.add_child(l3)
		var s3 = HSlider.new()
		s3.min_value = 10.0
		s3.max_value = 80.0
		s3.step = 5.0
		s3.value = sun_elev
		s3.custom_minimum_size = Vector2(160, 20)
		s3.value_changed.connect(_sun_elev_changed)
		scene_panel.add_child(s3)
		var ac_l = Label.new()
		ac_l.text = "Эмбиент цвет"
		scene_panel.add_child(ac_l)
		var acb = OptionButton.new()
		acb.add_item("Тёплый", 0)
		acb.add_item("Белый", 1)
		acb.add_item("Холодный", 2)
		acb.add_item("Зелёный", 3)
		acb.selected = amb_col
		acb.item_selected.connect(_amb_col_changed)
		scene_panel.add_child(acb)
		var l4 = Label.new()
		l4.text = "Эмбиент сила"
		scene_panel.add_child(l4)
		var s4 = HSlider.new()
		s4.min_value = 0.0
		s4.max_value = 2.0
		s4.step = 0.1
		s4.value = amb_energy
		s4.custom_minimum_size = Vector2(160, 20)
		s4.value_changed.connect(_amb_changed)
		scene_panel.add_child(s4)
		var l5 = Label.new()
		l5.text = "Заполняющий"
		scene_panel.add_child(l5)
		var s5 = HSlider.new()
		s5.min_value = 0.0
		s5.max_value = 1.0
		s5.step = 0.05
		s5.value = fill_energy
		s5.custom_minimum_size = Vector2(160, 20)
		s5.value_changed.connect(_fill_changed)
		scene_panel.add_child(s5)
		t1.queue_free()
		var shb = Button.new()
		shb.text = "[-] СЦЕНА"
		scene_panel.add_child(shb)
		scene_panel.move_child(shb, 0)
		shb.pressed.connect(func():
			var open = shb.text.begins_with("[-]")
			for ch in scene_panel.get_children():
				if ch != shb:
					ch.visible = not open
			shb.text = ("[+] СЦЕНА" if open else "[-] СЦЕНА")
		)
		_refresh_btns()
		_upd_edit_hint()
	else:
		_upd_hint()

func _set_wmode(m):
	w_mode = m
	sculpt_btn = ""
	giz_mode = ""
	_refresh_btns()
	_upd_edit_hint()

func _refresh_btns():
	for k in mbtns:
		mbtns[k].modulate = Color(1.6, 1.3, 0.6) if w_mode == k else Color(1, 1, 1)
	if decor_panel != null:
		decor_panel.visible = (w_mode == "decor")
	if light_panel != null:
		light_panel.visible = (w_mode == "light")

func _upd_edit_hint():
	if hint == null:
		return
	var tool = "выбор [1]"
	if w_mode == "point":
		tool = "точка [2]"
	elif w_mode == "light":
		tool = "свет [L] ЛКМ поставить | Shift+ЛКМ выбрать/снять | Ctrl+ЛКМ удалить"
	elif w_mode == "decor":
		tool = "декор [3] (%s) Q/E | Shift+клик выбрать, A/D размер" % DECOR_KINDS[decor_idx]
	elif w_mode == "sculpt":
		tool = "СКУЛЬПТ ЛКМ поднять/Ctrl опустить"
	elif w_mode == "paint":
		tool = "КРАСКА радиус %d [-/+]" % int(w_radius)
	hint.text = "РЕДАКТОР КАРТЫ | %s | Shift+клик по 2 точкам — связь | Ctrl+клик декор — удалить | гизмо: стрелки двигают, зелёная высота, кольцо поворот | ЧАНКИ [4] | Esc выход" % tool
func _exit_edit():
	Game.edit_world = false
	get_tree().call_group("con", "world_changed")
	get_tree().change_scene_to_file("res://overworld3d.tscn")

func _load_terrain():
	terr = load("res://scripts/terrain.gd").new(W_GW, W_GH, W_SUB)
	terr.set_materials(_mat_defs())
	terr.position = Vector3(OFFX, 0, OFFY)
	var d = DataLoader.load_json(W_PATH, {}) if FileAccess.file_exists(W_PATH) else {}
	var bad = int(d.get("ox", 0)) != 0 or int(d.get("oy", 0)) != 0 or int(d.get("gw", 0)) != W_GW
	if bad:
		d = {}
	terr.from_data(d)
	if bad:
		terr.chunk_mask = {}
		for cx in range(4, 8):
			for cy in range(3, 5):
				terr.chunk_mask[str(cx) + "," + str(cy)] = 1
		terr.build()
		terr.splat()

func _lj_arr(p):
	return DataLoader.load_json(p, [])

func _save_terrain():
	if terr == null:
		return
	DataLoader.save_json(W_PATH, terr.to_data())

func _save_decor():
	DataLoader.save_json(DECOR_PATH, DECOR)

func _save_locs():
	DataLoader.save_json("res://data/locations.json", LOCS)

func _h_w(x, z):
	if terr == null:
		return 0.0
	return terr.sample_h(x - OFFX, z - OFFY)

func _arr_check():
	if edit_mode:
		return
	if last_arr == Game.cur_loc:
		return
	last_arr = Game.cur_loc
	Game.goto_hook(Game.cur_loc)
	var dn = Game.arrive_dlg(Game.cur_loc, LOCS)
	if dn != "":
		_play_dlg(dn)

func _upd_hint():
	if hint == null:
		return
	var L = LOCS.get(Game.cur_loc, {})
	hint.text = "%s | Золото %d | Еда %d | День %d %d:00 | Клик по связи — переход, по своей — войти | H лавка S сон J журнал G/L сейв M меню| T говорить" % [str(L.get("name", "")), Game.gold, Game.food, Game.day, Game.hour]
	_arr_check()

func _setup_cam():
	yaw_n = Node3D.new()
	add_child(yaw_n)
	pitch_n = Node3D.new()
	yaw_n.add_child(pitch_n)
	cam = Camera3D.new()
	cam.current = true
	pitch_n.add_child(cam)
	cam.position = Vector3(0, 0, dist)

func live_reload():
	LOCS = DataLoader.load_json("res://data/locations.json")
	LOC_TYPES = DataLoader.load_json("res://data/loc_types.json")
	if edit_mode:
		DECOR = DataLoader.load_json(DECOR_PATH, [])
		if terr != null and terr.get_parent() == self:
			remove_child(terr)
	LIGHTS = DataLoader.load_json(LIGHT_PATH, [])
	chunk_debug_ind = null
	brush_ind = null
	light_gizmo_root = null
	for c in get_children():
		c.queue_free()
	gizmo_root = null
	sel_ring = null
	_setup_cam()
	_build_world()
	_apply()
	_ui()
	if edit_mode:
		_make_chunk_debug()
		_make_brush_ind()

func _mat_defs():
	var m = DataLoader.load_json("res://data/materials.json")
	var d = []
	for k in m:
		d.append({"col": Color(str(m[k].get("color", "#888888"))), "tex": str(m[k].get("tex", ""))})
	return d

func _type_models():
	var tm = {}
	var d = DirAccess.open("res://art")
	if d == null:
		return tm
	d.list_dir_begin()
	var fn = d.get_next()
	while fn != "":
		var low = fn.to_lower()
		if low.ends_with(".fbx") or low.ends_with(".glb") or low.ends_with(".tscn") or low.ends_with(".tres"):
			var pats = {"town": ["house", "dom", "home", "town", "derev"], "camp": ["tent", "shat", "camp", "fire", "kost"], "cave": ["cave", "rock", "stoun", "stone"], "field": ["tree", "derevo", "kust"]}
			for t in pats:
				if not tm.has(t):
					for pat in pats[t]:
						if low.find(pat) >= 0:
							tm[t] = "res://art/" + fn
							break
		fn = d.get_next()
	return tm

func _build_world():
	loc_roots = {}
	link_nodes = []
	var g = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(200, 140)
	var gm = StandardMaterial3D.new()
	gm.albedo_color = Color(0.10, 0.14, 0.10)
	pm.material = gm
	g.mesh = pm
	g.position = Vector3(60, -0.05, 40)
	add_child(g)
	var dl = DirectionalLight3D.new()
	sun_light = dl
	_load_sun()
	dl.light_energy = sun_energy
	dl.rotation_degrees = Vector3(-sun_elev, sun_rot, 0)
	if "directional_shadow_soft" in dl:
		dl.directional_shadow_soft = true
	add_child(dl)
	var fill = DirectionalLight3D.new()
	fill_light = fill
	fill.rotation_degrees = Vector3(-25, -130, 0)
	fill.light_energy = fill_energy
	fill.light_color = Color(0.55, 0.65, 0.9)
	fill.shadow_enabled = false
	add_child(fill)
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.05, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.65)
	env.ambient_light_energy = amb_energy
	world_env = env
	var we = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	if terr != null:
		if terr.get_parent() != null:
			terr.get_parent().remove_child(terr)
		add_child(terr)
	for id in LOCS:
		var L = LOCS[id]
		var wx = L.get("pos", [200, 200])[0] * S
		var wz = L.get("pos", [200, 200])[1] * S
		var root = Node3D.new()
		root.position = Vector3(wx, _h_w(wx, wz), wz)
		add_child(root)
		loc_roots[id] = root
		_loc_mesh(root, L)
		var lb = Label3D.new()
		lb.text = str(L.get("name", id))
		lb.pixel_size = 0.01
		lb.position = Vector3(0, 2.0, 0)
		lb.modulate = Color(1, 0.9, 0.6) if id == Game.cur_loc else Color(0.8, 0.8, 0.8)
		root.add_child(lb)
		if not edit_mode:
			var area = Area3D.new()
			area.input_ray_pickable = true
			var cs = CollisionShape3D.new()
			var sh = SphereShape3D.new()
			sh.radius = 2.5
			cs.shape = sh
			cs.position = Vector3(0, 1.2, 0)
			area.add_child(cs)
			root.add_child(area)
			area.input_event.connect(_on_loc_click.bind(id))
	if not edit_mode:
		_make_token()
	for d in DECOR:
		_decor_node(d)
	_rebuild_lights()
	if edit_mode:
		_update_gizmo()
	for id in LOCS:
		for lk in LOCS[id].get("links", []):
			if str(id) < str(lk) and LOCS.has(lk):
				var a = LOCS[id].get("pos", [0, 0])
				var b = LOCS[lk].get("pos", [0, 0])
				var pa = Vector3(a[0] * S, 0, a[1] * S)
				var pb = Vector3(b[0] * S, 0, b[1] * S)
				_link_line(pa, pb)

func _loc_mesh(root, L):
	var type = str(L.get("type", "field"))
	var model = str(L.get("model", ""))
	var ry = float(L.get("ry", 0.0))
	var myoff = float(L.get("myoff", 0.0))
	if model == "":
		var td = LOC_TYPES.get(type, {})
		model = str(td.get("model", ""))
	if model == "":
		model = str(_type_models().get(type, ""))
	var ms = _eff_ms2(L, LOC_TYPES)
	if model != "" and FileAccess.file_exists(model):
		var res = load(model)
		if res is PackedScene:
			var inst = res.instantiate()
			inst.scale = Vector3(ms * W_LOC_SCALE, ms * W_LOC_SCALE, ms * W_LOC_SCALE)
			inst.rotation = Vector3(deg_to_rad(float(L.get("rx", 0.0))), deg_to_rad(ry), deg_to_rad(float(L.get("rz", 0.0))))
			inst.position = Vector3(0, myoff, 0)
			root.add_child(inst)
			return
	if type == "town":
		var m = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(2.4, 1.6, 2.0)
		var mi = StandardMaterial3D.new()
		mi.albedo_color = Color(0.75, 0.6, 0.4)
		bm.material = mi
		m.mesh = bm
		m.position = Vector3(0, 0.8, 0)
		root.add_child(m)
		var r = MeshInstance3D.new()
		var pm = PrismMesh.new()
		pm.size = Vector3(2.8, 1.0, 2.4)
		var rm = StandardMaterial3D.new()
		rm.albedo_color = Color(0.6, 0.2, 0.15)
		rm.material = rm
		r.mesh = pm
		r.position = Vector3(0, 2.1, 0)
		root.add_child(r)
	elif type == "camp":
		var t = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.1
		cm.bottom_radius = 1.4
		cm.height = 1.8
		var tm = StandardMaterial3D.new()
		tm.albedo_color = Color(0.7, 0.65, 0.55)
		cm.material = tm
		t.mesh = cm
		t.position = Vector3(0, 0.9, 0)
		root.add_child(t)
	else:
		var t = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.1
		cm.bottom_radius = 1.0
		cm.height = 2.2
		var tm = StandardMaterial3D.new()
		tm.albedo_color = Color(0.15, 0.4, 0.2)
		cm.material = tm
		t.mesh = cm
		t.position = Vector3(0, 1.1, 0)
		root.add_child(t)
func _decor_node(d):
	var k = str(d.get("k", "tree"))
	var p = d.get("pos", [0, 0])
	var wx = float(p[0])
	var wz = float(p[1])
	var root = Node3D.new()
	root.position = Vector3(wx, _h_w(wx, wz), wz)
	root.rotation.y = deg_to_rad(float(d.get("rot", 0)))
	var sc = float(d.get("s", 1))
	root.scale = Vector3(sc, sc, sc)
	var od = OBJ3.get(k, {})
	var model = str(od.get("model", ""))
	var oms = float(od.get("mscale", 1.0))
	if oms <= 0.05:
		oms = 1.0
	var img = str(od.get("img", ""))
	if model == "" and img != "" and FileAccess.file_exists(img):
		var t = load(img)
		if t is Texture:
			var sp = Sprite3D.new()
			sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			sp.pixel_size = 0.01
			sp.scale = Vector3(oms, oms, oms)
			sp.position = Vector3(0, 1.2 * oms, 0)
			sp.texture = t
			root.add_child(sp)
			add_child(root)
			decor_nodes.append(root)
			return root
	if model != "" and FileAccess.file_exists(model):
		var res = load(model)
		if res is PackedScene:
			var inst = res.instantiate()
			inst.scale = Vector3(oms, oms, oms)
			inst.position = Vector3(0, float(od.get("myoff", 0.0)), 0)
			root.add_child(inst)
			add_child(root)
			decor_nodes.append(root)
			return root
		elif res is Mesh:
			var m = MeshInstance3D.new()
			m.mesh = res
			m.scale = Vector3(oms, oms, oms)
			m.position = Vector3(0, float(od.get("myoff", 0.0)), 0)
			root.add_child(m)
			add_child(root)
			decor_nodes.append(root)
			return root
		elif res is Texture:
			var mi = StandardMaterial3D.new()
			mi.albedo_texture = res
			mi.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mi.cull_mode = BaseMaterial3D.CULL_DISABLED
			var sz = oms * 2.0
			var q = PlaneMesh.new()
			q.size = Vector2(sz, sz)
			q.material = mi
			var m1 = MeshInstance3D.new()
			m1.mesh = q
			m1.rotation_degrees = Vector3(90, 0, 0)
			m1.position = Vector3(0, sz * 0.5, 0)
			root.add_child(m1)
			var m2 = MeshInstance3D.new()
			m2.mesh = q
			m2.rotation_degrees = Vector3(90, 90, 0)
			m2.position = Vector3(0, sz * 0.5, 0)
			root.add_child(m2)
			add_child(root)
			decor_nodes.append(root)
			return root
	if k == "tree":
		var t = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.1
		cm.bottom_radius = 1.0
		cm.height = 2.2
		var tm = StandardMaterial3D.new()
		tm.albedo_color = Color(0.15, 0.4, 0.2)
		cm.material = tm
		t.mesh = cm
		t.position = Vector3(0, 1.1, 0)
		root.add_child(t)
	elif k == "rock":
		var m = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.9, 0.7, 0.9)
		var mi = StandardMaterial3D.new()
		mi.albedo_color = Color(0.45, 0.45, 0.5)
		bm.material = mi
		m.mesh = bm
		m.position = Vector3(0, 0.35, 0)
		root.add_child(m)
	else:
		var m = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.7, 0.5, 0.7)
		var mi = StandardMaterial3D.new()
		mi.albedo_color = Color(0.55, 0.4, 0.2)
		bm.material = mi
		m.mesh = bm
		m.position = Vector3(0, 0.25, 0)
		root.add_child(m)
	add_child(root)
	decor_nodes.append(root)
	return root
func _update_gizmo():
	if gizmo_root != null:
		gizmo_root.queue_free()
		gizmo_root = null
	if sel_ring != null:
		sel_ring.queue_free()
		sel_ring = null
	if w_sel == "" or not LOCS.has(w_sel):
		return
	var q = _pos3(w_sel)
	var y = _h_w(q.x, q.z)
	sel_ring = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 1.2
	cm.bottom_radius = 1.2
	cm.height = 0.06
	var mi = StandardMaterial3D.new()
	mi.albedo_color = Color(1, 0.9, 0.1, 0.4)
	mi.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.emission_enabled = true
	mi.emission = Color(1, 0.9, 0.1)
	cm.material = mi
	sel_ring.mesh = cm
	sel_ring.position = Vector3(q.x, y + 0.05, q.z)
	add_child(sel_ring)
	gizmo_root = Node3D.new()
	gizmo_root.position = Vector3(q.x, y + float(LOCS[w_sel].get("myoff", 0.0)), q.z)
	add_child(gizmo_root)
	_g_arrow(Vector3(1, 0, 0), Color(1, 0.2, 0.2))
	_g_arrow(Vector3(0, 0, 1), Color(0.3, 0.4, 1))
	_g_arrow(Vector3(0, 1, 0), Color(0.3, 1, 0.3))
	_g_ring(Vector3(0, 1, 0), Color(0.3, 1, 0.3))
	_g_ring(Vector3(1, 0, 0), Color(1, 0.2, 0.2))
	_g_ring(Vector3(0, 0, 1), Color(0.3, 0.4, 1))

func _g_arrow(dirv, col, parent = null):
	if parent == null:
		parent = gizmo_root
	if parent == null:
		return
	var n = Node3D.new()
	var sh = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.08, 0.08, 2.0)
	var m1 = StandardMaterial3D.new()
	m1.albedo_color = col
	m1.emission_enabled = true
	m1.emission = col
	bm.material = m1
	sh.mesh = bm
	sh.position = Vector3(0, 0, 1.0)
	n.add_child(sh)
	var tp = MeshInstance3D.new()
	var cn = CylinderMesh.new()
	cn.top_radius = 0.0
	cn.bottom_radius = 0.15
	cn.height = 0.4
	var m2 = StandardMaterial3D.new()
	m2.albedo_color = col
	m2.emission_enabled = true
	m2.emission = col
	cn.material = m2
	tp.mesh = cn
	tp.position = Vector3(0, 0, 2.1)
	tp.rotation_degrees = Vector3(90, 0, 0)
	n.add_child(tp)
	if dirv == Vector3(1, 0, 0):
		n.rotation_degrees = Vector3(0, 90, 0)
	elif dirv == Vector3(0, 1, 0):
		n.rotation_degrees = Vector3(-90, 0, 0)
	parent.add_child(n)

func _g_ring(axis, col):
	var r = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = 1.2
	tm.outer_radius = 1.35
	var mi = StandardMaterial3D.new()
	mi.albedo_color = col
	mi.emission_enabled = true
	mi.emission = col
	tm.material = mi
	r.mesh = tm
	if axis == Vector3(1, 0, 0):
		r.rotation_degrees = Vector3(0, 0, 90)
	elif axis == Vector3(0, 0, 1):
		r.rotation_degrees = Vector3(90, 0, 0)
	gizmo_root.add_child(r)

func _seg_rd(o, d, a, b):
	var e = b - a
	var dd = d.dot(d)
	var ee = e.dot(e)
	var de = d.dot(e)
	var w0 = o - a
	var c1 = d.dot(w0)
	var c2 = e.dot(w0)
	var den = dd * ee - de * de
	if abs(den) < 0.00001:
		return 999.0
	var t = (de * c2 - ee * c1) / den
	var s2 = clampf((dd * c2 - de * c1) / den, 0.0, 1.0)
	var P = o + d * t
	var Q = a + e * s2
	return (P - Q).length()

func _plane_y(o, d, y):
	if abs(d.y) < 0.0001:
		return -1.0
	var t = (y - o.y) / d.y
	return t if t > 0 else -1.0

func _axis_s(o, d, e, base):
	var dd = d.dot(d)
	var de = d.dot(e)
	var w0 = o - base
	var c1 = d.dot(w0)
	var c2 = e.dot(w0)
	var den = dd * 1.0 - de * de
	if abs(den) < 0.00001:
		return 0.0
	return (dd * c2 - de * c1) / den

func _gizmo_pick(mp):
	if gizmo_root == null:
		return ""
	var c3 = get_viewport().get_camera_3d()
	var o = c3.project_ray_origin(mp)
	var d = c3.project_ray_normal(mp)
	var base = gizmo_root.position
	if _seg_rd(o, d, base, base + Vector3(2, 0, 0)) < 0.25:
		return "mx"
	if _seg_rd(o, d, base, base + Vector3(0, 0, 2)) < 0.25:
		return "mz"
	if _seg_rd(o, d, base, base + Vector3(0, 2, 0)) < 0.25:
		return "my"
	var best = ""
	var bt = 1000000.0
	var t1 = _plane_y(o, d, base.y)
	if t1 > 0 and t1 < bt:
		var hp = o + d * t1
		var r = Vector2(hp.x - base.x, hp.z - base.z).length()
		if r >= 1.0 and r <= 1.6:
			best = "ry"
			bt = t1
	var t2 = _plane_axis(o, d, 0, base.x)
	if t2 > 0 and t2 < bt:
		var hp = o + d * t2
		var r = Vector2(hp.y - base.y, hp.z - base.z).length()
		if r >= 1.0 and r <= 1.6:
			best = "rx"
			bt = t2
	var t3 = _plane_axis(o, d, 2, base.z)
	if t3 > 0 and t3 < bt:
		var hp = o + d * t3
		var r = Vector2(hp.x - base.x, hp.y - base.y).length()
		if r >= 1.0 and r <= 1.6:
			best = "rz"
			bt = t3
	return best

func _gizmo_drag(mp):
	if w_sel == "" or not LOCS.has(w_sel) or gizmo_root == null:
		return
	var c3 = get_viewport().get_camera_3d()
	var o = c3.project_ray_origin(mp)
	var d = c3.project_ray_normal(mp)
	var L = LOCS[w_sel]
	var q = _pos3(w_sel)
	var base = Vector3(q.x, _h_w(q.x, q.z), q.z)
	var root = loc_roots.get(w_sel)
	if giz_mode == "my":
		var s2 = _axis_s(o, d, Vector3(0, 1, 0), base)
		var prev = float(L.get("myoff", 0.0))
		var yo = clampf(giz_start.get("myoff", 0.0) + (s2 - giz_start.get("p", 0.0)), -3.0, 6.0)
		L["myoff"] = yo
		gizmo_root.position.y = base.y + yo
		if root != null:
			var dy = yo - prev
			for c in root.get_children():
				if not (c is Label3D):
					c.position.y += dy
	elif giz_mode == "ry":
		L["ry"] = snapped(giz_start.get("ry", 0.0) + (_ang_y(o, d, base) - giz_start.get("p", 0.0)), 15.0)
		_rot_children(root, L)
	elif giz_mode == "rx":
		L["rx"] = snapped(giz_start.get("rx", 0.0) + (_ang_x(o, d, base) - giz_start.get("p", 0.0)), 15.0)
		_rot_children(root, L)
	elif giz_mode == "rz":
		L["rz"] = snapped(giz_start.get("rz", 0.0) + (_ang_z(o, d, base) - giz_start.get("p", 0.0)), 15.0)
		_rot_children(root, L)
	else:
		var e = Vector3(1, 0, 0) if giz_mode == "mx" else Vector3(0, 0, 1)
		var s2 = _axis_s(o, d, e, base)
		var nx = base.x + (s2 if giz_mode == "mx" else 0.0)
		var nz = base.z + (s2 if giz_mode == "mz" else 0.0)
		nx = clampf(nx, OFFX, OFFX + W_GW)
		nz = clampf(nz, OFFY, OFFY + W_GH)
		L["pos"] = [int(round(nx / S)), int(round(nz / S))]
		var ny = _h_w(nx, nz)
		if root != null:
			root.position = Vector3(nx, ny, nz)
		gizmo_root.position = Vector3(nx, ny + float(L.get("myoff", 0.0)), nz)
		if sel_ring != null:
			sel_ring.position = Vector3(nx, ny + 0.05, nz)

func _make_token():
	token = MeshInstance3D.new()
	var tm = CylinderMesh.new()
	tm.top_radius = 0.8
	tm.bottom_radius = 0.8
	tm.height = 0.15
	var tmi = StandardMaterial3D.new()
	tmi.albedo_color = Color(1, 0.8, 0.2)
	tmi.emission_enabled = true
	tmi.emission = Color(1, 0.7, 0.1)
	tmi.emission_energy_multiplier = 2.0
	tm.material = tmi
	token.mesh = tm
	token.position = _pos3(Game.cur_loc)
	add_child(token)

func _process(_d):
	if traveling:
		target = token.position
		_apply()
	if edit_mode and w_sel != "" and LOCS.has(w_sel):
		_ms_timer += _d
		if _ms_timer >= 0.2:
			_ms_timer = 0.0
			var d = DataLoader.load_json("res://data/locations.json")
			var t = DataLoader.load_json("res://data/loc_types.json")
			var file_ms = _eff_ms2(d.get(w_sel, {}), t)
			var mem_ms = _eff_ms2(LOCS.get(w_sel, {}), LOC_TYPES)
			if abs(file_ms - mem_ms) > 0.0001:
				LOC_TYPES = t
				if str(LOCS[w_sel].get("model", "")) != "":
					LOCS[w_sel]["mscale"] = float(d.get(w_sel, {}).get("mscale", 1.0))
				_prev_ms = -1.0
				_dbg_log("mscale changed: file=%f -> reload" % file_ms)
		var cur_ms = _eff_ms2(LOCS.get(w_sel, {}), LOC_TYPES)
		if abs(cur_ms - _prev_ms) > 0.0001:
			var root = loc_roots.get(w_sel)
			if root != null:
				for c in root.get_children():
					if not (c is Label3D):
						c.scale = Vector3(cur_ms * W_LOC_SCALE, cur_ms * W_LOC_SCALE, cur_ms * W_LOC_SCALE)
			_prev_ms = cur_ms
			_dbg_log("applied scale=%f to %s" % [cur_ms, w_sel])
	if edit_mode and w_mode == "chunk" and terr != null and chunk_debug_ind != null:
		var mp = get_viewport().get_mouse_position()
		var p = _ray(mp)
		if p != null:
			var cx = int(floor((p.x - OFFX) / float(terr.CHUNK)))
			var cy = int(floor((p.z - OFFY) / float(terr.CHUNK)))
			var maxcx = int(terr.GW / terr.CHUNK) - 1
			var maxcy = int(terr.GH / terr.CHUNK) - 1
			if cx < 0 or cy < 0 or cx > maxcx or cy > maxcy:
				chunk_debug_ind.visible = false
			else:
				var wx = OFFX + cx * terr.CHUNK + terr.CHUNK * 0.5
				var wz = OFFY + cy * terr.CHUNK + terr.CHUNK * 0.5
				var wy = terr.sample_h(wx - OFFX, wz - OFFY) + 0.15
				chunk_debug_ind.position = Vector3(wx, wy, wz)
				chunk_debug_ind.visible = true
				var key = str(cx) + "," + str(cy)
				var mi = chunk_debug_ind.mesh.material
				if terr.chunk_mask.has(key):
					mi.albedo_color = Color(1, 0.2, 0.2, 0.5)
				else:
					mi.albedo_color = Color(0.2, 1, 0.2, 0.5)
		else:
			chunk_debug_ind.visible = false
	elif chunk_debug_ind != null:
		chunk_debug_ind.visible = false
	if brush_ind != null:
		if edit_mode and (w_mode == "decor" or w_mode == "sculpt" or w_mode == "paint"):
			var mp2 = get_viewport().get_mouse_position()
			var p2 = _ray(mp2)
			if p2 != null:
				brush_ind.visible = true
				brush_ind.position = Vector3(p2.x, _h_w(p2.x, p2.z) + 0.1, p2.z)
				var r = decor_radius if w_mode == "decor" else w_radius
				brush_ind.scale = Vector3(r, 1, r)
			else:
				brush_ind.visible = false
		else:
			brush_ind.visible = false

func _on_loc_click(_c, ev, _p2, _n, _si, id):
	if not (ev is InputEventMouseButton) or not ev.pressed or ev.button_index != MOUSE_BUTTON_LEFT:
		return
	_click_loc(id)

func _pos3(id):
	var p = LOCS.get(id, {}).get("pos", [200, 200])
	return Vector3(p[0] * S, 0, p[1] * S)

func _click_loc(id):
	var cur = LOCS.get(Game.cur_loc, {})
	if id == Game.cur_loc:
		_enter(id)
		return
	if not cur.get("links", []).has(id):
		_upd_hint()
		return
	if traveling:
		return
	traveling = true
	var tw = create_tween()
	tw.tween_property(token, "position", _pos3(id), 1.2)
	await tw.finished
	traveling = false
	if Game.food > 0:
		Game.food -= 1
	else:
		Game.fatigue += 1
	Game.hour += 2
	if Game.hour >= 24:
		Game.hour -= 24
		Game.day += 1
	Game.cur_loc = id
	Game.autosave()
	_upd_hint()
	if randf() < 0.35 and str(LOCS.get(id, {}).get("type", "")) != "town":
		_make_enc()
	_play_dlg(LOCS.get(id, {}).get("dlg", {}).get("arrive", ""))
	_enter(id)

func _enter(id):
	if str(LOCS.get(Game.cur_loc, {}).get("type", "")) == "town":
		_upd_hint()
	else:
		get_tree().change_scene_to_file("res://explore3d.tscn")  # EXPLORE_ROUTE_V1

func _play_dlg(dn):
	if dn == "":
		return
	var data = DataLoader.load_json("res://data/dialogs/%s.json" % dn, {})
	if data.is_empty():
		return
	var d = load("res://scripts/dialog.gd").new()
	d.chars = CHARS
	add_child(d)
	d.play(data)

func _apply():
	yaw_n.position = target
	yaw_n.rotation = Vector3(0, yaw, 0)
	pitch_n.rotation = Vector3(pitch, 0, 0)
	cam.position = Vector3(0, 0, dist)

func _ray(mp):
	var c3 = get_viewport().get_camera_3d()
	var from = c3.project_ray_origin(mp)
	var dir = c3.project_ray_normal(mp)
	if abs(dir.y) < 0.0001:
		return null
	var t = -from.y / dir.y
	if t < 0:
		return null
	return from + dir * t

func _hit_loc(mp):
	var p = _ray(mp)
	if p == null:
		return ""
	var bi = ""
	var bd = 1.5
	for id in LOCS:
		var q = _pos3(id)
		var d = Vector2(p.x - q.x, p.z - q.z).length()
		if d < bd:
			bd = d
			bi = id
	return bi

func _edit_input(ev):
	if ev is InputEventKey and ev.pressed:
		if ev.keycode == KEY_ESCAPE:
			_exit_edit()
		elif ev.keycode == KEY_1:
			_set_wmode("select")
		elif ev.keycode == KEY_2:
			_set_wmode("point")
		elif ev.keycode == KEY_3:
			_set_wmode("decor")
		elif ev.keycode == KEY_4:
			_set_wmode("chunk")
		elif ev.keycode == KEY_T:
			_set_wmode("sculpt")
		elif ev.keycode == KEY_P:
			_set_wmode("paint")
		elif ev.keycode == KEY_Q:
			if w_mode == "select" and w_sel != "":
				_rot_sel(-15.0)
			else:
				decor_idx = (decor_idx + DECOR_KINDS.size() - 1) % DECOR_KINDS.size()
				_upd_edit_hint()
		elif ev.keycode == KEY_E:
			if w_mode == "select" and w_sel != "":
				_rot_sel(15.0)
			else:
				decor_idx = (decor_idx + 1) % DECOR_KINDS.size()
				_upd_edit_hint()
		elif ev.keycode == KEY_A:
			if w_mode == "decor" and decor_sel >= 0:
				_resize_decor_sel(-0.1)
			else:
				_scale_sel(-0.1)
		elif ev.keycode == KEY_D:
			if w_mode == "decor" and decor_sel >= 0:
				_resize_decor_sel(0.1)
			else:
				_scale_sel(0.1)
		elif ev.keycode == KEY_MINUS:
			w_radius = maxf(1, w_radius - 1)
			_upd_edit_hint()
		elif ev.keycode == KEY_PLUS:
			w_radius = minf(6, w_radius + 1)
			_upd_edit_hint()
		return
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_MIDDLE:
			mid_drag = ev.pressed
			return
		if ev.button_index == MOUSE_BUTTON_RIGHT:
			right_drag = ev.pressed
			return
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			dist = clampf(dist - 2.0, 6, 60)
			_apply()
			return
		if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			dist = clampf(dist + 2.0, 6, 60)
			_apply()
			return
		if ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				_edit_click(ev)
			else:
				if giz_mode != "":
					if giz_mode.begins_with("l"):
						_save_lights()
					else:
						_save_locs()
					giz_mode = ""
				if sculpt_btn != "":
					sculpt_btn = ""
					_save_terrain()
					_rebuild_links()
				if paint_btn:
					paint_btn = false
					_save_terrain()
				if decor_brush_btn:
					decor_brush_btn = false
					_save_decor()
			return
	if ev is InputEventMouseMotion:
		if giz_mode != "" and giz_mode.begins_with("l"):
			_light_gizmo_drag(ev.position)
		elif giz_mode != "":
			_gizmo_drag(ev.position)
		elif right_drag:
			yaw -= ev.relative.x * 0.005
			pitch = clampf(pitch - ev.relative.y * 0.005, -1.45, -0.15)
			_apply()
		elif mid_drag:
			var k = dist * 0.0016
			var right = yaw_n.global_transform.basis.x
			var fwd = -yaw_n.global_transform.basis.z
			target -= right * ev.relative.x * k
			target += fwd * ev.relative.y * k
			_apply()
		elif sculpt_btn != "":
			var p = _ray(ev.position)
			if p != null:
				_brush_at(p)
		elif paint_btn:
			var p = _ray(ev.position)
			if p != null:
				terr.paint_at(p.x - OFFX, p.z - OFFY, w_radius, paint_mat)
		elif decor_brush_btn:
			var p = _ray(ev.position)
			if p != null:
				if ev.ctrl_pressed:
					_erase_decor_at(p, decor_radius)
				else:
					_brush_add_decor(p)

func _edit_click(ev):
	if w_mode == "light" and light_sel >= 0:
		var gm = _light_gizmo_pick(ev.position)
		if gm != "":
			giz_mode = gm
			_light_giz_begin(ev.position)
			return
	if w_mode == "select":
		if w_sel != "":
			var gm = _gizmo_pick(ev.position)
			if gm != "":
				giz_mode = gm
				_giz_begin(ev.position)
				return
	var lid = _hit_loc(ev.position)
	if w_mode == "select":
		if lid != "":
			if ev.shift_pressed and w_sel != "" and lid != w_sel:
				_toggle_link_w(w_sel, lid)
			else:
				w_sel = lid
				get_tree().call_group("con", "world_pick", lid)
				_update_gizmo()
				_prev_ms = -1.0
		else:
			w_sel = ""
			_update_gizmo()
			_prev_ms = -1.0
		return
	var p = _ray(ev.position)
	if p == null:
		return
	if w_mode == "sculpt":
		sculpt_btn = "smooth" if ev.shift_pressed else ("lower" if ev.ctrl_pressed else "raise")
		terr.push_undo()
		_brush_at(p)
	elif w_mode == "paint":
		paint_btn = true
		terr.reset_stroke()
		terr.paint_at(p.x - OFFX, p.z - OFFY, w_radius, paint_mat)
	elif w_mode == "chunk":
		_chunk_at_w(p, ev.ctrl_pressed)
	elif w_mode == "point":
		if lid == "":
			_new_loc_at(p)
	elif w_mode == "light":
		if ev.ctrl_pressed:
			var li = _pick_light_ray(ev.position)
			if li >= 0:
				LIGHTS.remove_at(li)
				_rebuild_lights()
				light_sel = -1
				_update_light_gizmo()
				_save_lights()
		elif ev.shift_pressed:
			var li = _pick_light_ray(ev.position)
			if li >= 0:
				light_sel = li
				_update_light_gizmo()
				if light_panel != null:
					var cb = light_panel.get_child(2) as OptionButton
					if cb:
						var cols = ["#ffd9a0", "#ffffff", "#a0c0ff", "#ff6040", "#80ff80"]
						var cur = str(LIGHTS[li].get("color", "#ffffff"))
						cb.selected = cols.find(cur)
					var sr = light_panel.get_child(4) as HSlider
					if sr:
						sr.value = float(LIGHTS[li].get("range", 6.0))
					var se = light_panel.get_child(6) as HSlider
					if se:
						se.value = float(LIGHTS[li].get("energy", 8.0))
			else:
				light_sel = -1
				_update_light_gizmo()
		else:
			LIGHTS.append({"pos": [p.x, p.z], "y": _h_w(p.x, p.z) + 2.0, "color": "#ffd9a0", "range": 6.0, "energy": 8.0})
			_rebuild_lights()
			light_sel = LIGHTS.size() - 1
			_update_light_gizmo()
			_save_lights()
	elif w_mode == "decor":
		if ev.shift_pressed:
			_pick_decor(p)
			return
		if ev.ctrl_pressed:
			if decor_sub == "brush":
				decor_brush_btn = true
				_erase_decor_at(p, decor_radius)
			else:
				_del_decor_at(p)
		else:
			if decor_sub == "rand":
				_rand_chunk_decor(p)
			elif decor_sub == "brush":
				decor_brush_btn = true
				_brush_add_decor(p)
			else:
				if _try_add_decor(p.x, p.z):
					_save_decor()

func _brush_at(p):
	if terr == null:
		return
	terr.apply_brush(p.x - OFFX, p.z - OFFY, w_radius, 0.15, sculpt_btn)
	_snap_decor_in_radius(p.x, p.z, w_radius)

func _new_loc_at(p):
	var id = "loc_" + str(LOCS.size() + 1)
	while LOCS.has(id):
		id += "x"
	LOCS[id] = {"name": "новая", "type": "field", "pos": [int(round(p.x / S)), int(round(p.z / S))], "links": [], "map": {"rocks": [], "objects": [], "units": []}, "loot": [], "dlg": {}}
	_save_locs()
	w_sel = id
	get_tree().call_group("con", "world_pick", id)
	get_tree().call_group("con", "world_changed")
	live_reload()

func _add_decor(p):
	DECOR.append({"k": DECOR_KINDS[decor_idx], "pos": [p.x, p.z], "s": 1.0, "rot": 0.0})
	_save_decor()
	_decor_node(DECOR[DECOR.size() - 1])

func _del_decor_at(p):
	var bi = -1
	var bd = 2.0
	for i in DECOR.size():
		var q = DECOR[i].get("pos", [0, 0])
		var d = Vector2(p.x - float(q[0]), p.z - float(q[1])).length()
		if d < bd:
			bd = d
			bi = i
	if bi < 0:
		return
	DECOR.remove_at(bi)
	_rebuild_decor()
	_save_decor()

func _toggle_link_w(a, b):
	var la = LOCS[a].get("links", [])
	if la.has(b):
		la.erase(b)
		LOCS[b].get("links", []).erase(a)
	else:
		la.append(b)
		if not LOCS[b].has("links"):
			LOCS[b]["links"] = []
		LOCS[b]["links"].append(a)
	_save_locs()
	get_tree().call_group("con", "world_changed")
	live_reload()

func _chunk_at_w(p, ctrl):
	if terr == null:
		return
	var cx = int(floor((p.x - OFFX) / float(terr.CHUNK)))
	var cy = int(floor((p.z - OFFY) / float(terr.CHUNK)))
	var maxcx = int(terr.GW / terr.CHUNK) - 1
	var maxcy = int(terr.GH / terr.CHUNK) - 1
	if cx < 0 or cy < 0 or cx > maxcx or cy > maxcy:
		print("CHUNK outside — ignore")
		return
	var key = str(cx) + "," + str(cy)
	print("CHUNK click -> (", cx, ",", cy, ") has=", terr.chunk_mask.has(key))
	if ctrl:
		if terr.chunk_mask.has(key):
			terr.chunk_mask.erase(key)
			terr.build()
			terr.splat()
			print("-> REMOVED")
	else:
		if terr.chunk_mask.has(key):
			print("-> уже есть (Ctrl+клик — удалить)")
		else:
			var r = terr.add_chunk(cx, cy)
			print("-> ", "ADDED" if r.ok else "FAIL")
	_save_terrain()
	_rebuild_links()

func _rebuild_links():
	for n in link_nodes:
		if is_instance_valid(n):
			n.queue_free()
	link_nodes = []
	for id in LOCS:
		for lk in LOCS[id].get("links", []):
			if str(id) < str(lk) and LOCS.has(lk):
				var a = LOCS[id].get("pos", [0, 0])
				var b = LOCS[lk].get("pos", [0, 0])
				var pa = Vector3(a[0] * S, 0, a[1] * S)
				var pb = Vector3(b[0] * S, 0, b[1] * S)
				_link_line(pa, pb)

func _refresh_map():
	if terr != null:
		var d = DataLoader.load_json(W_PATH, {}) if FileAccess.file_exists(W_PATH) else {}
		if int(d.get("gw", 0)) == W_GW:
			terr.from_data(d)
	_rebuild_links()

func _link_line(pa, pb):
	var dist = (pb - pa).length()
	if dist < 0.001:
		return
	var steps = int(clampf(dist / 0.35, 4, 220))
	var pts = []
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var p = pa.lerp(pb, t)
		p.y = _h_w(p.x, p.z) + 0.2
		pts.append(p)
	for i in range(1, steps):
		var tmp = pts[i]
		tmp.y = (pts[i - 1].y + pts[i].y * 2.0 + pts[i + 1].y) * 0.25
		pts[i] = tmp
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w = 0.09
	for i in range(steps):
		var p1 = pts[i]
		var p2 = pts[i + 1]
		var h = p2 - p1
		h.y = 0
		if h.length() < 0.0001:
			continue
		h = h.normalized()
		var side = Vector3(-h.z, 0, h.x) * w
		st.add_vertex(p1 - side)
		st.add_vertex(p1 + side)
		st.add_vertex(p2 + side)
		st.add_vertex(p1 - side)
		st.add_vertex(p2 + side)
		st.add_vertex(p2 - side)
	st.generate_normals()
	var am = st.commit()
	var mi = StandardMaterial3D.new()
	mi.albedo_color = Color(0.45, 0.38, 0.28)
	mi.cull_mode = BaseMaterial3D.CULL_DISABLED
	am.surface_set_material(0, mi)
	var m = MeshInstance3D.new()
	m.mesh = am
	add_child(m)
	link_nodes.append(m)

func _make_chunk_debug():
	if chunk_debug_ind != null:
		chunk_debug_ind.queue_free()
	chunk_debug_ind = MeshInstance3D.new()
	var qm = QuadMesh.new()
	qm.size = Vector2(terr.CHUNK, terr.CHUNK)
	var mi = StandardMaterial3D.new()
	mi.albedo_color = Color(0.2, 1, 0.2, 0.4)
	mi.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.material = mi
	chunk_debug_ind.mesh = qm
	chunk_debug_ind.rotation_degrees = Vector3(-90, 0, 0)
	add_child(chunk_debug_ind)
	chunk_debug_ind.visible = false

func _scale_sel(dv):
	var L = LOCS.get(w_sel, {})
	if L.is_empty():
		return
	L["mscale"] = clampf(float(L.get("mscale", 1.0)) + dv, 0.1, 10.0)
	var ms = _eff_ms2(L, LOC_TYPES)
	var root = loc_roots.get(w_sel)
	if root != null:
		for c in root.get_children():
			if not (c is Label3D):
				c.scale = Vector3(ms * W_LOC_SCALE, ms * W_LOC_SCALE, ms * W_LOC_SCALE)
	_prev_ms = ms
	_save_locs()
func _rot_sel(dv):
	var L = LOCS.get(w_sel, {})
	if L.is_empty():
		return
	L["ry"] = float(L.get("ry", 0.0)) + dv
	var root = loc_roots.get(w_sel)
	if root != null:
		var rv = Vector3(deg_to_rad(float(L.get("rx", 0.0))), deg_to_rad(float(L.get("ry", 0.0))), deg_to_rad(float(L.get("rz", 0.0))))
		for c in root.get_children():
			if not (c is Label3D):
				c.rotation = rv
	_save_locs()

func _plane_axis(o, d, comp, val):
	if abs(d[comp]) < 0.0001:
		return -1.0
	var t = (val - o[comp]) / d[comp]
	return t if t > 0 else -1.0

func _ang_y(o, d, base):
	var t = _plane_y(o, d, base.y)
	if t < 0:
		return 0.0
	var hp = o + d * t
	return rad_to_deg(atan2(hp.z - base.z, hp.x - base.x))

func _ang_x(o, d, base):
	var t = _plane_axis(o, d, 0, base.x)
	if t < 0:
		return 0.0
	var hp = o + d * t
	return rad_to_deg(atan2(hp.y - base.y, hp.z - base.z))

func _ang_z(o, d, base):
	var t = _plane_axis(o, d, 2, base.z)
	if t < 0:
		return 0.0
	var hp = o + d * t
	return rad_to_deg(atan2(hp.y - base.y, hp.x - base.x))

func _rot_children(root, L):
	if root == null:
		return
	var rv = Vector3(deg_to_rad(float(L.get("rx", 0.0))), deg_to_rad(float(L.get("ry", 0.0))), deg_to_rad(float(L.get("rz", 0.0))))
	for c in root.get_children():
		if not (c is Label3D):
			c.rotation = rv

func _giz_begin(mp):
	if gizmo_root == null:
		return
	var c3 = get_viewport().get_camera_3d()
	var o = c3.project_ray_origin(mp)
	var d = c3.project_ray_normal(mp)
	var base = gizmo_root.position
	var L = LOCS.get(w_sel, {})
	giz_start = {"myoff": float(L.get("myoff", 0.0)), "ry": float(L.get("ry", 0.0)), "rx": float(L.get("rx", 0.0)), "rz": float(L.get("rz", 0.0)), "p": 0.0}
	if giz_mode == "my":
		giz_start["p"] = _axis_s(o, d, Vector3(0, 1, 0), base)
	elif giz_mode == "ry":
		giz_start["p"] = _ang_y(o, d, base)
	elif giz_mode == "rx":
		giz_start["p"] = _ang_x(o, d, base)
	elif giz_mode == "rz":
		giz_start["p"] = _ang_z(o, d, base)

func _unhandled_input(ev):
	if edit_mode:
		_edit_input(ev)
		return
	if ev is InputEventKey and ev.pressed:
		if ev.keycode == KEY_M:
			Game.clear_transient_state()
			get_tree().change_scene_to_file("res://menu.tscn")
			return
		if ev.keycode == KEY_T:
			_talk()
			return
		if ev.keycode == KEY_I:
			var hub = load("res://scripts/game_hub.gd").new()
			add_child(hub)
			return
		if ev.keycode == KEY_P:
			var pu = load("res://scripts/party_ui.gd").new()
			add_child(pu)
			return
		if ev.keycode == KEY_R:
			var cu = load("res://scripts/camp_ui.gd").new()
			add_child(cu)
			return
		if ev.keycode == KEY_N and str(LOCS.get(Game.cur_loc, {}).get("type", "")) == "town":
			var tv = load("res://scripts/tavern.gd").new()
			add_child(tv)
			return
		if ev.keycode == KEY_E:
			get_tree().change_scene_to_file("res://explore3d.tscn")
			return
		if ev.keycode == KEY_J:
			var j = load("res://scripts/journal.gd").new()
			add_child(j)
			return
		if ev.keycode == KEY_G:
			Game.save_game()
			return
		if ev.keycode == KEY_L:
			if Game.load_game():
				live_reload()
			return
		if ev.keycode == KEY_H and str(LOCS.get(Game.cur_loc, {}).get("type", "")) == "town":
			var s = load("res://scripts/shop.gd").new()
			s.stock = LOCS.get(Game.cur_loc, {}).get("shop", ["potion", "food"])
			add_child(s)
			return
		if ev.keycode == KEY_S and str(LOCS.get(Game.cur_loc, {}).get("type", "")) == "town":
			Game.day += 1
			Game.hour = 8
			Game.fatigue = 0
			_upd_hint()
			return
	if ev is InputEventMouseButton:
		if ev.pressed and ev.button_index == MOUSE_BUTTON_MIDDLE:
			mid_drag = true
		elif not ev.pressed and ev.button_index == MOUSE_BUTTON_MIDDLE:
			mid_drag = false
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
			right_drag = true
		elif not ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
			right_drag = false
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist = clampf(dist - 2.0, 8, 80)
			_apply()
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist = clampf(dist + 2.0, 8, 80)
			_apply()
	elif ev is InputEventMouseMotion:
		if right_drag:
			yaw -= ev.relative.x * 0.005
			pitch = clampf(pitch - ev.relative.y * 0.005, -1.45, -0.15)
			_apply()
		elif mid_drag:
			var k = dist * 0.0016
			var right = yaw_n.global_transform.basis.x
			var fwd = -yaw_n.global_transform.basis.z
			target -= right * ev.relative.x * k
			target += fwd * ev.relative.y * k
			_apply()

func _make_enc():
	var cls = ["assassin", "swordsman", "archer", "halberd"]
	var units = []
	for i in range(2 + randi() % 2):
		units.append({"cls": cls[randi() % cls.size()], "team": 1, "cell": [6, 1 + i * 2]})
	var objs = []
	for i in range(4):
		objs.append({"cell": [2 + randi() % 4, randi() % 6], "k": "tree" if randf() < 0.5 else "rock"})
	Game.enc = {"map": {"rocks": [], "objects": objs, "units": units}, "gold": 6 + randi() % 12}

func _talk():
	var here = []
	for cid in CHARS:
		if str(CHARS[cid].get("loc", "")) == Game.cur_loc:
			here.append(cid)
	if here.size() == 0:
		return
	var ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(func(ev2):
		if ev2 is InputEventMouseButton and ev2.pressed:
			ui.queue_free())
	ui.add_child(bg)
	var box = VBoxContainer.new()
	box.position = Vector2(300, 200)
	ui.add_child(box)
	var t = Label.new()
	t.text = "Говорить с:"
	box.add_child(t)
	for cid in here:
		var b = Button.new()
		b.text = str(Game.resolve_char(cid).get("name", cid))
		b.pressed.connect(func():
			ui.queue_free()
			var dn = Game.talk_dlg(cid)
			if dn == "":
				dn = str(Game.resolve_char(cid).get("dlg", ""))
			if dn != "":
				_play_dlg(dn))
		box.add_child(b)
	var x = Button.new()
	x.text = "Закрыть"
	x.pressed.connect(func(): ui.queue_free())
	box.add_child(x)
	add_child(ui)

func _on_world_changed():
	LOCS = DataLoader.load_json("res://data/locations.json")
	LOC_TYPES = DataLoader.load_json("res://data/loc_types.json")
	_prev_ms = -1.0
	print("WORLD_CHANGED: LOCS reloaded")

func _dbg_log(t):
	if not FileAccess.file_exists("res://ms_debug.txt"):
		var f0 = FileAccess.open("res://ms_debug.txt", FileAccess.WRITE)
		if f0 != null: f0.close()
	var f = FileAccess.open("res://ms_debug.txt", FileAccess.READ_WRITE)
	if f != null:
		f.seek_end()
		f.store_line(t)
		f.close()

func _eff_ms2(L, types):
	if str(L.get("model", "")) != "":
		return clampf(float(L.get("mscale", 1.0)), 0.1, 10.0)
	var td = types.get(str(L.get("type", "field")), {})
	var ms = float(td.get("mscale", 1.0))
	if ms <= 0.05:
		ms = 1.0
	return clampf(ms, 0.1, 10.0)

func _can_place(x, z, md):
	for d in DECOR:
		var q = d.get("pos", [0, 0])
		var dx = x - float(q[0])
		var dz = z - float(q[1])
		if dx * dx + dz * dz < md * md:
			return false
	for id in LOCS:
		var q = LOCS[id].get("pos", [200, 200])
		var lx = float(q[0]) * S
		var lz = float(q[1]) * S
		var dx = x - lx
		var dz = z - lz
		var rr = md + 1.0
		if dx * dx + dz * dz < rr * rr:
			return false
	return true
func _try_add_decor(x, z):
	if not _can_place(x, z, DECOR_MIN):
		return false
	var kind = DECOR_KINDS[decor_idx]
	DECOR.append({"k": kind, "pos": [x, z], "s": decor_scale, "rot": randf() * 360.0})
	_decor_node(DECOR[DECOR.size() - 1])
	return true
func _erase_decor_at(p, r):
	var changed = false
	for i in range(DECOR.size() - 1, -1, -1):
		var q = DECOR[i].get("pos", [0, 0])
		var dx = p.x - float(q[0])
		var dz = p.z - float(q[1])
		if dx * dx + dz * dz <= r * r:
			DECOR.remove_at(i)
			changed = true
	if changed:
		decor_sel = -1  # _erase_decor_at сброс
		_rebuild_decor()
func _rebuild_decor():
	decor_sel = -1
	for n in decor_nodes:
		if is_instance_valid(n):
			n.queue_free()
	decor_nodes = []
	for d in DECOR:
		_decor_node(d)
func _rand_chunk_decor(p):
	if terr == null:
		return
	var cx = int(floor((p.x - OFFX) / float(terr.CHUNK)))
	var cy = int(floor((p.z - OFFY) / float(terr.CHUNK)))
	var x0 = OFFX + cx * terr.CHUNK
	var z0 = OFFY + cy * terr.CHUNK
	var x1 = x0 + terr.CHUNK
	var z1 = z0 + terr.CHUNK
	for i in range(DECOR.size() - 1, -1, -1):
		var q = DECOR[i].get("pos", [0, 0])
		var qx = float(q[0])
		var qz = float(q[1])
		if qx >= x0 and qx < x1 and qz >= z0 and qz < z1:
			DECOR.remove_at(i)
	for a in range(80):
		var rx = x0 + randf() * terr.CHUNK
		var rz = z0 + randf() * terr.CHUNK
		if _can_place(rx, rz, DECOR_MIN):
			var kind = DECOR_KINDS[randi() % DECOR_KINDS.size()]
			DECOR.append({"k": kind, "pos": [rx, rz], "s": decor_scale, "rot": randf() * 360.0})
	_rebuild_decor()
	_save_decor()
func _brush_add_decor(p):
	var n = int(decor_per)
	for i in range(n):
		var rx = p.x
		var rz = p.z
		if n > 1:
			var ang = randf() * TAU
			var rr = sqrt(randf()) * decor_radius
			rx = p.x + cos(ang) * rr
			rz = p.z + sin(ang) * rr
		if _can_place(rx, rz, DECOR_MIN):
			var kind = DECOR_KINDS[decor_idx]
			DECOR.append({"k": kind, "pos": [rx, rz], "s": decor_scale, "rot": randf() * 360.0})
			_decor_node(DECOR[DECOR.size() - 1])
func _make_brush_ind():
	if brush_ind != null:
		brush_ind.queue_free()
	brush_ind = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = 0.98
	tm.outer_radius = 1.0
	var mi = StandardMaterial3D.new()
	mi.albedo_color = Color(1, 1, 0.2, 0.25)
	mi.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.material = mi
	brush_ind.mesh = tm
	add_child(brush_ind)
	brush_ind.visible = false

func _pick_decor(p):
	var bi = -1
	var bd = 2.0
	for i in DECOR.size():
		var q = DECOR[i].get("pos", [0, 0])
		var d = Vector2(p.x - float(q[0]), p.z - float(q[1])).length()
		if d < bd:
			bd = d
			bi = i
	decor_sel = bi
	if bi >= 0:
		print("DECOR sel #", bi, " s=", DECOR[bi].get("s", 1.0), " (A/D — размер)")
func _resize_decor_sel(dv):
	if decor_sel < 0 or decor_sel >= DECOR.size():
		return
	var ns = clampf(float(DECOR[decor_sel].get("s", 1.0)) + dv, 0.2, 3.0)
	DECOR[decor_sel]["s"] = ns
	if decor_sel < decor_nodes.size() and is_instance_valid(decor_nodes[decor_sel]):
		decor_nodes[decor_sel].scale = Vector3(ns, ns, ns)
	_save_decor()

func _snap_decor_in_radius(cx, cz, r):
	if terr == null:
		return
	var r2 = r * r
	for i in DECOR.size():
		if i >= decor_nodes.size():
			break
		var d = DECOR[i]
		var q = d.get("pos", [0, 0])
		var wx = float(q[0])
		var wz = float(q[1])
		var dx = wx - cx
		var dz = wz - cz
		if dx * dx + dz * dz <= r2:
			var ny = _h_w(wx, wz)
			if is_instance_valid(decor_nodes[i]):
				decor_nodes[i].position.y = ny

func _save_lights():
	DataLoader.save_json(LIGHT_PATH, LIGHTS)

func _light_color_changed(i):
	if light_sel < 0 or light_sel >= LIGHTS.size():
		return
	var cols = ["#ffd9a0", "#ffffff", "#a0c0ff", "#ff6040", "#80ff80"]
	LIGHTS[light_sel]["color"] = cols[i]
	_update_light_node(light_sel)
	_save_lights()
func _light_range_changed(v):
	if light_sel < 0 or light_sel >= LIGHTS.size():
		return
	LIGHTS[light_sel]["range"] = v
	_update_light_node(light_sel)
	_save_lights()
func _light_energy_changed(v):
	if light_sel < 0 or light_sel >= LIGHTS.size():
		return
	LIGHTS[light_sel]["energy"] = v
	_update_light_node(light_sel)
	_save_lights()
func _update_light_node(i):
	if i < 0 or i >= LIGHTS.size() or i >= light_nodes.size():
		return
	var node = light_nodes[i]
	if not is_instance_valid(node):
		return
	var ld = LIGHTS[i]
	var omni = node.get_node("OmniLight3D") if node.has_node("OmniLight3D") else null
	if omni:
		omni.light_color = Color(str(ld.get("color", "#ffffff")))
		omni.light_energy = float(ld.get("energy", 8.0))
		omni.omni_range = float(ld.get("range", 6.0))
func _add_light_node(ld):
	var root = Node3D.new()
	var pos = ld.get("pos", [0, 0])
	root.position = Vector3(float(pos[0]), float(ld.get("y", 2.0)), float(pos[1]))
	var omni = OmniLight3D.new()
	omni.name = "OmniLight3D"
	omni.light_color = Color(str(ld.get("color", "#ffffff")))
	omni.light_energy = float(ld.get("energy", 8.0))
	omni.omni_range = float(ld.get("range", 6.0))
	root.add_child(omni)
	if edit_mode:
		var ind = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = 0.2
		sm.height = 0.4
		var mi = StandardMaterial3D.new()
		mi.albedo_color = Color(1, 1, 0.2)
		mi.emission_enabled = true
		mi.emission = Color(1, 1, 0.2)
		sm.material = mi
		ind.mesh = sm
		root.add_child(ind)
	add_child(root)
	light_nodes.append(root)
	return root
func _rebuild_lights():
	for n in light_nodes:
		if is_instance_valid(n):
			n.queue_free()
	light_nodes = []
	for ld in LIGHTS:
		_add_light_node(ld)
func _pick_light(p):
	var bi = -1
	var bd = 2.0
	for i in LIGHTS.size():
		var ld = LIGHTS[i]
		var pos = ld.get("pos", [0, 0])
		var lx = float(pos[0])
		var lz = float(pos[1])
		var ly = float(ld.get("y", 2.0))
		var dx = p.x - lx
		var dz = p.z - lz
		var dy = _h_w(p.x, p.z) - ly
		var d = sqrt(dx * dx + dz * dz + dy * dy)
		if d < bd:
			bd = d
			bi = i
	return bi
func _light_gizmo_pick(mp):
	if light_gizmo_root == null:
		return ""
	var c3 = get_viewport().get_camera_3d()
	var o = c3.project_ray_origin(mp)
	var d = c3.project_ray_normal(mp)
	var base = light_gizmo_root.position
	if _seg_rd(o, d, base, base + Vector3(2, 0, 0)) < 0.25:
		return "lmx"
	if _seg_rd(o, d, base, base + Vector3(0, 0, 2)) < 0.25:
		return "lmz"
	if _seg_rd(o, d, base, base + Vector3(0, 2, 0)) < 0.25:
		return "lmy"
	return ""
func _light_gizmo_drag(mp):
	if light_sel < 0 or light_sel >= LIGHTS.size() or light_gizmo_root == null:
		return
	var c3 = get_viewport().get_camera_3d()
	var o = c3.project_ray_origin(mp)
	var d = c3.project_ray_normal(mp)
	var ld = LIGHTS[light_sel]
	var pos = ld.get("pos", [0, 0])
	var base = Vector3(float(pos[0]), float(ld.get("y", 2.0)), float(pos[1]))
	if giz_mode == "lmy":
		var s2 = _axis_s(o, d, Vector3(0, 1, 0), base)
		var ny = clampf(giz_start.get("ly", 2.0) + (s2 - giz_start.get("p", 0.0)), 0.5, 10.0)
		ld["y"] = ny
		light_gizmo_root.position.y = ny
		if light_sel < light_nodes.size() and is_instance_valid(light_nodes[light_sel]):
			light_nodes[light_sel].position.y = ny
	elif giz_mode == "lmx" or giz_mode == "lmz":
		var e = Vector3(1, 0, 0) if giz_mode == "lmx" else Vector3(0, 0, 1)
		var s2 = _axis_s(o, d, e, base)
		var nx = base.x + (s2 if giz_mode == "lmx" else 0.0)
		var nz = base.z + (s2 if giz_mode == "lmz" else 0.0)
		ld["pos"] = [nx, nz]
		light_gizmo_root.position = Vector3(nx, float(ld.get("y", 2.0)), nz)
		if light_sel < light_nodes.size() and is_instance_valid(light_nodes[light_sel]):
			light_nodes[light_sel].position = Vector3(nx, float(ld.get("y", 2.0)), nz)
func _light_giz_begin(mp):
	if light_gizmo_root == null or light_sel < 0:
		return
	var c3 = get_viewport().get_camera_3d()
	var o = c3.project_ray_origin(mp)
	var d = c3.project_ray_normal(mp)
	var base = light_gizmo_root.position
	var ld = LIGHTS[light_sel]
	giz_start = {"ly": float(ld.get("y", 2.0)), "p": 0.0}
	if giz_mode == "lmy":
		giz_start["p"] = _axis_s(o, d, Vector3(0, 1, 0), base)
func _update_light_gizmo():
	if light_gizmo_root != null:
		light_gizmo_root.queue_free()
		light_gizmo_root = null
	if light_sel < 0 or light_sel >= LIGHTS.size():
		return
	var ld = LIGHTS[light_sel]
	var pos = ld.get("pos", [0, 0])
	var px = float(pos[0])
	var pz = float(pos[1])
	var py = float(ld.get("y", 2.0))
	light_gizmo_root = Node3D.new()
	light_gizmo_root.position = Vector3(px, py, pz)
	add_child(light_gizmo_root)
	_g_arrow(Vector3(1, 0, 0), Color(1, 0.8, 0.2), light_gizmo_root)
	_g_arrow(Vector3(0, 0, 1), Color(1, 0.8, 0.2), light_gizmo_root)
	_g_arrow(Vector3(0, 1, 0), Color(1, 0.8, 0.2), light_gizmo_root)

func _pick_light_ray(mp):
	var c3 = get_viewport().get_camera_3d()
	var o = c3.project_ray_origin(mp)
	var d = c3.project_ray_normal(mp)
	var bi = -1
	var bd = 1.5
	for i in LIGHTS.size():
		var ld = LIGHTS[i]
		var pos = ld.get("pos", [0, 0])
		var lx = float(pos[0])
		var lz = float(pos[1])
		var c = Vector3(lx, _h_w(lx, lz) + float(ld.get("y", 2.0)), lz)
		var w = c - o
		var t = w.dot(d)
		if t < 0:
			continue
		var closest = o + d * t
		var dist = (c - closest).length()
		if dist < bd:
			bd = dist
			bi = i
	return bi

func _load_sun():
	var d = DataLoader.load_json(SUN_PATH, {})
	sun_energy = float(d.get("energy", 1.0))
	sun_rot = float(d.get("rot", 30.0))
	sun_elev = float(d.get("elev", 50.0))
	sun_col = int(d.get("suncol", 0))
	amb_energy = float(d.get("amb", 0.6))
	amb_col = int(d.get("ambcol", 1))
	fill_energy = float(d.get("fill", 0.3))
func _save_sun():
	DataLoader.save_json(SUN_PATH, {"energy": sun_energy, "rot": sun_rot, "elev": sun_elev, "suncol": sun_col, "amb": amb_energy, "ambcol": amb_col, "fill": fill_energy})
func _apply_sun():
	var sun_cols = ["fff2dd", "ffffff", "dfe8ff"]
	var amb_cols = ["ffd9a0", "ffffff", "a0c0ff", "80ff80"]
	if sun_light != null:
		sun_light.light_energy = sun_energy
		sun_light.light_color = Color("#" + sun_cols[clampi(sun_col, 0, 2)])
		sun_light.rotation_degrees = Vector3(-sun_elev, sun_rot, 0)
	if fill_light != null:
		fill_light.light_energy = fill_energy
	if world_env != null:
		world_env.ambient_light_energy = amb_energy
		world_env.ambient_light_color = Color("#" + amb_cols[clampi(amb_col, 0, 3)])
func _sun_energy_changed(v):
	sun_energy = v
	_apply_sun()
	_save_sun()
func _sun_rot_changed(v):
	sun_rot = v
	_apply_sun()
	_save_sun()
func _sun_elev_changed(v):
	sun_elev = v
	_apply_sun()
	_save_sun()
func _sun_col_changed(i):
	sun_col = i
	_apply_sun()
	_save_sun()
func _amb_changed(v):
	amb_energy = v
	_apply_sun()
	_save_sun()
func _amb_col_changed(i):
	amb_col = i
	_apply_sun()
	_save_sun()
func _fill_changed(v):
	fill_energy = v
	_apply_sun()
	_save_sun()
