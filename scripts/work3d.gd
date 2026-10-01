# Редактор/мастерская 3D-локаций (Work3D)
# Служит 3D-вьювером и редактором ландшафта, чанков, света и декораций локации.
# Работает в тандеме с Конструктором (scripts/constructor.gd) и 2D-сеткой (scripts/loc_editor.gd / loc_grid.gd).
extends Node3D

var light_mode = false
var chunk_del_mode = false
var btn_sculpt = null
var btn_paint = null
var btn_chunk = null
var btn_chunkdel = null
var btn_free = null
var btn_light = null
var spawn_mode = false
var btn_spawn = null
var light_sel = -1
var light_drag = false
var light_press = Vector2()
var light_moved = false
var LIGHTS = []
var light_nodes = []
var giz_mode = ""
var gizmo_root = null
var sel_ind = null

var yaw_n: Node3D
var pitch_n: Node3D
var cam: Camera3D
var yaw = 0.6
var pitch = -0.9
var dist = 10.0
var target = Vector3(4, 0, 3)
var mid_drag = false
var right_drag = false
var terr = null
var content: Node3D
var CLASSES = {}
var OBJ3 = {}
var CHARS = {} 
var sculpt = false
var paint_mode = false
var chunk_mode = false
var free_mode = false
var free_sel = -1
var free_drag = false
var free_press = Vector2()
var free_moved = false
var FL = []
var free_nodes = []
var sculpt_btn = ""
var brush_radius = 1.5
var strength = 0.06
var force_mode = false
var radius_mode = false
var paint_mat = 0
var brush_ind = null
var ind_alpha = 0.07
var str_slider: HSlider
var rad_slider: HSlider
var str_lab: Label
var rad_lab: Label
var mat_opt: OptionButton
var tool_lab: Label
var _rb_pending = false
var _rb_time = 0
var dbg_root = null
var dbg_lab = null
func _ready():
	add_to_group("work")
	Game.log_scene("work3d_ready")
	if get_tree().get_nodes_in_group("work").size() > 1:
		queue_free()
		return
	CLASSES = DataLoader.load_json("res://data/classes.json")
	OBJ3 = DataLoader.load_json("res://data/objects.json")
	CHARS = DataLoader.load_json("res://data/chars.json")
	yaw_n = Node3D.new()
	add_child(yaw_n)
	pitch_n = Node3D.new()
	yaw_n.add_child(pitch_n)
	cam = Camera3D.new()
	pitch_n.add_child(cam)
	cam.position = Vector3(0, 0, dist)
	var dl = DirectionalLight3D.new()
	dl.rotation_degrees = Vector3(-50, 30, 0)
	if "directional_shadow_soft" in dl:
		dl.directional_shadow_soft = true
	add_child(dl)
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, -130, 0)
	fill.light_energy = 0.3
	fill.light_color = Color(0.55, 0.65, 0.9)
	fill.shadow_enabled = false
	add_child(fill)
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.65)
	env.ambient_light_energy = 0.6
	var we = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	content = Node3D.new()
	add_child(content)
	_ui()
	print("WORK3D READY")
	load_edit()
	_apply()
func _ui():
	var ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	var col = VBoxContainer.new()
	col.position = Vector2(10, 10)
	col.add_theme_constant_override("separation", 6)
	ui.add_child(col)
	var pn = _panel(col, "НАВИГАЦИЯ", false)
	var bb = Button.new()
	bb.text = "← в игру"
	bb.pressed.connect(func(): get_tree().call_group("con", "_edit_back"))
	pn.add_child(bb)
	var pt = _panel(col, "ИНСТРУМЕНТЫ", true)
	tool_lab = Label.new()
	tool_lab.autowrap_mode = TextServer.AUTOWRAP_WORD
	tool_lab.custom_minimum_size = Vector2(260, 0)
	pt.add_child(tool_lab)
	var bch = Button.new()
	bch.text = "ЧАНКИ [C]"
	bch.pressed.connect(func():
		chunk_mode = not chunk_mode
		_upd_tool())
	pt.add_child(bch)
	btn_chunk = bch
	var bsc = Button.new()
	bsc.text = "СКУЛЬПТ [T]"
	bsc.pressed.connect(func():
		sculpt = not sculpt
		_make_ind()
		_upd_tool())
	pt.add_child(bsc)
	btn_sculpt = bsc
	var bpt = Button.new()
	bpt.text = "КРАСКА [P]"
	bpt.pressed.connect(func():
		paint_mode = not paint_mode
		_upd_tool())
	pt.add_child(bpt)
	btn_paint = bpt
	var bfr = Button.new()
	bfr.text = "СВОБОДНО"
	bfr.pressed.connect(func():
		free_mode = not free_mode
		free_sel = -1
		_upd_tool())
	pt.add_child(bfr)
	btn_free = bfr
	var blight = Button.new()
	blight.text = "СВЕТ"
	blight.pressed.connect(func():
		light_mode = not light_mode
		light_sel = -1
		_upd_tool())
	pt.add_child(blight)
	btn_light = blight
	var bsp = Button.new()
	bsp.text = "ТОЧКА ВХОДА [V]"
	bsp.pressed.connect(func():
		spawn_mode = not spawn_mode
		_upd_tool())
	pt.add_child(bsp)
	btn_spawn = bsp
	var pk = _panel(col, "КИСТЬ", false)
	str_slider = HSlider.new()
	str_slider.min_value = 0.01
	str_slider.max_value = 0.25
	str_slider.step = 0.005
	str_slider.value = strength
	str_slider.custom_minimum_size = Vector2(180, 20)
	str_slider.value_changed.connect(func(v): strength = v; _upd_str(); _flash())
	pk.add_child(str_slider)
	str_lab = Label.new()
	pk.add_child(str_lab)
	rad_slider = HSlider.new()
	rad_slider.min_value = 0.125
	rad_slider.max_value = 4.0
	rad_slider.step = 0.125
	rad_slider.value = brush_radius
	rad_slider.custom_minimum_size = Vector2(180, 20)
	rad_slider.value_changed.connect(func(v): brush_radius = v; _upd_rad(); _make_ind(); _flash())
	pk.add_child(rad_slider)
	rad_lab = Label.new()
	pk.add_child(rad_lab)
	mat_opt = OptionButton.new()
	mat_opt.custom_minimum_size = Vector2(140, 26)
	var m = DataLoader.load_json("res://data/materials.json")
	for k in m:
		mat_opt.add_item(str(m[k].get("name", k)))
	mat_opt.item_selected.connect(func(i): paint_mat = i)
	pk.add_child(mat_opt)
	var pg = _panel(col, "GODOT", false)
	var bgod = Button.new()
	bgod.text = "В GODOT"
	bgod.pressed.connect(_send_to_godot)
	pg.add_child(bgod)
	var bdone = Button.new()
	bdone.text = "ГОТОВО (сохранить)"
	bdone.pressed.connect(_import_tscn)
	pg.add_child(bdone)
	_upd_str()
	_upd_rad()
	_upd_tool()
func _panel(parent, title, open = true):
	var pc = PanelContainer.new()
	parent.add_child(pc)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	pc.add_child(vb)
	var hb = Button.new()
	hb.text = ("[-] " if open else "[+] ") + title
	vb.add_child(hb)
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	body.visible = open
	vb.add_child(body)
	hb.pressed.connect(func():
		body.visible = not body.visible
		hb.text = ("[-] " if body.visible else "[+] ") + title)
	return body
func _upd_tool():
	if tool_lab != null:
		var mode = "ставить" if str(Game.edit_tool) == "place" else "стереть"
		if chunk_mode:
			mode = "чанк: клик добавить | Ctrl+клик удалить"
		elif sculpt:
			mode = "скульпт"
		elif paint_mode:
			mode = "краска"
		elif free_mode:
			mode = "свободно"
		elif light_mode:
			mode = "свет"
		tool_lab.text = "РЕЖИМ: %s | Shift — выбрать | Ctrl — удалить | Q/E поворот | R/F высота" % mode
	var on = Color(1.6, 1.3, 0.6)
	var off = Color(1, 1, 1)
	if btn_chunk != null:
		btn_chunk.modulate = on if chunk_mode else off
	if btn_sculpt != null:
		btn_sculpt.modulate = on if sculpt else off
	if btn_paint != null:
		btn_paint.modulate = on if paint_mode else off
	if btn_free != null:
		btn_free.modulate = on if free_mode else off
	if btn_light != null:
		btn_light.modulate = on if light_mode else off
	if btn_spawn != null:
		btn_spawn.modulate = on if spawn_mode else off
func _upd_str():
	if str_lab != null:
		str_lab.text = "сила %.3f" % strength
func _upd_rad():
	if rad_lab != null:
		rad_lab.text = "радиус %.2f" % brush_radius
func _flash():
	ind_alpha = 0.3
	if brush_ind != null:
		brush_ind.mesh.material.albedo_color = Color(1, 1, 1, ind_alpha)
func _tex(path):
	if path == "" or not FileAccess.file_exists(path):
		return null
	var im = Image.new()
	if im.load(path) != OK:
		return null
	return ImageTexture.create_from_image(im)
func _mat_defs():
	var m = DataLoader.load_json("res://data/materials.json")
	var defs = []
	for k in m:
		defs.append({"col": Color(str(m[k].get("color", "#888888"))), "tex": str(m[k].get("tex", ""))})
	return defs
func L():
	return Game.edit_data if Game.edit_data != null else {}
func load_edit():
	sculpt = false
	paint_mode = false
	CLASSES = DataLoader.load_json("res://data/classes.json")
	OBJ3 = DataLoader.load_json("res://data/objects.json")
	CHARS = DataLoader.load_json("res://data/chars.json")
	_rb_pending = true
	_upd_tool()
func _process(_d):
	if _rb_pending and (Time.get_ticks_msec() - _rb_time) > 150:
		_rb_pending = false
		_rb_time = Time.get_ticks_msec()
		rebuild()
func rebuild():
	for c in content.get_children():
		c.free()
	terr = null
	if brush_ind != null:
		brush_ind.queue_free()
		brush_ind = null
	var tdm = L().get("terrain", {})
	if tdm.size() > 0 and not tdm.get("migrated", false) and not tdm.has("chunks"):
		L()["terrain"] = _migrate(tdm)
	var td0 = L().get("terrain", {})
	terr = load("res://scripts/terrain.gd").new(int(td0.get("gw", 8)), int(td0.get("gh", 6)), int(td0.get("sub", 8)))
	content.add_child(terr)
	terr.set_materials(_mat_defs())
	terr.show_chunk_grid = true
	var td = td0
	if td.size() > 0:
		terr.from_data(td)
	else:
		terr.build()
	var m = L().get("map", {})
	for o in m.get("objects", []):
		_obj3(Vector3(o["cell"][0] + 0.5, 0, o["cell"][1] + 0.5), o.get("k", "rock"))
	for r in m.get("rocks", []):
		_obj3(Vector3(r[0] + 0.5, 0, r[1] + 0.5), "rock")
	for u in m.get("units", []):
		_unit3(Vector3(u["cell"][0] + 0.5, 0, u["cell"][1] + 0.5), int(u.get("team", 1)), u.get("cls", "swordsman"), u.get("char", ""))
	FL = m.get("free", [])
	free_nodes = []
	for fo in FL:
		free_nodes.append(_free_obj3(fo))
	LIGHTS = m.get("lights", [])
	light_nodes = []
	if light_sel >= LIGHTS.size():
		light_sel = -1
	for ld in LIGHTS:
		light_nodes.append(_light_node(ld, true))
	var sp2 = L().get("spawn", null)
	if sp2 != null:
		var mk = MeshInstance3D.new()
		var cmk = CylinderMesh.new()
		cmk.top_radius = 0.06
		cmk.bottom_radius = 0.06
		cmk.height = 1.2
		var mmk = StandardMaterial3D.new()
		mmk.albedo_color = Color(1, 0.9, 0.2)
		mmk.emission_enabled = true
		mmk.emission = Color(1, 0.9, 0.2)
		cmk.material = mmk
		mk.mesh = cmk
		var g2 = terr.sample_h(float(sp2[0]), float(sp2[1])) if terr != null else 0.0
		mk.position = Vector3(float(sp2[0]), g2 + 0.6, float(sp2[1]))
		content.add_child(mk)
	_gizmo_update()
	if sculpt:
		_make_ind()
func _obj3(p, k):
	p.y = terr.sample_h(p.x, p.z) if terr != null else 0.0
	var od = OBJ3.get(k, {})
	var mn = _model_inst(str(od.get("model", ""))) if bool(od.get("render3d", false)) else null
	if mn != null:
		var ms = float(od.get("mscale", 1.0))
		mn.scale = Vector3(ms, ms, ms)
		mn.position = p + Vector3(0, float(od.get("myoff", 0.0)), 0)
		content.add_child(mn)
		return
	var oimg = str(od.get("img", ""))
	var ot = _tex(oimg) if oimg != "" else null
	if ot != null:
		var h = 1.2 * float(od.get("scale", 1.0)) * float(od.get("mscale", 1.0))
		var sp = Sprite3D.new()
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.pixel_size = h / float(ot.get_height())
		sp.texture = ot
		sp.position = p + Vector3(0, h * 0.5 + float(od.get("myoff", 0.0)), 0)
		content.add_child(sp)
		return
	var m = MeshInstance3D.new()
	var mi = StandardMaterial3D.new()
	if k == "tree":
		var cm = CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = 0.42
		cm.height = 1.0
		mi.albedo_color = Color(0.15, 0.4, 0.2)
		cm.material = mi
		m.mesh = cm
		m.position = p + Vector3(0, 0.5, 0)
	else:
		var bm = BoxMesh.new()
		bm.size = Vector3(0.7, 0.5, 0.7)
		mi.albedo_color = Color(0.45, 0.45, 0.5)
		bm.material = mi
		m.mesh = bm
		m.position = p + Vector3(0, 0.25, 0)
	content.add_child(m)
func _unit3(p, team, cid, chid = ""):
	var cd = CLASSES.get(cid, {})
	var sc = float(cd.get("scale", 1.0))
	var tcol = Color(0.2, 0.5, 0.9) if team == 0 else Color(0.9, 0.25, 0.25)
	p.y = terr.sample_h(p.x, p.z) if terr != null else 0.0
	var img = ""
	if chid != "":
		img = str(CHARS.get(chid, {}).get("img", ""))
	if img == "":
		img = str(cd.get("img", ""))
	var t = _tex(img) if img != "" else null
	var mn = _model_inst(str(cd.get("model", ""))) if bool(cd.get("render3d", false)) else null
	if mn != null:
		var ms = float(cd.get("mscale", 1.0))
		mn.scale = Vector3(ms, ms, ms)
		mn.position = p + Vector3(0, float(cd.get("myoff", 0.0)), 0)
		content.add_child(mn)
	elif t != null:
		var sp = Sprite3D.new()
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.pixel_size = 0.004
		sp.scale = Vector3(sc, sc, sc)
		sp.position = p + Vector3(0, 0.85 * sc, 0)
		sp.texture = t
		content.add_child(sp)
	else:
		var m = MeshInstance3D.new()
		var cm = CapsuleMesh.new()
		cm.radius = 0.28
		cm.height = 0.9
		var mi = StandardMaterial3D.new()
		mi.albedo_color = tcol
		cm.material = mi
		m.mesh = cm
		m.position = p + Vector3(0, 0.45, 0)
		content.add_child(m)
	var lb = Label3D.new()
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var nm3 = str(CHARS.get(chid, {}).get("name", "")) if chid != "" else ""
	if nm3 == "":
		nm3 = str(cd.get("name", cid))
	lb.text = nm3
	lb.pixel_size = 0.004
	lb.position = p + Vector3(0, 1.8 * sc, 0)
	lb.modulate = Color(1, 1, 1) if team == 0 else Color(1, 0.6, 0.6)
	content.add_child(lb)
func _sync():
	get_tree().call_group("con", "on_work_dirty")
func _make_ind():
	if brush_ind != null:
		brush_ind.queue_free()
		brush_ind = null
	if not sculpt:
		return
	brush_ind = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = brush_radius
	cm.bottom_radius = brush_radius
	cm.height = 0.02
	var mi = StandardMaterial3D.new()
	mi.albedo_color = Color(1, 1, 1, ind_alpha)
	mi.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.material = mi
	brush_ind.mesh = cm
	add_child(brush_ind)
func _apply():
	yaw_n.position = target
	yaw_n.rotation = Vector3(0, yaw, 0)
	pitch_n.rotation = Vector3(pitch, 0, 0)
	cam.position = Vector3(0, 0, dist)
func _input(ev):
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_RIGHT:
			right_drag = ev.pressed
		elif ev.button_index == MOUSE_BUTTON_MIDDLE:
			mid_drag = ev.pressed
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			if force_mode:
				strength = clampf(strength + 0.005, 0.01, 0.25)
				str_slider.value = strength
				_upd_str()
			elif radius_mode:
				brush_radius = clampf(brush_radius + 0.25, 0.5, 4.0)
				rad_slider.value = brush_radius
				_upd_rad()
				_make_ind()
			else:
				dist = clampf(dist - 1.0, 4, 25)
				_apply()
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			if force_mode:
				strength = clampf(strength - 0.005, 0.01, 0.25)
				str_slider.value = strength
				_upd_str()
			elif radius_mode:
				brush_radius = clampf(brush_radius - 0.25, 0.5, 4.0)
				rad_slider.value = brush_radius
				_upd_rad()
				_make_ind()
			else:
				dist = clampf(dist + 1.0, 4, 25)
				_apply()
		return

func _unhandled_input(ev):
	if not visible:
		return
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_V:
		spawn_mode = not spawn_mode
		_upd_tool()
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed and spawn_mode:
		var p = _ray(ev.position)
		if p != null:
			L()["spawn"] = [round(p.x * 2) / 2, round(p.z * 2) / 2]
			_sync()
			rebuild()
		return
	# GIZMO_TOP3
	if ev is InputEventMouseMotion and giz_mode != "":
		_gizmo_drag(ev.position)
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed and ev.shift_pressed and not sculpt and not paint_mode:
			_sel_click(ev.position)
			return
		if ev.pressed and ev.ctrl_pressed and not sculpt and not paint_mode:
			_del_click(ev.position)
			return
		if ev.pressed and (free_sel >= 0 or light_sel >= 0) and not sculpt and not paint_mode:
			var gm = _gizmo_pick(ev.position)
			if gm != "":
				giz_mode = gm
				return
		if not ev.pressed and giz_mode != "":
			giz_mode = ""
			if free_sel >= 0:
				_save_free()
			else:
				_save_lights()
			rebuild()
			return
	# CHUNK_TOP
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed and chunk_mode and not sculpt and not paint_mode:
		var p = _ray(ev.position)
		if p != null:
			if ev.ctrl_pressed:
				_chunk_del_at(p)
			else:
				_chunk_add_at(p)
		return
	# GIZMO_TOP2
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed and (chunk_mode or chunk_del_mode) and not sculpt and not paint_mode:
		var p = _ray(ev.position)
		if p != null:
			if chunk_del_mode:
				_chunk_del_at(p)
			else:
				_chunk_add_at(p)
		return
	if ev is InputEventMouseMotion and giz_mode != "":
		_gizmo_drag(ev.position)
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed and ev.shift_pressed and not sculpt and not paint_mode:
			_sel_click(ev.position)
			return
		if ev.pressed and ev.ctrl_pressed and not sculpt and not paint_mode:
			_del_click(ev.position)
			return
		if ev.pressed and (free_sel >= 0 or light_sel >= 0) and not sculpt and not paint_mode:
			var gm = _gizmo_pick(ev.position)
			if gm != "":
				giz_mode = gm
			return
		if not ev.pressed and giz_mode != "":
			giz_mode = ""
			if free_sel >= 0:
				_save_free()
			else:
				_save_lights()
			rebuild()
			return
	# GIZMO_TOP
	if ev is InputEventMouseMotion and giz_mode != "":
		_gizmo_drag(ev.position)
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed and ev.shift_pressed and not sculpt and not paint_mode:
			_sel_click(ev.position)
			return
		if ev.pressed and ev.ctrl_pressed and not sculpt and not paint_mode:
			_del_click(ev.position)
			return
		if ev.pressed and free_sel >= 0 and not sculpt and not paint_mode:
			var gm = _gizmo_pick(ev.position)
			if gm != "":
				giz_mode = gm
				return
		if not ev.pressed and giz_mode != "":
			giz_mode = ""
			if free_sel >= 0:
				_save_free()
			else:
				_save_lights()
			rebuild()
			return
	if ev is InputEventKey and ev.pressed:
		if ev.keycode == KEY_L:
			light_mode = not light_mode
			light_sel = -1
			_upd_tool()
			return
		if ev.keycode == KEY_T and light_sel < 0:
			sculpt = not sculpt
			_make_ind()
			_upd_tool()
			return
		if ev.keycode == KEY_P:
			paint_mode = not paint_mode
			return
		if ev.keycode == KEY_U and terr != null:
			terr.undo()
			L()["terrain"] = terr.to_data()
			_sync()
			return
		if ev.keycode == KEY_F:
			force_mode = not force_mode
			return
		if light_sel >= 0:
			var ld = LIGHTS[light_sel]
			var ch = false
			if ev.keycode == KEY_Q:
				var rq = ld.get("rot", 0.0)
				var rvq = [float(rq[0]), float(rq[1]), float(rq[2])] if rq is Array else [0.0, float(rq), 0.0]
				rvq[1] -= 15.0
				ld["rot"] = rvq
				ch = true
			if ev.keycode == KEY_E:
				var rq = ld.get("rot", 0.0)
				var rvq = [float(rq[0]), float(rq[1]), float(rq[2])] if rq is Array else [0.0, float(rq), 0.0]
				rvq[1] += 15.0
				ld["rot"] = rvq
				ch = true
			if ev.keycode == KEY_A:
				ld["energy"] = maxf(0.5, float(ld.get("energy", 8.0)) - 1.0)
				ch = true
			if ev.keycode == KEY_D:
				ld["energy"] = minf(64.0, float(ld.get("energy", 8.0)) + 1.0)
				ch = true
			if ev.keycode == KEY_R:
				ld["y"] = float(ld.get("y", 2.0)) + 0.25
				ch = true
			if ev.keycode == KEY_F:
				ld["y"] = maxf(0.2, float(ld.get("y", 2.0)) - 0.25)
				ch = true
			if ev.keycode == KEY_T:
				ld["type"] = "spot" if str(ld.get("type", "omni")) == "omni" else "omni"
				ch = true
			if ev.keycode == KEY_C:
				var cols = ["ffd9a0", "ffffff", "a0c0ff", "ff6040", "80ff80"]
				var cur = str(ld.get("color", "ffd9a0")).replace("#", "")
				ld["color"] = "#" + cols[(cols.find(cur) + 1) % cols.size()]
				ch = true
			if ev.keycode == KEY_DELETE or ev.keycode == KEY_X:
				LIGHTS.remove_at(light_sel)
				light_sel = -1
				_save_lights()
				rebuild()
				_light_hint()
				return
			if ch:
				_save_lights()
				rebuild()
				_light_hint()
				return

		if ev.keycode == KEY_Q and free_sel >= 0:
			FL[free_sel]["rot"] = float(FL[free_sel].get("rot", 0.0)) - 15.0
			_apply_free_sel()
			return
		if ev.keycode == KEY_E and free_sel >= 0:
			FL[free_sel]["rot"] = float(FL[free_sel].get("rot", 0.0)) + 15.0
			_apply_free_sel()
			return
		if ev.keycode == KEY_A and free_sel >= 0:
			FL[free_sel]["s"] = maxf(0.3, float(FL[free_sel].get("s", 1.0)) - 0.1)
			_apply_free_sel()
			return
		if ev.keycode == KEY_D and free_sel >= 0:
			FL[free_sel]["s"] = minf(3.0, float(FL[free_sel].get("s", 1.0)) + 0.1)
			_apply_free_sel()
			return
		if (ev.keycode == KEY_DELETE or ev.keycode == KEY_X) and free_sel >= 0:
			FL.remove_at(free_sel)
			free_sel = -1
			if free_sel >= 0:
				_save_free()
			else:
				_save_lights()
			rebuild()
			return
		if ev.keycode == KEY_C:
			chunk_mode = not chunk_mode
			_upd_tool()
			return
			radius_mode = not radius_mode
			return
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed and sculpt:
				sculpt_btn = "smooth" if ev.shift_pressed else ("lower" if ev.ctrl_pressed else "raise")
				terr.push_undo()
				_brush_at(ev.position, sculpt_btn)
			elif not ev.pressed and sculpt_btn != "":
				sculpt_btn = ""
				L()["terrain"] = terr.to_data()
				_sync()
			elif ev.pressed and paint_mode:
				terr.reset_stroke()
				var pp = _ray(ev.position)
				if pp != null:
					terr.paint_at(pp.x, pp.z, brush_radius, paint_mat)
					L()["terrain"] = terr.to_data()
					_sync()
			elif ev.pressed and chunk_mode:
				_chunk_at(ev)
				return
			elif ev.pressed and light_mode:
				_light_click(ev.position)
				return
			elif ev.pressed and free_mode:
				_free_click(ev.position)
				return
			elif not ev.pressed and light_drag:
				light_drag = false
				_save_lights()
			elif not ev.pressed and free_drag:
				free_drag = false
				_save_free()
			elif ev.pressed and free_sel < 0 and light_sel < 0:
				_place_click(ev.position)
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
		elif sculpt_btn != "":
			_brush_at(ev.position, sculpt_btn)
		elif light_drag:
			_light_drag_to(ev.position)
		elif free_drag:
			_free_drag_to(ev.position)
		elif paint_mode and ev.button_mask & MOUSE_BUTTON_MASK_LEFT:
			var pm = _ray(ev.position)
			if pm != null:
				terr.paint_at(pm.x, pm.z, brush_radius, paint_mat)
				L()["terrain"] = terr.to_data()
				_sync()
		if sculpt and brush_ind != null:
			_move_ind(ev.position)
func _place_click(mp):
	var c = _pick(mp)
	if c == null:
		return
	if terr != null and not terr.has_cell(c.x, c.y):
		return
	var Ld = L()
	var m = Ld.get("map", {})
	if m.is_empty():
		m = {"rocks": [], "objects": [], "units": []}
		Ld["map"] = m
	_erase(m, c.x, c.y)
	if Game.edit_tool == "erase":
		_sync()
		rebuild()
		return
	if Game.edit_tool == "place":
		if Game.edit_what == "obj":
			m["objects"].append({"cell": [c.x, c.y], "k": Game.edit_obj})
		else:
			m["units"].append({"cls": Game.edit_cls, "team": 0 if Game.edit_what == "mine" else 1, "cell": [c.x, c.y]})
		_sync()
		rebuild()
func _erase(m, x, y):
	var no = []
	for o in m.get("objects", []):
		if int(o["cell"][0]) != x or int(o["cell"][1]) != y:
			no.append(o)
	m["objects"] = no
	var nr = []
	for r in m.get("rocks", []):
		if int(r[0]) != x or int(r[1]) != y:
			nr.append(r)
	m["rocks"] = nr
	var nu = []
	for u in m.get("units", []):
		if int(u["cell"][0]) != x or int(u["cell"][1]) != y:
			nu.append(u)
	m["units"] = nu
func _brush_at(mp, t):
	var p = _ray(mp)
	if p == null:
		return
	terr.apply_brush(p.x, p.z, brush_radius, strength, t)
	_move_ind(mp)
func _move_ind(mp):
	if brush_ind == null:
		return
	var p = _ray(mp)
	if p == null:
		return
	brush_ind.position = Vector3(p.x, terr.sample_h(p.x, p.z) + 0.05, p.z)
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
func _pick(mp):
	var p = _ray(mp)
	if p == null:
		return null
	var cx = int(p.x)
	var cz = int(p.z)
	if terr != null and (cx < 0 or cz < 0 or cx >= terr.GW or cz >= terr.GH):
		return null
	return Vector2i(cx, cz)

func _model_inst(path):
	if path == "" or not FileAccess.file_exists(path):
		return null
	var res = load(path)
	if res is PackedScene:
		return res.instantiate()
	return null

func _chunk_at(ev):
	var p = _ray(ev.position)
	if p == null or terr == null:
		return
	var cx = int(floor(p.x / 8.0))
	var cy = int(floor(p.z / 8.0))
	if ev.ctrl_pressed:
		terr.chunk_mask.erase(str(cx) + "," + str(cy))
		terr.build()
		terr.splat()
	else:
		var r = terr.add_chunk(cx, cy)
		if not r.ok:
			return
	L()["terrain"] = terr.to_data()
	_sync()
func _shift_map(d):
	var m = L().get("map", {})
	for o in m.get("objects", []):
		o["cell"][0] += d.x
		o["cell"][1] += d.y
	for rr in m.get("rocks", []):
		rr[0] += d.x
		rr[1] += d.y
	for u in m.get("units", []):
		u["cell"][0] += d.x
		u["cell"][1] += d.y
	var el = m.get("elev", {})
	if el.size() > 0:
		var ne = {}
		for k in el:
			var p2 = k.split(",")
			ne[str(int(p2[0]) + d.x) + "," + str(int(p2[1]) + d.y)] = el[k]
		m["elev"] = ne


func _migrate(td):
	var sub = int(td.get("sub", 8))
	var ogw = int(td.get("gw", 8))
	var ogh = int(td.get("gh", 6))
	var oox = int(td.get("ox", 0))
	var ooy = int(td.get("oy", 0))
	var NG = 40
	var RX = NG * sub + 1
	var RZ = NG * sub + 1
	var oRX = ogw * sub + 1
	var oRZ = ogh * sub + 1
	var oh = td.get("h", [])
	var ow = td.get("w", [])
	var shx = 8
	var shy = 8
	var kx = int((8 - oox) / 8)
	var ky = int((8 - ooy) / 8)
	var nh = []
	nh.resize(RX * RZ)
	nh.fill(0.0)
	for j in oRZ:
		if j >= RZ:
			break
		for i in oRX:
			var ni = i + shx * sub
			var nj = j + shy * sub
			if ni < RX and nj < RZ and i + j * oRX < oh.size():
				nh[ni + nj * RX] = oh[i + j * oRX]
	var nw = []
	for k in ow.size():
		var a = []
		a.resize(RX * RZ)
		a.fill(0.0)
		for j in oRZ:
			if j >= RZ:
				break
			for i in oRX:
				var ni = i + shx * sub
				var nj = j + shy * sub
				if ni < RX and nj < RZ and i + j * oRX < ow[k].size():
					a[ni + nj * RX] = ow[k][i + j * oRX]
		nw.append(a)
	if nw.size() == 0:
		var a2 = []
		a2.resize(RX * RZ)
		a2.fill(0.0)
		nw.append(a2)
	var ncm = {}
	if td.get("chunks", {}).size() > 0:
		for key in td.get("chunks", {}):
			var p = key.split(",")
			var cx = int(p[0]) + kx
			var cy = int(p[1]) + ky
			if cx >= 0 and cy >= 0 and cx < 5 and cy < 5:
				ncm[str(cx) + "," + str(cy)] = 1
	if ncm.size() == 0:
		ncm = {"1,1": 1}
	var m = L().get("map", {})
	for o in m.get("objects", []):
		o["cell"][0] += shx
		o["cell"][1] += shy
	for r in m.get("rocks", []):
		r[0] += shx
		r[1] += shy
	for u in m.get("units", []):
		u["cell"][0] += shx
		u["cell"][1] += shy
	var el = m.get("elev", {})
	if el.size() > 0:
		var ne = {}
		for kk in el:
			var pp = kk.split(",")
			ne[str(int(pp[0]) + shx) + "," + str(int(pp[1]) + shy)] = el[kk]
		m["elev"] = ne
	return {"gw": NG, "gh": NG, "sub": sub, "h": nh, "w": nw, "chunks": ncm, "ox": 0, "oy": 0, "migrated": true}

func _free_obj3(fo):
	var k = str(fo.get("k", "rock"))
	var pp = fo.get("pos", [0, 0])
	var g = terr.sample_h(float(pp[0]), float(pp[1])) if terr != null else 0.0
	var p = Vector3(float(pp[0]), g + float(fo.get("y", 0.0)), float(pp[1]))
	var od = OBJ3.get(k, {})
	var sc = float(fo.get("s", 1.0))
	var r0 = fo.get("rot", 0.0)
	var rv = Vector3(deg_to_rad(float(r0[0])), deg_to_rad(float(r0[1])), deg_to_rad(float(r0[2]))) if r0 is Array else Vector3(0, deg_to_rad(float(r0)), 0)
	var tilted = abs(rv.x) > 0.001 or abs(rv.z) > 0.001
	var mn = _model_inst(str(od.get("model", ""))) if bool(od.get("render3d", false)) else null
	if mn != null:
		var ms = float(od.get("mscale", 1.0)) * sc
		mn.scale = Vector3(ms, ms, ms)
		mn.rotation = rv
		mn.position = p + Vector3(0, float(od.get("myoff", 0.0)), 0)
		content.add_child(mn)
		mn.set_meta("yoff", mn.position.y - g)
		mn.set_meta("voff", _vis_off(k))
		return mn
	var oimg = str(od.get("img", ""))
	var ot = _tex(oimg) if oimg != "" else null
	if ot != null:
		var h = 1.2 * float(od.get("scale", 1.0)) * float(od.get("mscale", 1.0)) * sc
		var sp = Sprite3D.new()
		sp.billboard = BaseMaterial3D.BILLBOARD_DISABLED if tilted else BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.pixel_size = h / float(ot.get_height())
		sp.scale = Vector3(sc, sc, sc)
		sp.texture = ot
		sp.rotation = rv
		sp.position = p + Vector3(0, h * 0.5 + float(od.get("myoff", 0.0)), 0)
		content.add_child(sp)
		sp.set_meta("yoff", sp.position.y - g)
		sp.set_meta("voff", _vis_off(k))
		return sp
	var m = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.7, 0.5, 0.7)
	m.mesh = bm
	m.scale = Vector3(sc, sc, sc)
	m.rotation = rv
	m.position = p + Vector3(0, 0.25, 0)
	content.add_child(m)
	m.set_meta("yoff", m.position.y - g)
	m.set_meta("voff", _vis_off(k))
	return m
func _free_pick(mp):
	var od = _ray_od(mp)
	if od == null:
		return -1
	var o = od[0]
	var d = od[1]
	var bi = -1
	var bd = 0.5
	for i in FL.size():
		var fo = FL[i]
		var pp = fo.get("pos", [0, 0])
		var g = terr.sample_h(float(pp[0]), float(pp[1])) if terr != null else 0.0
		var sc = float(fo.get("s", 1.0))
		var base = Vector3(float(pp[0]), g + float(fo.get("y", 0.0)), float(pp[1]))
		var top = base + Vector3(0, 1.2 * sc, 0)
		var dist = _seg_ray_dist(o, d, base, top)
		if dist < bd:
			bd = dist
			bi = i
	return bi
func _free_click(mp):
	var p = _ray(mp)
	if p == null:
		return
	var idx = _free_pick(mp)
	if Game.edit_tool == "erase":
		if idx >= 0:
			FL.remove_at(idx)
			free_sel = -1
			_save_free()
			rebuild()
		else:
			var m = L().get("map", {})
			var bo = m.get("objects", []).size()
			var br = m.get("rocks", []).size()
			_erase(m, int(p.x), int(p.z))
			if m.get("objects", []).size() != bo or m.get("rocks", []).size() != br:
				_sync()
				rebuild()
		return
	if idx >= 0:
		free_sel = idx
		free_drag = true
		free_moved = false
		free_press = mp
		return
	if free_sel >= 0 or light_sel >= 0:
		return
	FL.append({"k": Game.edit_obj, "pos": [p.x, p.z], "rot": 0.0, "s": 1.0})
	free_sel = FL.size() - 1
	free_drag = true
	free_moved = false
	free_press = mp
	_save_free()
	rebuild()
func _free_drag_to(mp):
	if not free_moved:
		if (mp - free_press).length() < 8:
			return
		free_moved = true
	var p = _ray(mp)
	if p == null or free_sel < 0 or free_sel >= FL.size():
		return
	p.x = clampf(p.x, 0.0, terr.GW if terr != null else 40.0)
	p.z = clampf(p.z, 0.0, terr.GH if terr != null else 40.0)
	if terr != null and not terr.has_cell(int(p.x), int(p.z)):
		return
	FL[free_sel]["pos"] = [p.x, p.z]
	if free_sel < free_nodes.size() and free_nodes[free_sel] != null:
		var n = free_nodes[free_sel]
		var g = terr.sample_h(p.x, p.z) if terr != null else 0.0
		n.position = Vector3(p.x, g + n.get_meta("yoff", 0.0), p.z)
		FL[free_sel]["y"] = n.position.y - g - n.get_meta("voff", 0.0)
func _apply_free_sel():
	if free_sel < 0 or free_sel >= FL.size():
		return
	if free_sel < free_nodes.size() and free_nodes[free_sel] != null:
		var n = free_nodes[free_sel]
		var od = OBJ3.get(str(FL[free_sel].get("k", "rock")), {})
		var sc = float(FL[free_sel].get("s", 1.0))
		var r0 = FL[free_sel].get("rot", 0.0)
		var rv = Vector3(deg_to_rad(float(r0[0])), deg_to_rad(float(r0[1])), deg_to_rad(float(r0[2]))) if r0 is Array else Vector3(0, deg_to_rad(float(r0)), 0)
		n.rotation = rv
		if n is Sprite3D:
			n.billboard = BaseMaterial3D.BILLBOARD_DISABLED if (abs(rv.x) > 0.001 or abs(rv.z) > 0.001) else BaseMaterial3D.BILLBOARD_FIXED_Y
		if bool(od.get("render3d", false)):
			var ms = float(od.get("mscale", 1.0)) * sc
			n.scale = Vector3(ms, ms, ms)
		else:
			n.scale = Vector3(sc, sc, sc)
	_save_free()
func _save_free():
	var m = L().get("map", {})
	m["free"] = FL
	L()["map"] = m
	_sync()

func _send_to_godot():
	_export_tscn()
	var f = FileAccess.open("res://locs_edit/_cmd_open.txt", FileAccess.WRITE)
	f.store_string("res://locs_edit/%s.tscn" % Game.edit_loc)
	f.close()
	if tool_lab != null:
		tool_lab.text = "Сцена открывается в Godot. Правь, сохрани (Ctrl+S), затем «ГОТОВО»."
	print("SEND TO GODOT: res://locs_edit/%s.tscn" % Game.edit_loc)
func _make_obj_node(k, p, rot_deg, sc, rv = null):
	var od = OBJ3.get(k, {})
	var rotv = rv if rv != null else Vector3(0, deg_to_rad(rot_deg), 0)
	var tilted = abs(rotv.x) > 0.001 or abs(rotv.z) > 0.001
	var mn = _model_inst(str(od.get("model", ""))) if bool(od.get("render3d", false)) else null
	if mn != null:
		var ms = float(od.get("mscale", 1.0)) * sc
		mn.set_meta("noown", true)
		mn.scale = Vector3(ms, ms, ms)
		mn.rotation = rotv
		mn.position = p + Vector3(0, float(od.get("myoff", 0.0)), 0)
		return mn
	var oimg = str(od.get("img", ""))
	var ot = _tex(oimg) if oimg != "" else null
	if ot != null:
		var h = 1.2 * float(od.get("scale", 1.0)) * float(od.get("mscale", 1.0))
		var sp = Sprite3D.new()
		sp.billboard = BaseMaterial3D.BILLBOARD_DISABLED if tilted else BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.pixel_size = h / float(ot.get_height())
		sp.scale = Vector3(sc, sc, sc)
		sp.texture = ot
		sp.rotation = rotv
		sp.position = p + Vector3(0, h * 0.5 + float(od.get("myoff", 0.0)), 0)
		return sp
	var m = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.7, 0.5, 0.7)
	m.mesh = bm
	m.scale = Vector3(sc, sc, sc)
	m.rotation = rotv
	m.position = p + Vector3(0, 0.25, 0)
	return m
func _export_tscn():
	var root = Node3D.new()
	root.name = str(Game.edit_loc)
	var tm = MeshInstance3D.new()
	tm.name = "TERRAIN_REF"
	if terr != null:
		var srcm = null
		for c in terr.get_children():
			if c is MeshInstance3D and c.mesh != null:
				srcm = c.mesh
				break
		if srcm != null:
			var am = ArrayMesh.new()
			for si in srcm.get_surface_count():
				am.add_surface_from_arrays(srcm.surface_get_primitive_type(si), srcm.surface_get_arrays(si))
				var gm = StandardMaterial3D.new()
				gm.albedo_color = Color(0.35, 0.4, 0.35)
				am.surface_set_material(si, gm)
			tm.mesh = am
	root.add_child(tm)
	var m = L().get("map", {})
	var i = 0
	for r in m.get("rocks", []):
		var n = _make_obj_node("rock", Vector3(r[0] + 0.5, 0, r[1] + 0.5), 0.0, 1.0)
		n.name = "O_rock_%d" % i
		i += 1
		root.add_child(n)
	for o in m.get("objects", []):
		var k = str(o.get("k", "rock"))
		var n = _make_obj_node(k, Vector3(o["cell"][0] + 0.5, 0, o["cell"][1] + 0.5), 0.0, 1.0)
		n.name = "O_%s_%d" % [k, i]
		i += 1
		root.add_child(n)
	for fo in m.get("free", []):
		var k = str(fo.get("k", "rock"))
		var pp = fo.get("pos", [0, 0])
		var n = _make_obj_node(k, Vector3(float(pp[0]), 0, float(pp[1])), float(fo.get("rot", 0.0)), float(fo.get("s", 1.0)))
		n.name = "O_%s_%d" % [k, i]
		i += 1
		root.add_child(n)
	var j = 0
	for u in m.get("units", []):
		var n = Node3D.new()
		n.name = "U_%s_%d_%d" % [str(u.get("cls", "swordsman")), int(u.get("team", 1)), j]
		j += 1
		n.position = Vector3(u["cell"][0] + 0.5, 0, u["cell"][1] + 0.5)
		var cap = MeshInstance3D.new()
		var cm = CapsuleMesh.new()
		cap.mesh = cm
		var mi = StandardMaterial3D.new()
		mi.albedo_color = Color(0.2, 0.5, 0.9) if int(u.get("team", 0)) == 0 else Color(0.9, 0.3, 0.3)
		cm.material = mi
		n.add_child(cap)
		root.add_child(n)
	if not DirAccess.dir_exists_absolute("res://locs_edit"):
		DirAccess.make_dir_absolute("res://locs_edit")
	_set_owners(root, root)
	print("EXPORT nodes: ", root.get_child_count(), " | rocks:", m.get("rocks", []).size(), " obj:", m.get("objects", []).size(), " free:", m.get("free", []).size(), " units:", m.get("units", []).size())
	var ps = PackedScene.new()
	ps.pack(root)
	var err = ResourceSaver.save(ps, "res://locs_edit/%s.tscn" % Game.edit_loc)
	print("SAVE RESULT: ", err)
	root.queue_free()
	if tool_lab != null:
		tool_lab.text = "Экспортировано: res://locs_edit/%s.tscn" % Game.edit_loc
	print("EXPORT: res://locs_edit/%s.tscn" % Game.edit_loc)
func _import_tscn():
	var path = "res://locs_edit/%s.tscn" % Game.edit_loc
	var f0 = FileAccess.open("res://locs_edit/_cmd_save.txt", FileAccess.WRITE)
	f0.store_string(path)
	f0.close()
	var ack = false
	var t = 0.0
	while t < 2.0 and not FileAccess.file_exists("res://locs_edit/_save_done.txt"):
		await get_tree().process_frame
		t += get_process_delta_time()
	var d0 = DirAccess.open("res://locs_edit")
	if d0 != null and d0.file_exists("_save_done.txt"):
		d0.remove("_save_done.txt")
		ack = true
	if ack:
		await get_tree().create_timer(0.3).timeout
	if not FileAccess.file_exists(path):
		if tool_lab != null:
			tool_lab.text = "Нет файла %s — сначала «В GODOT»." % path
		return
	var ps = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var inst = ps.instantiate()
	var m = L().get("map", {})
	var free = []
	var units = []
	var objects = []
	var decor = false
	var stack = []
	for c0 in inst.get_children():
		stack.append(c0)
	while stack.size() > 0:
		var c = stack.pop_back()
		if c.name.begins_with("TERRAIN_REF"):
			continue
		if c.name == "OBJ" or c.name == "UNITS":
			for cc in c.get_children():
				stack.append(cc)
			continue
		if c.name.begins_with("O_"):
			var parts = c.name.split("_")
			var k = parts[1] if parts.size() > 1 else "rock"
			if k == "stairs":
				objects.append({"cell": [int(round(c.position.x - 0.5)), int(round(c.position.z - 0.5))], "k": "stairs", "dir": [0, -1]})
			else:
				var msd = float(OBJ3.get(k, {}).get("mscale", 1.0)) if bool(OBJ3.get(k, {}).get("render3d", false)) else 1.0
				free.append({"k": k, "pos": [c.position.x, c.position.z], "rot": rad_to_deg(c.rotation.y), "s": c.scale.x / msd})
		elif c.name.begins_with("U_"):
			var parts = c.name.split("_")
			units.append({"cls": parts[1] if parts.size() > 1 else "swordsman", "team": int(parts[2]) if parts.size() > 2 else 1, "cell": [int(round(c.position.x - 0.5)), int(round(c.position.z - 0.5))]})
		else:
			decor = true
	m["free"] = free
	m["units"] = units
	m["objects"] = objects
	m["rocks"] = []
	if decor:
		L()["decor"] = path
	else:
		L().erase("decor")
	L()["map"] = m
	inst.queue_free()
	_sync()
	rebuild()
	print("IMPORT: ", path, " ack=", ack, " free=", free.size(), " units=", units.size())
	if tool_lab != null:
		if ack:
			tool_lab.text = "Импортировано (автосейв): free %d, юнитов %d" % [free.size(), units.size()]
		else:
			tool_lab.text = "Импортировано с диска: free %d, юнитов %d. Если правки не видны — Ctrl+S в Godot и ГОТОВО ещё раз." % [free.size(), units.size()]
func _set_owners(n, root):
	for c in n.get_children():
		c.owner = root
		if not c.has_meta("noown"):
			_set_owners(c, root)

func _diag_ui():
	if has_meta("dw"):
		return
	set_meta("dw", true)
	var txt = "DIAG WORKSHOP\n"
	txt += "opened at: %s\n" % str(Time.get_datetime_string_from_system())
	txt += "has light_mode var: %s\n" % str("light_mode" in self)
	var btns = []
	_collect_btns(self, btns)
	txt += "buttons: %s\n" % ", ".join(btns)
	var f = FileAccess.open("res://diag.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(txt)
		f.close()
	print(txt)
func _collect_btns(n, out):
	if n is Button:
		out.append(str(n.text))
	for c in n.get_children():
		_collect_btns(c, out)

func _vis_off(k):
	var od = OBJ3.get(k, {})
	if bool(od.get("render3d", false)):
		return float(od.get("myoff", 0.0))
	var oimg = str(od.get("img", ""))
	if oimg != "":
		var h = 1.2 * float(od.get("scale", 1.0)) * float(od.get("mscale", 1.0))
		return h * 0.5 + float(od.get("myoff", 0.0))
	return 0.25

func _rot_adj(d):
	var r0 = FL[free_sel].get("rot", 0.0)
	var rv = [float(r0[0]), float(r0[1]), float(r0[2])] if r0 is Array else [0.0, float(r0), 0.0]
	rv[1] += d
	FL[free_sel]["rot"] = rv

func _sel_click(mp):
	var od = _ray_od(mp)
	var hit = _vis_pick(od)
	if hit == null:
		var p = _ray(mp)
		if p == null:
			free_sel = -1
			light_sel = -1
			_gizmo_update()
			return
		var ci = _cell_pick(p)
		if ci != null:
			_convert_cell_to_free(ci)
			rebuild()
			free_sel = FL.size() - 1
			light_sel = -1
			_gizmo_update()
			_free_hint()
		else:
			free_sel = -1
			light_sel = -1
			_gizmo_update()
		return
	if hit[0] == "obj":
		light_sel = -1
		free_sel = hit[1]
	else:
		free_sel = -1
		light_sel = hit[1]
	_gizmo_update()
	if free_sel >= 0:
		_free_hint()
	elif light_sel >= 0:
		_light_hint()
func _del_click(mp):
	var od = _ray_od(mp)
	var hit = _vis_pick(od)
	if hit == null:
		var p = _ray(mp)
		if p == null:
			return
		var ci = _cell_pick(p)
		if ci == null:
			return
		var m = L().get("map", {})
		if ci["src"] == "objects":
			m["objects"].remove_at(ci["i"])
		else:
			m["rocks"].remove_at(ci["i"])
		L()["map"] = m
		_sync()
		rebuild()
		return
	if hit[0] == "obj":
		FL.remove_at(hit[1])
		free_sel = -1
		_save_free()
	else:
		LIGHTS.remove_at(hit[1])
		light_sel = -1
		_save_lights()
	rebuild()
func _free_hint():
	if tool_lab == null:
		return
	if free_sel < 0 or free_sel >= FL.size():
		return
	tool_lab.text = "Выбран #%d: гизмо стрелки/кольцо | Q/E поворот, A/D масштаб, R/F высота, Del удалить" % free_sel

func _ray_od(mp):
	if cam == null:
		return null
	return [cam.project_ray_origin(mp), cam.project_ray_normal(mp)]

func _plane_t(o, d, y):
	if abs(d.y) < 0.0001:
		return -1.0
	var t = (y - o.y) / d.y
	return t if t > 0 else -1.0

func _seg_ray_dist(o, d, a, b):
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

func _gizmo_pick(mp):
	if free_sel < 0 and light_sel < 0:
		return ""
	var od = _ray_od(mp)
	if od == null:
		return ""
	var o = od[0]
	var d = od[1]
	var fo = FL[free_sel] if free_sel >= 0 else LIGHTS[light_sel]
	var pp = fo.get("pos", [0, 0])
	var g = terr.sample_h(float(pp[0]), float(pp[1])) if terr != null else 0.0
	var base = Vector3(float(pp[0]), g + float(fo.get("y", 0.0)), float(pp[1]))
	if _seg_ray_dist(o, d, base, base + Vector3(1.1, 0, 0)) < 0.18:
		return "mx"
	if _seg_ray_dist(o, d, base, base + Vector3(0, 0, 1.1)) < 0.18:
		return "mz"
	if _seg_ray_dist(o, d, base, base + Vector3(0, 1.1, 0)) < 0.18:
		return "my"
	var best = ""
	var bt = 1000000.0
	var t1 = _plane_t(o, d, base.y)
	if t1 > 0 and t1 < bt:
		var hp = o + d * t1
		var r = Vector2(hp.x - base.x, hp.z - base.z).length()
		if r >= 0.35 and r <= 0.95:
			best = "ry"
			bt = t1
	var t2 = _plane_axis(o, d, 0, base.x)
	if t2 > 0 and t2 < bt:
		var hp = o + d * t2
		var r = Vector2(hp.y - base.y, hp.z - base.z).length()
		if r >= 0.35 and r <= 0.95:
			best = "rx"
			bt = t2
	var t3 = _plane_axis(o, d, 2, base.z)
	if t3 > 0 and t3 < bt:
		var hp = o + d * t3
		var r = Vector2(hp.x - base.x, hp.y - base.y).length()
		if r >= 0.35 and r <= 0.95:
			best = "rz"
			bt = t3
	return best
func _gizmo_drag(mp):
	if free_sel < 0 and light_sel < 0:
		return
	var od = _ray_od(mp)
	if od == null:
		return
	var o = od[0]
	var d = od[1]
	var fo = FL[free_sel] if free_sel >= 0 else LIGHTS[light_sel]
	var pp = fo.get("pos", [0, 0])
	var g = terr.sample_h(float(pp[0]), float(pp[1])) if terr != null else 0.0
	var base = Vector3(float(pp[0]), g + float(fo.get("y", 0.0)), float(pp[1]))
	var nx = base.x
	var nz = base.z
	var ny = float(fo.get("y", 0.0))
	var r0 = fo.get("rot", 0.0)
	var rv = [float(r0[0]), float(r0[1]), float(r0[2])] if r0 is Array else [0.0, float(r0), 0.0]
	if giz_mode == "ry":
		var t = _plane_t(o, d, base.y)
		if t > 0:
			var hp = o + d * t
			rv[1] = snapped(-rad_to_deg(atan2(hp.z - base.z, hp.x - base.x)), 15.0)
			fo["rot"] = rv
	elif giz_mode == "rx":
		var t = _plane_axis(o, d, 0, base.x)
		if t > 0:
			var hp = o + d * t
			rv[0] = snapped(-rad_to_deg(atan2(hp.y - base.y, hp.z - base.z)), 15.0)
			fo["rot"] = rv
	elif giz_mode == "rz":
		var t = _plane_axis(o, d, 2, base.z)
		if t > 0:
			var hp = o + d * t
			rv[2] = snapped(rad_to_deg(atan2(hp.y - base.y, hp.x - base.x)), 15.0)
			fo["rot"] = rv
	elif giz_mode == "my":
		var e = Vector3(0, 1, 0)
		var dd = d.dot(d)
		var de = d.dot(e)
		var w0 = o - base
		var c1 = d.dot(w0)
		var c2 = e.dot(w0)
		var den = dd * 1.0 - de * de
		if abs(den) > 0.00001:
			var s2 = (dd * c2 - de * c1) / den
			ny = clampf(base.y + s2 - g, -1.0, 8.0)
			fo["y"] = ny
	else:
		var e = Vector3(1, 0, 0) if giz_mode == "mx" else Vector3(0, 0, 1)
		var dd = d.dot(d)
		var de = d.dot(e)
		var w0 = o - base
		var c1 = d.dot(w0)
		var c2 = e.dot(w0)
		var den = dd * 1.0 - de * de
		if abs(den) > 0.00001:
			var s2 = (dd * c2 - de * c1) / den
			if giz_mode == "mx":
				nx = clampf(base.x + s2, 0.0, terr.GW if terr != null else 40.0)
				nz = base.z
			else:
				nz = clampf(base.z + s2, 0.0, terr.GH if terr != null else 40.0)
				nx = base.x
		if terr != null and not terr.has_cell(int(nx), int(nz)):
			return
		fo["pos"] = [nx, nz]
		if free_sel >= 0:
			fo["y"] = 0.0
			ny = 0.0
	var n = null
	if free_sel >= 0 and free_sel < free_nodes.size():
		n = free_nodes[free_sel]
	elif light_sel >= 0 and light_sel < light_nodes.size():
		n = light_nodes[light_sel]
	var g2 = terr.sample_h(nx, nz) if terr != null else 0.0
	var by = g2 + ny
	if n != null:
		var voff = n.get_meta("voff", 0.0)
		n.position = Vector3(nx, by + voff, nz)
		if free_sel >= 0:
			n.rotation = Vector3(deg_to_rad(rv[0]), deg_to_rad(rv[1]), deg_to_rad(rv[2]))
		else:
			n.rotation.y = deg_to_rad(rv[1])
	if gizmo_root != null:
		gizmo_root.position = Vector3(nx, by, nz)
	if sel_ind != null:
		sel_ind.position = Vector3(nx, g2 + 0.03, nz)
func snapf2(v, st):
	return round(v / st) * st

func _gizmo_update():
	if gizmo_root != null:
		gizmo_root.queue_free()
		gizmo_root = null
	if sel_ind != null:
		sel_ind.queue_free()
		sel_ind = null
	if free_sel < 0 and light_sel < 0:
		return
	var fo = FL[free_sel] if free_sel >= 0 else LIGHTS[light_sel]
	var pp = fo.get("pos", [0, 0])
	var g = terr.sample_h(float(pp[0]), float(pp[1])) if terr != null else 0.0
	var base = Vector3(float(pp[0]), g + float(fo.get("y", 0.0)), float(pp[1]))
	var dsc = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.45
	cm.bottom_radius = 0.45
	cm.height = 0.02
	var mm = StandardMaterial3D.new()
	mm.albedo_color = Color(1, 0.9, 0.1, 0.5)
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.emission_enabled = true
	mm.emission = Color(1, 0.9, 0.1)
	cm.material = mm
	dsc.mesh = cm
	dsc.position = Vector3(base.x, g + 0.03, base.z)
	content.add_child(dsc)
	sel_ind = dsc
	gizmo_root = Node3D.new()
	gizmo_root.position = base
	content.add_child(gizmo_root)
	_add_arrow(Vector3(1, 0, 0), Color(1, 0.2, 0.2))
	_add_arrow(Vector3(0, 0, 1), Color(0.3, 0.4, 1))
	_add_arrow(Vector3(0, 1, 0), Color(0.3, 1, 0.3))
	_add_ring(Vector3(0, 1, 0), Color(0.3, 1, 0.3))
	_add_ring(Vector3(1, 0, 0), Color(1, 0.2, 0.2))
	_add_ring(Vector3(0, 0, 1), Color(0.3, 0.4, 1))
func _add_arrow(dirv, col):
	var n = Node3D.new()
	var sh = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.02, 0.02, 0.9)
	var m1 = StandardMaterial3D.new()
	m1.albedo_color = col
	m1.emission_enabled = true
	m1.emission = col
	bm.material = m1
	sh.mesh = bm
	sh.position = Vector3(0, 0, 0.45)
	n.add_child(sh)
	var tp = MeshInstance3D.new()
	var cn = CylinderMesh.new()
	cn.top_radius = 0.0
	cn.bottom_radius = 0.05
	cn.height = 0.15
	var m2 = StandardMaterial3D.new()
	m2.albedo_color = col
	m2.emission_enabled = true
	m2.emission = col
	cn.material = m2
	tp.mesh = cn
	tp.position = Vector3(0, 0, 0.95)
	tp.rotation_degrees = Vector3(90, 0, 0)
	n.add_child(tp)
	if dirv == Vector3(1, 0, 0):
		n.rotation_degrees = Vector3(0, 90, 0)
	elif dirv == Vector3(0, 1, 0):
		n.rotation_degrees = Vector3(-90, 0, 0)
	gizmo_root.add_child(n)
func _light_node(ld, marker):
	var ty = str(ld.get("type", "omni"))
	var l
	if ty == "spot":
		l = SpotLight3D.new()
		if "spot_angle_degrees" in l:
			l.spot_angle_degrees = float(ld.get("spot_deg", 45.0))
		elif "spot_angle" in l:
			l.spot_angle = float(ld.get("spot_deg", 45.0))
		if "spot_range" in l:
			l.spot_range = float(ld.get("range", 10.0))
		elif "light_range" in l:
			l.light_range = float(ld.get("range", 10.0))
	else:
		l = OmniLight3D.new()
		l.omni_range = float(ld.get("range", 6.0))
	l.light_color = Color(str(ld.get("color", "#ffd9a0")))
	l.light_energy = float(ld.get("energy", 8.0))
	var pp = ld.get("pos", [0, 0])
	var g = terr.sample_h(float(pp[0]), float(pp[1])) if terr != null else 0.0
	l.position = Vector3(float(pp[0]), g + float(ld.get("y", 2.0)), float(pp[1]))
	var r0 = ld.get("rot", 0.0)
	var ry = float(r0[1]) if r0 is Array else float(r0)
	l.rotation.y = deg_to_rad(ry)
	if marker:
		var mk = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = 0.12
		var mm = StandardMaterial3D.new()
		mm.albedo_color = l.light_color
		mm.emission_enabled = true
		mm.emission = l.light_color
		sm.material = mm
		mk.mesh = sm
		l.add_child(mk)
	content.add_child(l)
	return l

func _light_pick(mp):
	var od = _ray_od(mp)
	if od == null:
		return -1
	var bi = -1
	var bd = 0.4
	for i in LIGHTS.size():
		var dd = _light_seg_dist(od, LIGHTS[i])
		if dd < bd:
			bd = dd
			bi = i
	return bi

func _light_click(mp):
	var p = _ray(mp)
	if p == null:
		return
	var idx = _light_pick(mp)
	if Game.edit_tool == "erase":
		if idx >= 0:
			LIGHTS.remove_at(idx)
			light_sel = -1
			_save_lights()
			rebuild()
		return
	if idx >= 0:
		light_sel = idx
		light_drag = true
		light_moved = false
		light_press = mp
		_light_hint()
		return
	if free_sel >= 0 or light_sel >= 0:
		return
	LIGHTS.append({"pos": [p.x, p.z], "y": 2.0, "type": "omni", "color": "#ffd9a0", "energy": 8.0, "range": 6.0, "spot_deg": 45.0, "rot": 0.0})
	light_sel = LIGHTS.size() - 1
	light_drag = true
	light_moved = false
	light_press = mp
	_save_lights()
	rebuild()
	_light_hint()

func _light_drag_to(mp):
	if not light_moved:
		if (mp - light_press).length() < 8:
			return
		light_moved = true
	var p = _ray(mp)
	if p == null or light_sel < 0 or light_sel >= LIGHTS.size():
		return
	p.x = clampf(p.x, 0.0, terr.GW if terr != null else 40.0)
	p.z = clampf(p.z, 0.0, terr.GH if terr != null else 40.0)
	if terr != null and not terr.has_cell(int(p.x), int(p.z)):
		return
	LIGHTS[light_sel]["pos"] = [p.x, p.z]
	if light_sel < light_nodes.size() and light_nodes[light_sel] != null:
		var g = terr.sample_h(p.x, p.z) if terr != null else 0.0
		light_nodes[light_sel].position = Vector3(p.x, g + float(LIGHTS[light_sel].get("y", 2.0)), p.z)

func _save_lights():
	var m = L().get("map", {})
	m["lights"] = LIGHTS
	L()["map"] = m
	_sync()

func _light_hint():
	if tool_lab == null:
		return
	if light_sel < 0 or light_sel >= LIGHTS.size():
		tool_lab.text = "СВЕТ: клик — поставить, тянуть — двигать, стереть+клик — удалить."
		return
	var ld = LIGHTS[light_sel]
	tool_lab.text = "Свет #%d: %s, эн %.0f, рад %.1f, выс %.2f, пов %.0f | Q/E пов, A/D эн, R/F выс, T тип, C цвет, Del удалить" % [light_sel, str(ld.get("type", "omni")), float(ld.get("energy", 8.0)), float(ld.get("range", 6.0)), float(ld.get("y", 2.0)), _rot_y(ld.get("rot", 0.0))]

func _add_ring(axis, col):
	var ring = MeshInstance3D.new()
	var tm2 = TorusMesh.new()
	tm2.inner_radius = 0.58
	tm2.outer_radius = 0.63
	var rm = StandardMaterial3D.new()
	rm.albedo_color = col
	rm.emission_enabled = true
	rm.emission = col
	tm2.material = rm
	ring.mesh = tm2
	if axis == Vector3(1, 0, 0):
		ring.rotation_degrees = Vector3(0, 0, 90)
	elif axis == Vector3(0, 0, 1):
		ring.rotation_degrees = Vector3(90, 0, 0)
	gizmo_root.add_child(ring)
func _plane_axis(o, d, comp, val):
	if abs(d[comp]) < 0.0001:
		return -1.0
	var t = (val - o[comp]) / d[comp]
	return t if t > 0 else -1.0

func _obj_seg_dist(od, fo):
	var pp = fo.get("pos", [0, 0])
	var g = terr.sample_h(float(pp[0]), float(pp[1])) if terr != null else 0.0
	var sc = float(fo.get("s", 1.0))
	var base = Vector3(float(pp[0]), g + float(fo.get("y", 0.0)), float(pp[1]))
	var top = base + Vector3(0, 1.2 * sc, 0)
	return _seg_ray_dist(od[0], od[1], base, top)
func _cell_pick(p):
	var m = L().get("map", {})
	var bi = -1
	var bd = 0.6
	var bsrc = ""
	var i = 0
	for o in m.get("objects", []):
		if str(o.get("k", "")) != "stairs":
			var c = o.get("cell", [0, 0])
			var dd = Vector2(float(c[0]) + 0.5 - p.x, float(c[1]) + 0.5 - p.z).length()
			if dd < bd:
				bd = dd
				bi = i
				bsrc = "objects"
		i += 1
	i = 0
	for r in m.get("rocks", []):
		var dd = Vector2(float(r[0]) + 0.5 - p.x, float(r[1]) + 0.5 - p.z).length()
		if dd < bd:
			bd = dd
			bi = i
			bsrc = "rocks"
		i += 1
	if bi < 0:
		return null
	return {"src": bsrc, "i": bi}
func _convert_cell_to_free(ci):
	var m = L().get("map", {})
	var k = "rock"
	var cell = [0, 0]
	if ci["src"] == "objects":
		var o = m["objects"][ci["i"]]
		k = str(o.get("k", "rock"))
		cell = o["cell"]
		m["objects"].remove_at(ci["i"])
	else:
		var r = m["rocks"][ci["i"]]
		cell = [int(r[0]), int(r[1])]
		m["rocks"].remove_at(ci["i"])
	if not m.has("free"):
		m["free"] = []
	m["free"].append({"k": k, "pos": [cell[0] + 0.5, cell[1] + 0.5], "rot": 0.0, "s": 1.0})
	L()["map"] = m
	_sync()

func _light_seg_dist(od, ld):
	var pp = ld.get("pos", [0, 0])
	var g = terr.sample_h(float(pp[0]), float(pp[1])) if terr != null else 0.0
	var base = Vector3(float(pp[0]), g, float(pp[1]))
	var top = Vector3(float(pp[0]), g + float(ld.get("y", 2.0)) + 0.2, float(pp[1]))
	return _seg_ray_dist(od[0], od[1], base, top)

func _vis_pick(od):
	if od == null:
		return null
	var o = od[0]
	var d = od[1]
	var hit = null
	var ht = 1000000.0
	for i in FL.size():
		var vr = _obj_vis(FL[i])
		var t = d.dot(vr[0] - o)
		if t < 0 or t > ht:
			continue
		var q = o + d * t
		if (q - vr[0]).length() < vr[1]:
			ht = t
			hit = ["obj", i]
	for i in LIGHTS.size():
		var lp = LIGHTS[i].get("pos", [0, 0])
		var g = terr.sample_h(float(lp[0]), float(lp[1])) if terr != null else 0.0
		var c = Vector3(float(lp[0]), g + float(LIGHTS[i].get("y", 2.0)), float(lp[1]))
		var t = d.dot(c - o)
		if t < 0 or t > ht:
			continue
		var q = o + d * t
		if (q - c).length() < 0.35:
			ht = t
			hit = ["light", i]
	return hit
func _obj_vis(fo):
	var k = str(fo.get("k", "rock"))
	var od = OBJ3.get(k, {})
	var sc = float(fo.get("s", 1.0))
	var pp = fo.get("pos", [0, 0])
	var g = terr.sample_h(float(pp[0]), float(pp[1])) if terr != null else 0.0
	var base = Vector3(float(pp[0]), g + float(fo.get("y", 0.0)), float(pp[1]))
	var myoff = float(od.get("myoff", 0.0))
	if bool(od.get("render3d", false)):
		var ms = float(od.get("mscale", 1.0)) * sc
		return [base + Vector3(0, 0.45 * ms + myoff, 0), maxf(0.3, 0.55 * ms)]
	var oimg = str(od.get("img", ""))
	if oimg != "":
		var h = 1.2 * float(od.get("scale", 1.0)) * float(od.get("mscale", 1.0)) * sc
		var ot = _tex(oimg)
		var w = h * 0.6
		if ot != null and ot.get_height() > 0:
			w = h * ot.get_width() / float(ot.get_height())
		return [base + Vector3(0, h * 0.5 + myoff, 0), maxf(0.3, 0.45 * maxf(w, h))]
	return [base + Vector3(0, 0.25, 0), maxf(0.3, 0.5 * sc)]

func _rot_y(r0):
	return float(r0[1]) if r0 is Array else float(r0)

func _chunk_add_at(p):
	var m = L().get("terrain", {})
	var ch = m.get("chunks", {})
	var cs = int(m.get("chunk_size", 8))
	var key = str(int(p.x / cs)) + "," + str(int(p.z / cs))
	if ch.has(key):
		return
	var n = cs * cs
	ch[key] = {"h": [], "w": []}
	ch[key]["h"].resize(n)
	ch[key]["w"].resize(n)
	for i in n:
		ch[key]["h"][i] = 0.0
		ch[key]["w"][i] = 0.0
	m["chunks"] = ch
	L()["terrain"] = m
	_sync()
	rebuild()
func _chunk_del_at(p):
	var m = L().get("terrain", {})
	var ch = m.get("chunks", {})
	var cs = int(m.get("chunk_size", 8))
	var key = str(int(p.x / cs)) + "," + str(int(p.z / cs))
	if not ch.has(key):
		return
	ch.erase(key)
	m["chunks"] = ch
	L()["terrain"] = m
	_sync()
	rebuild()
