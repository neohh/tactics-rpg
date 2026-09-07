# END_RETURN_V1
extends Node3D
var turn_state = null
var coordinator = null
var _busy_time = 0.0
var yaw_n: Node3D
var pitch_n: Node3D
var cam: Camera3D
var yaw = 0.6
var pitch = -0.9
var dist = 12.0
var target = Vector3(4, 0, 3)
var mid_drag = false
var right_drag = false
var CLASSES = {}
var OBJ3 = {}
var LOCS = {}
var CHARS = {}
var units3 = []
var npcs3 = []
var objects3 = []
var ELEV = {}
var climb = {}
var stairs_list = []
var selected = -1
var move_hl = []
var attack_hl = []
var hl_root: Node3D
var busy = false
var terrain = null
var hovered = -1
var acted_idx = -1
var handled_click = false
var game_over3 = false
var won3 = false
var status: Label
var info: Label
var loc_id = ""
var deploy_mode = true
var deploy_max_x = 3
var deploy_i = 0
var deploy_min_x = 0
var start_btn: Button
var fire_btn: Button
var magic_charges = 2
var casting = false
var qte_pressed = false
var qte_on = false
var fires = []
var bfs_parent = {}
var shove_mode = false
var arrow_mode = false
var skills_box: VBoxContainer
var heal_mode = false
var activations_left = 2
var act_lab: Label
const PCLS = ["assassin", "swordsman", "halberd", "archer", "mage"]
func _ready():
	add_to_group("live")
	loc_id = Game.cur_loc
	_setup()
	_lights()
	CLASSES = _lj("res://data/classes.json")
	LOCS = _lj("res://data/locations.json")
	CHARS = _lj("res://data/chars.json")
	OBJ3 = _lj("res://data/objects.json")
	hl_root = Node3D.new()
	add_child(hl_root)
	_build()
	_apply_explore()
	if units3.size() > 0:
		var mnx = 999
		var mny = 999
		var mxx = -999
		var mxy = -999
		for u in units3:
			mnx = mini(mnx, u.cell.x)
			mxx = maxi(mxx, u.cell.x)
			mny = mini(mny, u.cell.y)
			mxy = maxi(mxy, u.cell.y)
		target = Vector3((mnx + mxx) * 0.5 + 0.5, 0, (mny + mxy) * 0.5 + 0.5)
	else:
		target = Vector3(terrain.GW * 0.5, 0, terrain.GH * 0.5)
	_apply()
	_ui()
	_init_turn_state()
func _setup():
	yaw_n = Node3D.new()
	add_child(yaw_n)
	pitch_n = Node3D.new()
	yaw_n.add_child(pitch_n)
	cam = Camera3D.new()
	pitch_n.add_child(cam)
	cam.position = Vector3(0, 0, dist)
func _lj(p):
	var f = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var j = JSON.parse_string(f.get_as_text())
	f.close()
	return {} if j == null else j
func _tex(path):
	if path == "" or not FileAccess.file_exists(path):
		return null
	var im = Image.new()
	if im.load(path) != OK:
		return null
	return ImageTexture.create_from_image(im)
func _p(c):
	return Vector3(c.x + 0.5, 0, c.y + 0.5)
func _th(c):
	var h = terrain.cell_h(c.x, c.y) if terrain != null else 0.0
	return h + ELEV.get(str(c.x) + "," + str(c.y), 0.0)
func _mat_defs():
	var m = _lj("res://data/materials.json")
	var d = []
	for k in m:
		d.append({"col": Color(str(m[k].get("color", "#888888"))), "tex": str(m[k].get("tex", ""))})
	return d
func _build():
	var td = LOCS.get(loc_id, {}).get("terrain", {})
	terrain = load("res://scripts/terrain.gd").new(int(td.get("gw", 8)), int(td.get("gh", 6)), int(td.get("sub", 8)))
	add_child(terrain)
	terrain.set_materials(_mat_defs())
	if td.size() > 0:
		terrain.from_data(td)
	else:
		terrain.build()

	var camp = LOCS.get(loc_id, {}).get("map", {})
	ELEV = {}
	for ek in camp.get("elev", {}):
		ELEV[ek] = float(camp["elev"][ek])
	climb = {}
	_render_elev()
	for o in camp.get("objects", []):
		var okk = o.get("k", "rock")
		var oc = Vector2i(o["cell"][0], o["cell"][1])
		if okk == "stairs":
			var dd = o.get("dir", [0, -1])
			_render_stairs(oc, Vector2i(dd[0], dd[1]))
			stairs_list.append({"c": oc, "d": Vector2i(dd[0], dd[1])})
			climb[str(oc.x) + "," + str(oc.y) + "->" + str(oc.x + dd[0]) + "," + str(oc.y + dd[1])] = true
			climb[str(oc.x + dd[0]) + "," + str(oc.y + dd[1]) + "->" + str(oc.x) + "," + str(oc.y)] = true
		else:
			objects3.append(oc)
			_obj(Vector3(oc.x + 0.5, 0, oc.y + 0.5), okk)
	for fo in camp.get("free", []):
		_obj_free(fo)
		for c in _footprint(fo):
			if not objects3.has(c):
				objects3.append(c)
	var dp = camp.get("decor", "")
	if str(dp) != "" and FileAccess.file_exists(str(dp)):
		var di = load(str(dp)).instantiate()
		for c in di.get_children():
			if c.name.begins_with("TERRAIN_REF") or c.name.begins_with("O_") or c.name.begins_with("U_") or c.name.begins_with("LGT_"):
				c.queue_free()
		add_child(di)
	for ld in camp.get("lights", []):
		_game_light(ld)
	for r in camp.get("rocks", []):
		objects3.append(Vector2i(r[0], r[1]))
		_obj(Vector3(r[0] + 0.5, 0, r[1] + 0.5), "rock")
	var es = Game.explore_start
	var has0 = false
	for u in camp.get("units", []):
		if int(u.get("team", 1)) == 0:
			has0 = true
	var from_explore = es != null and es.has("players") and es["players"].size() > 0
	if from_explore:
		has0 = true
		for pl in es["players"]:
			var c = Vector2i(int(pl["cell"][0]), int(pl["cell"][1]))
			_spawn_unit(c, 0, str(pl.get("cls", "swordsman")), Vector2(1, 0), str(pl.get("char", "")))
			var uu = units3[units3.size() - 1]
			uu.hp = int(pl.get("hp", uu.hp))
			uu.maxhp = int(pl.get("maxhp", uu.maxhp))
			_set_hp_bar(uu)
	for u in camp.get("units", []):
		var tm = int(u.get("team", 1))
		if tm == 0 and from_explore:
			continue
		_spawn_unit(Vector2i(u["cell"][0], u["cell"][1]), tm, u.get("cls", "swordsman"), Vector2(1, 0) if tm == 0 else Vector2(-1, 0), u.get("char", ""))
	# F2_WORLD
	if not from_explore:
		if Game.party.size() > 0:
			has0 = true
			var dmin = _calc_deploy_min_x()
			var di = 0
			for m in Game.party:
				if di >= 6:
					break
				PartyTools.ensure_hp(m)
				_spawn_unit(Vector2i(dmin, 1 + di), 0, str(m.get("cls", "swordsman")), Vector2(1, 0), str(m.get("char", "")))
				var uu2 = units3[units3.size() - 1]
				uu2.hp = int(m.get("hp", uu2.hp))
				uu2.maxhp = int(m.get("maxhp", uu2.maxhp))
				_set_hp_bar(uu2)
				di += 1
			var enc = Game.enc
			if enc != null:
				for ob in enc.get("map", {}).get("objects", []):
					objects3.append(Vector2i(ob["cell"][0], ob["cell"][1]))
					_obj(Vector3(ob["cell"][0] + 0.5, 0, ob["cell"][1] + 0.5), ob.get("k", "rock"))
				for un in enc.get("map", {}).get("units", []):
					_spawn_unit(Vector2i(un["cell"][0], un["cell"][1]), int(un.get("team", 1)), un.get("cls", "swordsman"), Vector2(-1, 0))
				Game.enc = null
		else:
			for i in 4:
				_spawn_unit(Vector2i(6, 1 + i), 1, PCLS[i], Vector2(-1, 0))

	deploy_min_x = 9999
	for key in terrain.chunk_mask:
		var p2 = key.split(",")
		var cx0 = int(p2[0]) * terrain.CHUNK - terrain.OX
		if cx0 < deploy_min_x:
			deploy_min_x = cx0
	if deploy_min_x > 9000:
		deploy_min_x = 0
	for np in camp.get("npcs", []):
		_spawn_npc(np)
	deploy_mode = not has0
	_log_click("BUILD loc=%s GW=%d GH=%d OX=%d OY=%d chunks=%s deploy_min_x=%d" % [loc_id, terrain.GW, terrain.GH, terrain.OX, terrain.OY, str(terrain.chunk_mask.keys()), deploy_min_x])
	if deploy_mode:
		_hl_deploy()
func _spawn_unit(c, team, cls, dir, cid = ""):
	var cd = CLASSES.get(cls, {})
	var sc = float(cd.get("scale", 1.0))
	var root = Node3D.new()
	root.position = _p(c) + Vector3(0, _th(c), 0)
	add_child(root)
	var imgp = ""
	if cid != "":
		imgp = str(CHARS.get(cid, {}).get("img", ""))
	if imgp == "":
		imgp = str(cd.get("img", ""))
	var t = _tex(imgp)
	if t != null:
		var sp = Sprite3D.new()
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.pixel_size = 0.004
		sp.scale = Vector3(sc, sc, sc)
		sp.position = Vector3(0, 0.85 * sc, 0)
		sp.texture = t
		root.add_child(sp)
	else:
		var m = MeshInstance3D.new()
		var cm = CapsuleMesh.new()
		cm.radius = 0.28
		cm.height = 0.9
		var mi = StandardMaterial3D.new()
		mi.albedo_color = Color(0.2, 0.5, 0.9) if team == 0 else Color(0.9, 0.25, 0.25)
		cm.material = mi
		m.mesh = cm
		m.position = Vector3(0, 0.45, 0)
		root.add_child(m)
	var holder = Node3D.new()
	holder.position = Vector3(0, 0.05, 0)
	holder.rotation.y = atan2(-dir.y, dir.x)
	root.add_child(holder)
	var cone = MeshInstance3D.new()
	var cm2 = CylinderMesh.new()
	cm2.top_radius = 0.02
	cm2.bottom_radius = 0.11
	cm2.height = 0.4
	var ma = StandardMaterial3D.new()
	ma.albedo_color = Color(0.2, 0.5, 0.9).lightened(0.4) if team == 0 else Color(0.9, 0.25, 0.25).lightened(0.4)
	cm2.material = ma
	cone.mesh = cm2
	cone.rotation.z = -PI / 2
	cone.position = Vector3(0.32, 0, 0)
	holder.add_child(cone)
	var bar = MeshInstance3D.new()
	var bq = QuadMesh.new()
	bq.size = Vector2(0.7, 0.1)
	var mf = StandardMaterial3D.new()
	mf.albedo_color = Color(0.2, 0.9, 0.2)
	mf.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	bq.material = mf
	bar.mesh = bq
	bar.position = Vector3(0, 1.8 * sc, 0)
	root.add_child(bar)
	var lb = Label3D.new()
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var nm2 = str(CHARS.get(cid, {}).get("name", "")) if cid != "" else ""
	if nm2 == "":
		nm2 = str(cd.get("name", cls))
	lb.text = nm2
	lb.pixel_size = 0.004
	lb.position = Vector3(0, 1.8 * sc + 0.3, 0)
	lb.modulate = Color(1, 1, 1) if team == 0 else Color(1, 0.6, 0.6)
	root.add_child(lb)
	var area = Area3D.new()
	area.input_ray_pickable = true
	area.collision_layer = 2
	var csh = CollisionShape3D.new()
	var shp = CapsuleShape3D.new()
	shp.radius = 0.45
	shp.height = 1.8 * sc
	csh.shape = shp
	csh.position = Vector3(0, 0.9 * sc, 0)
	area.add_child(csh)
	root.add_child(area)
	area.input_event.connect(_on_area_click.bind(units3.size()))
	units3.append({"cell": c, "team": team, "cls": cls, "hp": int(cd.get("hp", 2)), "maxhp": int(cd.get("hp", 2)), "facing": dir, "root": root, "bar": bar, "arrow": holder, "moved": false, "attacked": false, "char": cid})
func _obj(p, k):
	p.y = terrain.sample_h(p.x, p.z) if terrain != null else 0.0
	var od = OBJ3.get(k, {})
	var mn = _model_inst(str(od.get("model", ""))) if bool(od.get("render3d", false)) else null
	if mn != null:
		var ms = float(od.get("mscale", 1.0))
		mn.scale = Vector3(ms, ms, ms)
		mn.position = p + Vector3(0, float(od.get("myoff", 0.0)), 0)
		add_child(mn)
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
		add_child(sp)
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
	add_child(m)
func _ui():
	var ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	var btn = Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = "Завершить ход"
	btn.position = Vector2(10, 10)
	btn.pressed.connect(_end_turn_safe)
	ui.add_child(btn)
	start_btn = Button.new()
	start_btn.focus_mode = Control.FOCUS_NONE
	start_btn.text = "В БОЙ"
	start_btn.position = Vector2(150, 10)
	start_btn.pressed.connect(_start_battle)
	start_btn.visible = deploy_mode
	ui.add_child(start_btn)
	act_lab = Label.new()
	act_lab.position = Vector2(400, 10)
	act_lab.add_theme_color_override("font_color", Color(1, 0.9, 0.1))
	ui.add_child(act_lab)
	start_btn.visible = deploy_mode
	start_btn.visible = deploy_mode
	fire_btn = Button.new()
	fire_btn.focus_mode = Control.FOCUS_NONE
	fire_btn.text = "Огонь 3x3 — 2"
	fire_btn.position = Vector2(260, 10)
	fire_btn.pressed.connect(_toggle_cast)
	ui.add_child(fire_btn)
	fire_btn.visible = false
	skills_box = VBoxContainer.new()
	skills_box.position = Vector2(880, 60)
	skills_box.custom_minimum_size = Vector2(240, 0)
	ui.add_child(skills_box)
	status = Label.new()
	status.position = Vector2(10, 45)
	status.text = "Твой ход: клик по своему юниту."
	ui.add_child(status)
	info = Label.new()
	info.position = Vector2(10, 70)
	ui.add_child(info)
	_upd_info()
func _upd_info():
	if act_lab != null:
		act_lab.text = "Активаций: %d из 2" % activations_left
	if info == null:
		return
	if acted_idx < 0:
		info.text = "За раунд: 2 активации — две разные фигуры или одна дважды (усталость)."
	else:
		var u = units3[acted_idx]
		info.text = "%s: ходов %d, атак %d." % [CLASSES.get(u.cls, {}).get("name", ""), 0 if u.moved else 1, 0 if u.attacked else 1]
func _start_battle():
	deploy_mode = false; _turn_state_on_battle_start()
	_setup_coordinator()
	activations_left = 2
	for u in units3:
		u.acts = 0
		u.spent = false
		u.tired = false
		u.fresh = false
		u.acted_prev = false
		if u.cls == "mage":
			u.heal_uses = 3
			u.fire_uses = 3
	if start_btn != null:
		start_btn.visible = false
	var pre = LOCS.get(loc_id, {}).get("dlg", {}).get("pre", "")
	if pre != "":
		await _play_dlg(pre)
	if Game.flags.get("peace_" + loc_id, false) or Game.flags.get("paid_bandits", false):
		var mode = str(LOCS.get(loc_id, {}).get("dlg", {}).get("peace", "leave"))
		if mode == "neutral":
			for u in units3:
				if u.team == 1:
					u.team = 2
					for chn in u.root.get_children():
						if chn is Label3D:
							chn.modulate = Color(1, 1, 0.6)
			status.text = "Бандиты получили золото и остались нейтральными."
		else:
			for i in range(units3.size() - 1, -1, -1):
				if units3[i].team == 1:
					if is_instance_valid(units3[i].root):
						units3[i].root.queue_free()
					units3.remove_at(i)
			status.text = "Бандиты получили золото и не трогают тебя."
		_upd_info()
		return
	status.text = "Твой ход: клик по своему юниту."
	_upd_info()
func _apply():
	yaw_n.position = target
	yaw_n.rotation = Vector3(0, yaw, 0)
	pitch_n.rotation = Vector3(pitch, 0, 0)
	cam.position = Vector3(0, 0, dist)
func _cheb(a, b):
	return max(abs(a.x - b.x), abs(a.y - b.y))
func _unit_at(c):
	for i in units3.size():
		if units3[i].hp > 0 and units3[i].cell == c:
			return i
	return -1
func _ar(u):
	return int(CLASSES.get(u.cls, {}).get("ar", 1))
func _mv(u):
	var base = int(CLASSES.get(u.cls, {}).get("move", 3))
	if u.get("tired", false):
		base -= 1
	if u.get("fresh", false):
		base += 1
	if u.get("burn", 0) > 0 or u.get("pin", 0) > 0:
		base -= 1
	return maxi(1, base)
func _bfs(start, rng, pass_units = false):
	var res = []
	bfs_parent = {}
	var dist = {start: 0}
	var fr = [start]
	while fr.size() > 0:
		var nxt = []
		for c in fr:
			if dist[c] >= rng:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n = c + d
				if n.x < 0 or n.y < 0 or n.x >= (terrain.GW if terrain != null else 8) or n.y >= (terrain.GH if terrain != null else 6):
					continue
				if terrain != null and not terrain.has_cell(n.x, n.y):
					continue
				if objects3.has(n) or dist.has(n):
					continue
				if not pass_units and _unit_at(n) >= 0:
					continue
				if terrain != null and not _can_step(c, n):
					continue
				bfs_parent[n] = c
				dist[n] = dist[c] + 1
				res.append(n)
				nxt.append(n)
		fr = nxt
	return res
func _select(i):
	var u = units3[i]
	if selected != i and activations_left <= 0 and u.get("acts", 0) == 0:
		status.text = "Активации закончились — заверши ход."
		return
	selected = i
	_compute_hl()
	status.text = "Выбран %s: зелёные — ход, красные — атака." % CLASSES.get(u.cls, {}).get("name", "")
	_upd_info()
func _compute_hl():
	for c in hl_root.get_children():
		c.queue_free()
	move_hl = []
	attack_hl = []
	if selected < 0 or units3[selected].hp <= 0:
		_skills_ui()
		return
	var u = units3[selected]
	if not u.moved:
		for cc in _bfs(u.cell, _mv(u), u.cls == "assassin"):
			if _unit_at(cc) < 0:
				move_hl.append(cc)
	if not u.attacked:
		for j in units3.size():
			var t = units3[j]
			if t.team != u.team and t.hp > 0 and u.cls != "mage" and _cheb(u.cell, t.cell) <= _ar(u):
				attack_hl.append(t.cell)
	for c in move_hl:
		_hl_quad(c, Color(0.2, 0.9, 0.3, 0.5))
	for c in attack_hl:
		_hl_quad(c, Color(0.9, 0.2, 0.2, 0.5))
	if selected >= 0:
		_disc(units3[selected].cell, Color(1, 0.85, 0.2, 0.6), 0.4)
	if fire_btn != null:
		fire_btn.visible = false
	_skills_ui()
func _hl_quad(c, col):
	var m = MeshInstance3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var N = 4
	for iy in N:
		for ix in N:
			var p00 = _hl_pt(c, ix, iy, N)
			var p10 = _hl_pt(c, ix + 1, iy, N)
			var p11 = _hl_pt(c, ix + 1, iy + 1, N)
			var p01 = _hl_pt(c, ix, iy + 1, N)
			st.add_vertex(p00)
			st.add_vertex(p10)
			st.add_vertex(p11)
			st.add_vertex(p00)
			st.add_vertex(p11)
			st.add_vertex(p01)
	st.generate_normals()
	var mi = StandardMaterial3D.new()
	mi.albedo_color = col
	mi.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mi)
	m.mesh = st.commit()
	hl_root.add_child(m)
func _hl_pt(c, ix, iy, N):
	var x = c.x + 0.05 + (0.9 * float(ix)) / N
	var z = c.y + 0.05 + (0.9 * float(iy)) / N
	var y = 0.03
	if terrain != null:
		y += terrain.sample_h(x, z)
	y += ELEV.get(str(c.x) + "," + str(c.y), 0.0)
	return Vector3(x, y, z)
func _disc(c, col, rr):
	var m = MeshInstance3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cx = c.x + 0.5
	var cz = c.y + 0.5
	var base = _h_at(cx, cz, c) + 0.05
	var S = 16
	var prev = _disc_pt(cx, cz, rr, 0.0, c)
	for s in range(1, S + 1):
		var a = float(s) * TAU / float(S)
		var p = _disc_pt(cx, cz, rr, a, c)
		st.add_vertex(Vector3(cx, base, cz))
		st.add_vertex(prev)
		st.add_vertex(p)
		prev = p
	st.generate_normals()
	var mi = StandardMaterial3D.new()
	mi.albedo_color = col
	mi.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mi)
	m.mesh = st.commit()
	hl_root.add_child(m)
func _disc_pt(cx, cz, rr, a, c):
	var x = cx + cos(a) * rr
	var z = cz + sin(a) * rr
	return Vector3(x, _h_at(x, z, c) + 0.05, z)
func _h_at(x, z, c):
	var h = terrain.sample_h(x, z) if terrain != null else 0.0
	return h + ELEV.get(str(c.x) + "," + str(c.y), 0.0)
func _pick_cell():
	var m = get_viewport().get_mouse_position()
	var c3 = get_viewport().get_camera_3d()
	var from = c3.project_ray_origin(m)
	var dir = c3.project_ray_normal(m)
	if abs(dir.y) < 0.0001:
		return null
	var t = -from.y / dir.y
	if t < 0:
		return null
	var p = from + dir * t
	var cx = int(p.x)
	var cz = int(p.z)
	if cx < 0 or cz < 0 or (terrain != null and (cx >= terrain.GW or cz >= terrain.GH)):
		return null
	return Vector2i(cx, cz)
func _dir_to(d):
	if abs(d.x) >= abs(d.y):
		return Vector2(sign(d.x), 0)
	return Vector2(0, sign(d.y))
func _set_face(u, d):
	u.facing = d
	u.arrow.rotation.y = atan2(-d.y, d.x)
func _move_to(i, c):
	var u = units3[i]
	_act_spend(i)
	var from = u.cell
	_set_face(u, _dir_to(c - u.cell))
	u.cell = c
	u.moved = true
	var tw = create_tween()
	tw.tween_property(u.root, "position", _p(c) + Vector3(0, _th(c), 0), 0.25)
	if _fire_at(c):
		u.burn = 1
		_float_text(u.root.position, "ГОРИТ!", Color(1, 0.5, 0.1))
	await _slip_check(i, from, c)
	_ao_check(i, c)
	if u.team == 0:
		acted_idx = i
		status.text = "Фигура походила — атакуй или заверши ход."
	_compute_hl()
func _zone_of(t, from):
	var d = Vector2(from.x - t.cell.x, from.y - t.cell.y).normalized()
	var f = t.facing.normalized()
	var dot = f.x * d.x + f.y * d.y
	if dot <= -0.7:
		return "back"
	if dot >= 0.7:
		return "front"
	return "side"
func _attack(i, j):
	var u = units3[i]
	var t = units3[j]
	if u.cls == "mage":
		return
	if t.team == 2:
		t.team = 1
		for chn in t.root.get_children():
			if chn is Label3D:
				chn.modulate = Color(1, 0.6, 0.6)
			elif chn is MeshInstance3D and chn.mesh is CapsuleMesh and chn.mesh.material != null:
				chn.mesh.material.albedo_color = Color(0.9, 0.25, 0.25)
		_float_text(t.root.position, "В БОЙ!", Color(1, 0.4, 0.2))
	_act_spend(i)
	u.attacked = true
	if u.team == 0:
		selected = -1
	_set_face(u, _dir_to(t.cell - u.cell))
	var cd = CLASSES.get(u.cls, {})
	var z = _zone_of(t, u.cell)
	var cf = float(cd.get("cf", 0.6))
	var cbk = float(cd.get("cb", 0.6))
	var chance = cbk if z == "back" else (cf if z == "front" else (cf + cbk) * 0.5)
	if u.get("tired", false):
		chance *= 0.9
	if u.get("fresh", false):
		chance *= 1.1
	if t.get("mark", 0) > 0 and u.team == 0:
		chance *= 1.2
	if u.team == 0:
		if await _qte("УДАР! [SPACE]", 0.9):
			chance += 0.25
	elif t.team == 0:
		if await _qte("ВРАГ АТАКУЕТ! БЛОК! [SPACE]", 0.9):
			_float_text(t.root.position, "ОТРАЖЕНО!", Color(0.4, 0.8, 1.0))
			status.text = "Ты отразил атаку!"
			_compute_hl()
			_check_end()
			_upd_info()
			return
	if randf() < chance:
		var dmg = 1
		var prey = str(cd.get("prey", ""))
		if prey != "" and prey == str(t.cls):
			dmg += 1
			_float_text(t.root.position, "КОНТР!", Color(1, 0.8, 0.2))
		if t.get("offbal", 0) > 0:
			dmg += 1
			_float_text(t.root.position, "+1 РАСБАЛАНС", Color(1, 0.5, 0.1))
		t.hp -= dmg
		_set_hp_bar(t)
		_float_text(t.root.position, "-%d" % dmg, Color(1, 0.3, 0.3))
		if u.cls == "assassin":
			t.mark = 2
			_float_text(t.root.position, "МЕТКА", Color(0.8, 0.2, 0.8))
		if u.cls == "swordsman":
			t.offbal = 2
		if t.hp <= 0:
			t.root.visible = false
			status.text = "Попадание (%s) — убит!" % z
		else:
			status.text = "Попадание (%s, -%d)." % [z, dmg]
	else:
		_float_text(t.root.position, "МИМО", Color(0.8, 0.8, 0.8))
		status.text = "Промах (%s, %d%%)." % [z, int(chance * 100)]
	_compute_hl()
	_check_end()
	_upd_info()
func _end_turn_old():
	if busy or game_over3:
		return
	busy = true
	acted_idx = -1
	selected = -1
	shove_mode = false
	arrow_mode = false
	heal_mode = false
	_compute_hl()
	status.text = "Ход врагов…"
	_enemy_phase_old()
func _enemy_phase_old():
	var acted = false
	var e_acts = 2
	for i in units3.size():
		var u = units3[i]
		if u.team != 1 or u.hp <= 0:
			continue
		if e_acts <= 0:
			break
		var action = _ai_decide(i)
		_log_click("EP: i=%d action=%s" % [i, str(action)])
		if action.size() > 0:
			e_acts -= 1
			status.text = "Враг действует…"
			await get_tree().create_timer(0.35).timeout
			if action.has("move_to"):
				var st = action["move_to"]
				var from = u.cell
				_set_face(u, _dir_to(st - u.cell))
				u.cell = st
				var tw = create_tween()
				tw.tween_property(u.root, "position", _p(st) + Vector3(0, _th(st), 0), 0.25)
				await tw.finished
				if _fire_at(st):
					u.burn = 1
				await _slip_check(i, from, st)
				_ao_check(i, st)
				await get_tree().create_timer(0.2).timeout
			if action.has("heal") and units3[action["heal"]].hp > 0:
				_do_heal(i, action["heal"])
				acted = true
			if action.has("mage_fire"):
				_cast_fire(action["mage_fire"], i)
				acted = true
			if action.has("attack") and units3[action["attack"]].hp > 0:
				await _attack(i, action["attack"])
				acted = true
	if not acted:
		status.text = "Враги выжидают."
	await get_tree().create_timer(0.3).timeout
	for u in units3:
		u.moved = false
		u.attacked = false
		u.reacted = false
		u.acted_prev = u.get("acts", 0) > 0
		u.acts = 0
		u.spent = false
		u.tired = false
		u.fresh = false
		if u.get("mark", 0) > 0:
			u.mark -= 1
		if u.get("offbal", 0) > 0:
			u.offbal -= 1
		if u.get("pin", 0) > 0:
			u.pin -= 1
		if u.get("burn", 0) > 0 and u.hp > 0:
			u.burn -= 1
			if u.burn > 0:
				u.hp -= 1
				_set_hp_bar(u)
				_float_text(u.root.position, "-1 горение", Color(1, 0.5, 0.1))
				if u.hp <= 0:
					u.root.visible = false
	activations_left = 2
	busy = false
	acted_idx = -1
	if not game_over3:
		status.text = "Твой ход: клик по своему юниту."
	_upd_info()
	_tick_fire()
	_age_fires()
	_check_end()
func _ai_decide(i):
	var u = units3[i]
	var gw = terrain.GW if terrain != null else 8
	var gh = terrain.GH if terrain != null else 6
	var ti = -1
	var bh = 999
	for j in units3.size():
		var t = units3[j]
		if u.cls != "mage" and t.team == 0 and t.hp > 0 and _can_hit(u.cell, t.cell):
			var sc = t.hp
			if _zone_of(t, u.cell) == "back":
				sc -= 1
			if sc < bh:
				bh = sc
				ti = j
	if ti >= 0:
		return {"attack": ti}
	if u.cls == "swordsman" and not u.attacked:
		for j in units3.size():
			var t = units3[j]
			if t.team != 0 or t.hp <= 0 or _cheb(u.cell, t.cell) > 1:
				continue
			var dir = _dir_to(t.cell - u.cell)
			var dest = t.cell + Vector2i(roundi(dir.x), roundi(dir.y))
			var good = false
			if dest.x < 0 or dest.y < 0 or dest.x >= gw or dest.y >= gh:
				good = true
			elif _th(t.cell) - _th(dest) > 0.5:
				good = true
			elif _fire_at(dest):
				good = true
			elif (objects3.has(dest) or _unit_at(dest) >= 0) and t.hp <= 1:
				good = true
			if good:
				return {"shove": j}
	if u.cls == "archer" and not u.attacked and u.get("uses", 0) < 2:
		var bj = -1
		var bd = 99
		for j in units3.size():
			var t = units3[j]
			if t.team == 0 and t.hp > 0 and not _fire_at(t.cell):
				var d = _cheb(u.cell, t.cell)
				if d <= _ar(u) and d < bd:
					bd = d
					bj = j
		if bj >= 0:
			return {"fire_at": Vector2i(units3[bj].cell.x, units3[bj].cell.y)}
	ti = _nearest_player(u.cell)
	if ti < 0:
		return {}
	var t = units3[ti]
	var res = {}
	var mv = _best_step(u, t)
	if mv != null:
		res["move_to"] = mv
		if u.cls != "mage" and _cheb(mv, t.cell) <= _ar(u):
			res["attack"] = ti
	return res
func _nearest_player(c):
	var bi = -1
	var bd = 99
	for i in units3.size():
		var u = units3[i]
		if u.team == 0 and u.hp > 0:
			var d = _cheb(c, u.cell)
			if d < bd:
				bd = d
				bi = i
	return bi
func _best_step(u, t):
	var best = null
	var bs = 999
	for c in _bfs(u.cell, _mv(u), u.cls == "assassin"):
		if _fire_at(c):
			continue
		var d = _cheb(c, t.cell)
		if u.cls == "assassin":
			var z = _zone_of(t, c)
			if z == "back":
				d -= 2
			elif z == "side":
				d -= 1
		if d < bs:
			bs = d
			best = c
	return best
func _can_hit(from, to):
	var uf = null
	for uu in units3:
		if uu.cell == from:
			uf = uu
			break
	if uf == null:
		return false
	var d = to - from
	if _cheb(from, to) > _ar(uf):
		return false
	if _ar(uf) == 1 and abs(d.x) == 1 and abs(d.y) == 1:
		if objects3.has(from + Vector2i(d.x, 0)) or objects3.has(from + Vector2i(0, d.y)):
			return false
	return true
func _check_end():
	var p = 0
	var e = 0
	for u in units3:
		if u.hp > 0:
			if u.team == 0:
				p += 1
			elif u.team == 1:
				e += 1
	if e == 0:
		game_over3 = true
		won3 = true
		_show_end_overlay(true)
		_on_win()
	elif p == 0:
		game_over3 = true
		won3 = false
		_show_end_overlay(false)
		_play_dlg(LOCS.get(loc_id, {}).get("dlg", {}).get("loss", ""))
		status.text = "ПОРАЖЕНИЕ… M — на карту."
func _show_end_overlay(win):
	var old = get_node_or_null("EndUI")
	if old != null:
		old.queue_free()
	var ui = Control.new()
	ui.name = "EndUI"
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.45)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(bg)
	var lb = Label.new()
	lb.set_anchors_preset(Control.PRESET_CENTER)
	lb.add_theme_font_size_override("font_size", 48)
	if win:
		lb.text = "ПОБЕДА!"
		lb.add_theme_color_override("font_color", Color(0.3, 1, 0.4))
	else:
		lb.text = "ПОРАЖЕНИЕ…"
		lb.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	ui.add_child(lb)
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_top = 60
	vbox.offset_bottom = 140
	vbox.offset_left = -160
	vbox.offset_right = 160
	vbox.add_theme_constant_override("separation", 8)
	ui.add_child(vbox)
	var stay_btn = Button.new()
	stay_btn.text = "Остаться на локации"
	stay_btn.custom_minimum_size = Vector2(300, 36)
	stay_btn.pressed.connect(_on_stay_loc)
	vbox.add_child(stay_btn)
	var map_btn = Button.new()
	map_btn.text = "На глобальную карту"
	map_btn.custom_minimum_size = Vector2(300, 36)
	map_btn.pressed.connect(_on_to_map)
	vbox.add_child(map_btn)

func _on_win():
	var L = LOCS.get(loc_id, {})
	Game.flags["clear_" + loc_id] = true
	Game.clear_hook(loc_id)
	var got = []
	if Game.explore_return != null:
		_drop_loot_on_deaths()
		for u in units3:
			if u.team == 0:
				for m in Game.party:
					if str(m.get("char", "")) != "" and str(m.get("char", "")) == str(u.get("char", "")):
						m["hp"] = u.hp
						m["maxhp"] = u.maxhp
		if Game.has_method("loc_state_get"):
			Game.loc_state_get(loc_id)["cleared_day"] = Game.day
		var total = 0
		for u in units3:
			if u.team == 1 and u.hp <= 0:
				total += StatsTools.xp_for_kill(CLASSES.get(u.cls, {}), int(u.get("lvl", 1)))
		if total > 0:
			for m in Game.party:
				var ups = PartyTools.add_xp(m, total)
				if ups > 0:
					Game._notify("Новый уровень: %s (ур. %d, +1 перк-поинт)" % [str(Game.resolve_char(str(m.get("char", ""))).get("name", str(m.get("char", "")))), int(m.get("level", 1))])
	else:
		for row in L.get("loot", []):
			if randf() * 100.0 < float(row.get("chance", 0)):
				Game.add_item(row.get("item", ""))
				got.append(str(row.get("item", "")))
	_play_dlg(L.get("dlg", {}).get("win", ""))
	status.text = "ПОБЕДА! Лут: %s. M — дальше." % (", ".join(got) if got.size() > 0 else "ничего")
func _float_text(pos, txt, col):
	var lb = Label3D.new()
	lb.text = txt
	lb.pixel_size = 0.006
	lb.modulate = col
	lb.position = pos + Vector3(0, 2.2, 0)
	add_child(lb)
	var tw = create_tween()
	tw.tween_property(lb, "position:y", lb.position.y + 0.8, 0.8)
	tw.parallel().tween_property(lb, "modulate:a", 0.0, 0.8)
	tw.tween_callback(lb.queue_free)
func _play_dlg(dn, hook = false):
	if dn == "":
		return
	var f = FileAccess.open("res://data/dialogs/%s.json" % dn, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if data == null:
		return
	var d = load("res://scripts/dialog.gd").new()
	d.chars = CHARS
	d.hook = hook
	add_child(d)
	await d.play(data)
func _on_area_click(_cam, ev, _p2, _n, _si, i):
	if not (ev is InputEventMouseButton) or not ev.pressed or ev.button_index != MOUSE_BUTTON_LEFT or busy:
		return
	handled_click = true
	var u = units3[i]
	if u.hp <= 0:
		return
	if shove_mode and selected >= 0 and u.team == 1:
		_do_shove(selected, i)
		return
	if heal_mode and selected >= 0 and u.team == 0:
		_do_heal(selected, i)
		return
	if arrow_mode and selected >= 0 and u.team == 1:
		_fire_arrow(selected, u.cell)
		return
	if u.team == 0:
		if selected != i and activations_left <= 0 and u.get("acts", 0) == 0:
			status.text = "Активации закончились — заверши ход."
			return
		_select(i)
	elif selected >= 0 and attack_hl.has(u.cell):
		_attack(selected, i)
		return
	# Если не атакуем, то для нейтралов (team=2) — диалог/лавка
	if u.team == 2:
		var cid = str(u.get("char", ""))
		if cid != "":
			var cd = CHARS.get(cid, {})
			if cd.has("shop"):
				var sh = load("res://scripts/shop.gd").new()
				sh.stock = cd.get("shop", ["potion", "food"])
				add_child(sh)
				return
			var dn = Game.talk_dlg(cid)
			if dn == "":
				dn = str(cd.get("dlg", ""))
			if dn != "":
				_play_dlg(dn, true)
func _click_action():
	var _lgc = _pick_cell()
	_log_click("CLICK mouse=%s cell=%s deploy=%s min_x=%d" % [str(get_viewport().get_mouse_position()), str(_lgc), str(deploy_mode), _calc_deploy_min_x()])
	if handled_click:
		handled_click = false
		return
	if casting:
		var cc = _pick_cell()
		if cc != null:
			_cast_fire(cc)
		return
	var c = _pick_cell()
	if arrow_mode and selected >= 0 and c != null:
		_fire_arrow(selected, c)
		return
	if c == null:
		return
	if deploy_mode:
		var dmin = _calc_deploy_min_x()
		if c.x >= dmin and c.x < dmin + 3 and terrain != null and terrain.has_cell(c.x, c.y) and _unit_at(c) < 0 and not objects3.has(c) and deploy_i < 5:
			var cls = PCLS[deploy_i]
			_spawn_unit(c, 0, cls, Vector2(1, 0))
			deploy_i += 1
			status.text = "Поставлен %s (%d/4). «В БОЙ» — начать." % [CLASSES.get(cls, {}).get("name", ""), deploy_i]
		return
	if selected >= 0 and move_hl.has(c):
		_move_to(selected, c)
	elif selected >= 0 and attack_hl.has(c):
		var j = _unit_at(c)
		if j >= 0:
			_attack(selected, j)
	else:
		if not (selected >= 0 and units3[selected].moved and not units3[selected].attacked):
			selected = -1
		_compute_hl()
func _unhandled_input(ev):
	if qte_on and ev is InputEventKey and ev.pressed and ev.keycode == KEY_SPACE:
		qte_pressed = true
		get_viewport().set_input_as_handled()
		return
	if ev is InputEventKey and ev.pressed:
		if ev.keycode == KEY_M:
			_leave_battle()
			return
		if selected >= 0 and not busy and not deploy_mode:
			if ev.keycode == KEY_Q:
				_rotate_sel(-1)
				return
			if ev.keycode == KEY_E:
				_rotate_sel(1)
				return
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_RIGHT:
			right_drag = ev.pressed
		elif ev.button_index == MOUSE_BUTTON_MIDDLE:
			mid_drag = ev.pressed
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist = clampf(dist - 1.0, 4, 30)
			_apply()
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist = clampf(dist + 1.0, 4, 30)
			_apply()
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not busy and not qte_on:
			_click_action()
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
func _rotate_sel(d):
	var u = units3[selected]
	var a = d * PI / 4.0
	var f = u.facing
	var nf = Vector2(f.x * cos(a) - f.y * sin(a), f.x * sin(a) + f.y * cos(a))
	nf = Vector2(round(nf.x * 2) / 2, round(nf.y * 2) / 2)
	if nf != Vector2.ZERO:
		_set_face(u, nf)
		_compute_hl()


func _model_inst(path):
	if path == "" or not FileAccess.file_exists(path):
		return null
	var res = load(path)
	if res is PackedScene:
		return res.instantiate()
	return null

func _lights():
	var dl = DirectionalLight3D.new()
	dl.rotation_degrees = Vector3(-50, 30, 0)
	dl.light_energy = 1.1
	add_child(dl)
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.07, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.6)
	env.ambient_light_energy = 0.7
	var we = WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _toggle_cast():
	if busy or deploy_mode:
		return
	if selected < 0 or units3[selected].cls != "mage" or units3[selected].get("fire_uses", 0) <= 0:
		status.text = "Огонь 3x3 доступен только магу."
		return
	casting = not casting
	status.text = "Выбери клетку — огонь 3x3. ПКМ — отмена." if casting else "Твой ход: клик по своему юниту."
	_upd_magic()
func _upd_magic():
	if fire_btn != null:
		fire_btn.text = "Огонь 3x3 — %d" % magic_charges
		fire_btn.disabled = magic_charges <= 0
func _cast_fire(center, caster_i = -1):
	var u = null
	if caster_i >= 0:
		u = units3[caster_i]
	elif selected >= 0 and units3[selected].cls == "mage":
		u = units3[selected]
	if u == null or u.cls != "mage":
		return
	if u.attacked or u.get("fire_uses", 0) <= 0:
		if u.team == 0:
			status.text = "Огонь недоступен."
		return
	if _cheb(u.cell, center) > 4:
		if u.team == 0:
			status.text = "Слишком далеко."
		return
	_act_spend(units3.find(u))
	u.attacked = true
	u.fire_uses -= 1
	casting = false
	var boosted = false
	if u.team == 0:
		boosted = await _qte("ФОКУС! [SPACE]", 0.9)
	var cells = []
	var nodes = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var c = center + Vector2i(dx, dy)
			if c.x < 0 or c.y < 0 or c.x >= (terrain.GW if terrain != null else 8) or c.y >= (terrain.GH if terrain != null else 6):
				continue
			if terrain != null and not terrain.has_cell(c.x, c.y):
				continue
			cells.append(c)
			nodes.append(_fire_quad(c))
	fires.append({"cells": cells, "left": 2, "nodes": nodes, "dmg": 2 if boosted else 1})
	for un in units3:
		if un.hp > 0 and cells.has(un.cell):
			un.burn = 2
			_float_text(un.root.position, "ГОРЕНИЕ", Color(1, 0.5, 0.1))
	status.text = "Огонь накрыл область!"
	_compute_hl()
	_upd_info()
func _fire_quad(c):
	var m = MeshInstance3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var N = 4
	for iy in N:
		for ix in N:
			var p00 = _hl_pt(c, ix, iy, N)
			var p10 = _hl_pt(c, ix + 1, iy, N)
			var p11 = _hl_pt(c, ix + 1, iy + 1, N)
			var p01 = _hl_pt(c, ix, iy + 1, N)
			st.add_vertex(p00)
			st.add_vertex(p10)
			st.add_vertex(p11)
			st.add_vertex(p00)
			st.add_vertex(p11)
			st.add_vertex(p01)
	st.generate_normals()
	var mi = StandardMaterial3D.new()
	mi.albedo_color = Color(1.0, 0.45, 0.1, 0.55)
	mi.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.emission_enabled = true
	mi.emission = Color(1.0, 0.35, 0.05)
	mi.emission_energy_multiplier = 2.0
	mi.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mi)
	m.mesh = st.commit()
	add_child(m)
	return m
func _tick_fire():
	for f in fires:
		for u in units3:
			if u.hp > 0 and f.cells.has(u.cell):
				u.hp -= int(f.get("dmg", 1))
				_set_hp_bar(u)
				_float_text(u.root.position, "-1 огонь", Color(1, 0.5, 0.1))
				if u.hp <= 0:
					u.root.visible = false
	_check_end()
func _age_fires():
	var alive = []
	for f in fires:
		f.left -= 1
		if f.left <= 0:
			for n in f.nodes:
				n.queue_free()
		else:
			alive.append(f)
	fires = alive
func _set_hp_bar(u):
	var r = clampf(float(u.hp) / float(u.maxhp), 0.0, 1.0)
	u.bar.scale.x = maxf(0.05, r)
	u.bar.mesh.material.albedo_color = Color(0.9, 0.2, 0.2).lerp(Color(0.2, 0.9, 0.2), r)

func _apply_explore():
	if Game.explore_start == null:
		return
	var su = Game.explore_start
	Game.explore_start = null
	var t1 = []
	var t0 = []
	for u in units3:
		if u.team == 1:
			t1.append(u)
		elif u.team == 0:
			t0.append(u)
	var ec = su.get("enemies", [])
	for i in min(ec.size(), t1.size()):
		var c = Vector2i(int(ec[i][0]), int(ec[i][1]))
		t1[i].cell = c
		t1[i].root.position = _p(c) + Vector3(0, _th(c), 0)
	var pls = su.get("players", [])
	for i in min(pls.size(), t0.size()):
		var c = Vector2i(int(pls[i]["cell"][0]), int(pls[i]["cell"][1]))
		t0[i].cell = c
		t0[i].root.position = _p(c) + Vector3(0, _th(c), 0)
	var pc = su.get("player", [])
	if pc.size() == 2 and t0.size() > 0:
		var c = Vector2i(int(pc[0]), int(pc[1]))
		t0[0].cell = c
		t0[0].root.position = _p(c) + Vector3(0, _th(c), 0)
func _can_step(a, b):
	var ea = ELEV.get(str(a.x) + "," + str(a.y), 0.0)
	var eb = ELEV.get(str(b.x) + "," + str(b.y), 0.0)
	if ea == 0.0 and eb == 0.0:
		return terrain.can_move(a.x, a.y, b.x, b.y) if terrain != null else true
	var ha = _th(a)
	var hb = _th(b)
	if abs(ha - hb) <= 0.5:
		return true
	for sl in stairs_list:
		var c = sl["c"]
		var d = sl["d"]
		if (a == c and b == c + d) or (b == c and a == c + d):
			return true
	return climb.has(str(a.x) + "," + str(a.y) + "->" + str(b.x) + "," + str(b.y))
func _elev_key(c):
	return str(c.x) + "," + str(c.y)
func _render_elev():
	for kk in ELEV:
		var parts = kk.split(",")
		var cx = int(parts[0])
		var cy = int(parts[1])
		var h = ELEV[kk]
		var m = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(1.0, h, 1.0)
		var mi = StandardMaterial3D.new()
		mi.albedo_color = Color(0.35, 0.3, 0.25)
		bm.material = mi
		m.mesh = bm
		m.position = Vector3(cx + 0.5, h * 0.5, cy + 0.5)
		add_child(m)
func _render_stairs(c, d):
	var h0 = _th(c)
	var h1 = _th(Vector2i(c.x + d.x, c.y + d.y))
	var n = 4
	for i in n:
		var t = float(i + 1) / float(n)
		var m = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.9, 0.1, 0.24)
		var mi = StandardMaterial3D.new()
		mi.albedo_color = Color(0.5, 0.4, 0.3)
		bm.material = mi
		m.mesh = bm
		var along = Vector3(d.x, 0, d.y).normalized()
		var p = Vector3(c.x + 0.5, 0, c.y + 0.5) + along * (0.5 * t)
		m.position = Vector3(p.x, lerp(h0, h1, t) * 0.5 + 0.05, p.z)
		m.rotation.y = atan2(d.x, d.y)
		add_child(m)

func _qte(text, dur):
	if qte_on:
		return false
	qte_on = true
	qte_pressed = false
	var ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bgc = ColorRect.new()
	bgc.color = Color(0, 0, 0, 0.35)
	bgc.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(bgc)
	var lab = Label.new()
	lab.text = text
	lab.position = Vector2(280, 180)
	lab.add_theme_font_size_override("font_size", 26)
	ui.add_child(lab)
	var bar = ColorRect.new()
	bar.color = Color(1, 0.8, 0.2)
	bar.position = Vector2(280, 220)
	bar.size = Vector2(320, 10)
	ui.add_child(bar)
	add_child(ui)
	var fo = get_viewport().gui_get_focus_owner()
	if fo != null:
		fo.release_focus()
	var t = 0.0
	while t < dur and not qte_pressed:
		await get_tree().process_frame
		t += get_process_delta_time()
		bar.size.x = 320 * clampf(1.0 - t / dur, 0.0, 1.0)
	ui.queue_free()
	qte_on = false
	return qte_pressed

func _fire_at(c):
	for f in fires:
		if f.cells.has(c):
			return true
	return false
func _slip_check(i, from, to):
	var u = units3[i]
	if u.cls != "assassin":
		return
	var cur = to
	var touched = false
	while bfs_parent.has(cur) and cur != from:
		cur = bfs_parent[cur]
		if cur != from and _unit_at(cur) >= 0:
			touched = true
	if not touched:
		return
	if u.team == 0:
		if not await _qte("ПРОСКОЛЬЗНУТЬ! [SPACE]", 0.8):
			u.hp -= 1
			_set_hp_bar(u)
			_float_text(u.root.position, "-1 задело!", Color(1, 0.3, 0.3))
			if u.hp <= 0:
				u.root.visible = false
				_check_end()
	else:
		if randf() < 0.4:
			u.hp -= 1
			_set_hp_bar(u)
			_float_text(u.root.position, "-1 задело!", Color(1, 0.3, 0.3))
			if u.hp <= 0:
				u.root.visible = false
func _ao_check(mi, to):
	var mv = units3[mi]
	if mv.hp <= 0:
		return
	for j in units3.size():
		var h = units3[j]
		if h.team == mv.team or h.hp <= 0 or h.cls != "halberd":
			continue
		if h.get("reacted", false):
			continue
		if _cheb(h.cell, to) <= 1:
			h.reacted = true
			_float_text(h.root.position, "АЛЕБАРДА!", Color(1, 1, 0.5))
			units3[mi].pin = 2
			_float_text(units3[mi].root.position, "ПРИГВОЖДЁН", Color(0.9, 0.7, 0.2))
			_strike(j, mi)
func _strike(i, j):
	var u = units3[i]
	var t = units3[j]
	_set_face(u, _dir_to(t.cell - u.cell))
	var cd = CLASSES.get(u.cls, {})
	var chance = (float(cd.get("cf", 0.6)) + float(cd.get("cb", 0.6))) * 0.5
	if randf() < chance:
		t.hp -= 1
		_set_hp_bar(t)
		_float_text(t.root.position, "-1", Color(1, 0.3, 0.3))
		if t.hp <= 0:
			t.root.visible = false
	else:
		_float_text(t.root.position, "МИМО", Color(0.8, 0.8, 0.8))
	_check_end()
func _do_shove(i, j):
	var u = units3[i]
	var t = units3[j]
	_act_spend(i)
	if u.attacked or _cheb(u.cell, t.cell) > 1:
		status.text = "Толчок недоступен."
		return
	shove_mode = false
	u.attacked = true
	if u.team == 0:
		acted_idx = i
	_set_face(u, _dir_to(t.cell - u.cell))
	var dir = _dir_to(t.cell - u.cell)
	var dest = t.cell + Vector2i(roundi(dir.x), roundi(dir.y))
	_float_text(u.root.position, "ТОЛЧОК!", Color(1, 1, 0.5))
	if dest.x < 0 or dest.y < 0 or dest.x >= (terrain.GW if terrain != null else 8) or dest.y >= (terrain.GH if terrain != null else 6):
		t.hp -= 2
		_set_hp_bar(t)
		_float_text(t.root.position, "-2 сбил!", Color(1, 0.3, 0.3))
	elif _th(t.cell) - _th(dest) > 0.5:
		t.hp -= 2
		_set_hp_bar(t)
		_float_text(t.root.position, "-2 падение!", Color(1, 0.3, 0.3))
	elif not _can_step(t.cell, dest) or objects3.has(dest) or _unit_at(dest) >= 0:
		t.hp -= 1
		_set_hp_bar(t)
		_float_text(t.root.position, "-1 удар!", Color(1, 0.3, 0.3))
	else:
		t.cell = dest
		var tw = create_tween()
		tw.tween_property(t.root, "position", _p(dest) + Vector3(0, _th(dest), 0), 0.2)
		if _fire_at(dest):
			t.burn = 1
	if t.hp <= 0:
		t.root.visible = false
	_compute_hl()
	_check_end()
	_upd_info()
func _fire_arrow(i, c):
	var u = units3[i]
	if u.attacked or _cheb(u.cell, c) > _ar(u):
		status.text = "Недоступно."
		arrow_mode = false
		return
	arrow_mode = false
	u.attacked = true
	acted_idx = i
	fires.append({"cells": [c], "left": 2, "nodes": [_fire_quad(c)], "dmg": 1})
	_float_text(u.root.position, "ОГОНЬ!", Color(1, 0.5, 0.1))
	status.text = "Клетка подожжена."
	_compute_hl()
	_upd_info()
func _skills_ui():
	if skills_box == null:
		return
	for cch in skills_box.get_children():
		cch.queue_free()
	var t = Label.new()
	t.text = "НАВЫКИ"
	skills_box.add_child(t)
	if selected < 0:
		return
	var u = units3[selected]
	var nm = Label.new()
	nm.text = str(CLASSES.get(u.cls, {}).get("name", ""))
	skills_box.add_child(nm)
	if u.cls == "swordsman":
		var b = Button.new()
		b.text = "Толчок"
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func():
			shove_mode = not shove_mode
			arrow_mode = false
			status.text = "Толчок: клик по врагу рядом.")
		skills_box.add_child(b)
	elif u.cls == "archer":
		var b = Button.new()
		b.text = "Огненная стрела"
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func():
			arrow_mode = not arrow_mode
			shove_mode = false
			status.text = "Огненная стрела: клик по клетке в радиусе.")
		skills_box.add_child(b)
	elif u.cls == "assassin":
		var l = Label.new()
		l.text = "Проскользнуть: сквозь юнитов (QTE)"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		skills_box.add_child(l)
	elif u.cls == "mage":
		var bh = Button.new()
		bh.text = "Лечение (%d)" % u.get("heal_uses", 0)
		bh.focus_mode = Control.FOCUS_NONE
		bh.pressed.connect(func():
			heal_mode = not heal_mode
			status.text = "Лечение: клик по своему в радиусе 4.")
		skills_box.add_child(bh)
		var bf = Button.new()
		bf.text = "Огонь 3x3 (%d)" % u.get("fire_uses", 0)
		bf.focus_mode = Control.FOCUS_NONE
		bf.pressed.connect(_toggle_cast)
		skills_box.add_child(bf)
	elif u.cls == "halberd":
		var l = Label.new()
		l.text = "Дальность 2; бьёт подошедших вплотную"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		skills_box.add_child(l)

func _ai_fire(i, c):
	var u = units3[i]
	u.attacked = true
	u.uses = u.get("uses", 0) + 1
	fires.append({"cells": [c], "left": 2, "nodes": [_fire_quad(c)], "dmg": 1})
	_float_text(u.root.position, "ОГОНЬ!", Color(1, 0.5, 0.1))
	status.text = "Враг поджигает клетку под тобой!"

func _act_spend(i):
	var u = units3[i]
	if u.team != 0 or u.get("spent", false):
		return
	u.spent = true
	activations_left -= 1
	u.acts = u.get("acts", 0) + 1
	if u.acts >= 2:
		u.tired = true
		u.moved = false
		u.attacked = false
	elif not u.get("acted_prev", false):
		u.fresh = true
	acted_idx = i
	_upd_info()
func off_dec(u):
	u.offbal -= 1
func _do_heal(i, j):
	var u = units3[i]
	var t = units3[j]
	if u.get("heal_uses", 0) <= 0 or u.attacked or _cheb(u.cell, t.cell) > 4 or t.hp >= t.maxhp:
		status.text = "Лечение недоступно."
		heal_mode = false
		return
	_act_spend(i)
	heal_mode = false
	u.attacked = true
	u.heal_uses -= 1
	t.hp = mini(t.maxhp, t.hp + 1)
	_set_hp_bar(t)
	_float_text(t.root.position, "+1", Color(0.3, 1, 0.4))
	status.text = "Лечение: +1 HP."
	_compute_hl()
	_upd_info()

func _footprint(fo):
	var res = []
	var k = str(fo.get("k", "rock"))
	var sc = float(fo.get("s", 1.0))
	var br = float(OBJ3.get(k, {}).get("br", 0.45)) * sc
	var pp = fo.get("pos", [0, 0])
	var px = float(pp[0])
	var py = float(pp[1])
	for cx in range(int(px - br - 0.5), int(px + br + 0.5) + 1):
		for cy in range(int(py - br - 0.5), int(py + br + 0.5) + 1):
			if Vector2(cx + 0.5, cy + 0.5).distance_to(Vector2(px, py)) <= br + 0.45:
				res.append(Vector2i(cx, cy))
	return res
func _obj_free(fo):
	var k = str(fo.get("k", "rock"))
	var pp = fo.get("pos", [0, 0])
	var g = terrain.sample_h(float(pp[0]), float(pp[1])) if terrain != null else 0.0
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
		add_child(mn)
		return
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
		add_child(sp)
		return
	var m = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.7, 0.5, 0.7)
	m.mesh = bm
	m.scale = Vector3(sc, sc, sc)
	m.rotation = rv
	m.position = p + Vector3(0, 0.25, 0)
	add_child(m)
func _vis_off(k):
	var od = OBJ3.get(k, {})
	if bool(od.get("render3d", false)):
		return float(od.get("myoff", 0.0))
	var oimg = str(od.get("img", ""))
	if oimg != "":
		var h = 1.2 * float(od.get("scale", 1.0)) * float(od.get("mscale", 1.0))
		return h * 0.5 + float(od.get("myoff", 0.0))
	return 0.25

func _game_light(ld):
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
	var g = terrain.sample_h(float(pp[0]), float(pp[1])) if terrain != null else 0.0
	l.position = Vector3(float(pp[0]), g + float(ld.get("y", 2.0)), float(pp[1]))
	var r0 = ld.get("rot", 0.0)
	var ry = float(r0[1]) if r0 is Array else float(r0)
	l.rotation.y = deg_to_rad(ry)
	add_child(l)

func _hl_deploy():
	var minx = 1000000
	var miny = 1000000
	if terrain != null:
		for key in terrain.chunk_mask:
			var p2 = key.split(",")
			var cx = int(p2[0]) * terrain.CHUNK - terrain.OX
			var cy = int(p2[1]) * terrain.CHUNK - terrain.OY
			if cx < minx:
				minx = cx
			if cy < miny:
				miny = cy
	if minx >= 1000000:
		return
	deploy_max_x = minx + 3
	for cx in range(minx, deploy_max_x):
		for cy in range(miny, terrain.GH if terrain != null else 0):
			var c = Vector2i(cx, cy)
			if terrain != null and terrain.has_cell(cx, cy) and not objects3.has(c) and _unit_at(c) < 0:
				_hl_quad(c, Color(0.2, 0.9, 0.3, 0.25))

func _log_click(txt):
	var f = FileAccess.open("res://click_log.txt", FileAccess.READ)
	var old = ""
	if f != null:
		old = f.get_as_text()
		f.close()
	var w = FileAccess.open("res://click_log.txt", FileAccess.WRITE)
	if w != null:
		w.store_string(old + txt + "\n")
		w.close()

func _calc_deploy_min_x():
	var mnx = 1000000
	if terrain != null:
		for key in terrain.chunk_mask:
			var p2 = key.split(",")
			var cx0 = int(p2[0]) * terrain.CHUNK - terrain.OX
			if cx0 < mnx:
				mnx = cx0
	if mnx > 900000:
		mnx = 0
	return mnx

func _spawn_npc(np):
	var cid = str(np.get("char", ""))
	var cd = CHARS.get(cid, {})
	var cc = np.get("cell", [2, 2])
	var c = Vector2i(int(cc[0]), int(cc[1]))
	var root = Node3D.new()
	root.position = _p(c) + Vector3(0, _th(c), 0)
	add_child(root)
	var imgp = ""
	if cid != "":
		imgp = str(CHARS.get(cid, {}).get("img", ""))
	if imgp == "":
		imgp = str(cd.get("img", ""))
	var t = _tex(imgp)
	var sc = float(cd.get("scale", 1.0))
	if t != null:
		var sp = Sprite3D.new()
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.pixel_size = 0.004
		sp.scale = Vector3(sc, sc, sc)
		sp.position = Vector3(0, 0.85 * sc, 0)
		sp.texture = t
		root.add_child(sp)
	else:
		var m = MeshInstance3D.new()
		var cm = CapsuleMesh.new()
		cm.radius = 0.28
		cm.height = 0.9
		var mi = StandardMaterial3D.new()
		mi.albedo_color = Color(0.2, 0.8, 0.4)
		cm.material = mi
		m.mesh = cm
		m.position = Vector3(0, 0.45, 0)
		root.add_child(m)
	var lb = Label3D.new()
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.text = str(cd.get("name", cid))
	lb.pixel_size = 0.004
	lb.position = Vector3(0, 1.8 * sc + 0.3, 0)
	lb.modulate = Color(0.4, 1, 0.5)
	root.add_child(lb)
	var area = Area3D.new()
	area.input_ray_pickable = true
	var csh = CollisionShape3D.new()
	var shp = CapsuleShape3D.new()
	shp.radius = 0.45
	shp.height = 1.8 * sc
	csh.shape = shp
	csh.position = Vector3(0, 0.9 * sc, 0)
	area.add_child(csh)
	root.add_child(area)
	area.input_event.connect(_on_npc_click.bind(npcs3.size()))
	npcs3.append({"root": root, "np": np, "cid": cid})
func _on_npc_click(_cam, ev, _p2, _n, _si, i):
	if not (ev is InputEventMouseButton) or not ev.pressed or ev.button_index != MOUSE_BUTTON_LEFT or busy:
		return
	handled_click = true
	_talk_npc(i)
func _talk_npc(i):
	if i < 0 or i >= npcs3.size():
		return
	var cid = npcs3[i]["cid"]
	var cd = CHARS.get(cid, {})
	if cd.has("shop"):
		var s = load("res://scripts/shop.gd").new()
		s.stock = cd.get("shop", ["potion", "food"])
		add_child(s)
		return
	var dn = Game.talk_dlg(cid)
	if dn == "":
		dn = str(cd.get("dlg", ""))
	if dn != "":
		_play_dlg(dn, true)
func _talk_ui():
	if busy or npcs3.size() == 0:
		return
	var ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bgc = ColorRect.new()
	bgc.color = Color(0, 0, 0, 0.6)
	bgc.set_anchors_preset(Control.PRESET_FULL_RECT)
	bgc.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			ui.queue_free())
	ui.add_child(bgc)
	var box = VBoxContainer.new()
	box.position = Vector2(300, 200)
	ui.add_child(box)
	var t = Label.new()
	t.text = "Говорить с:"
	box.add_child(t)
	for i in npcs3.size():
		var cid = npcs3[i]["cid"]
		var b = Button.new()
		b.text = str(CHARS.get(cid, {}).get("name", cid))
		b.pressed.connect(func():
			ui.queue_free()
			_talk_npc(i))
		box.add_child(b)
	var x = Button.new()
	x.text = "Закрыть"
	x.pressed.connect(func(): ui.queue_free())
	box.add_child(x)
	add_child(ui)
# BATTLE_TAIL_V1
func _init_turn_state():
	pass
func _turn_state_on_battle_start():
	pass
func _setup_coordinator():
	pass
func _end_turn_safe():
	if game_over3:
		_leave_battle()
		return
	if busy or deploy_mode:
		return
	busy = true
	acted_idx = -1
	selected = -1
	shove_mode = false
	arrow_mode = false
	heal_mode = false
	_compute_hl()
	status.text = "Ход врагов…"
	_busy_time = 0.0
	await _enemy_phase_old()
	_finalize_turn_safe()
func _finalize_turn_safe():
	activations_left = 2
	busy = false
	acted_idx = -1
	if not game_over3:
		status.text = "Твой ход: клик по своему юниту."
	_upd_info()
func _process(d):
	if busy:
		_busy_time += d
		if _busy_time > 10.0:
			_busy_time = 0.0
			_finalize_turn_safe()
	else:
		_busy_time = 0.0
func _leave_battle():
	if Game.explore_return != null and not game_over3:
		get_tree().change_scene_to_file("res://explore3d.tscn")
		return
	if Game.explore_return != null and game_over3 and won3:
		get_tree().change_scene_to_file("res://explore3d.tscn")
		return
	if Game.explore_return != null and game_over3 and not won3:
		Game.explore_return = null
		Game.explore_ground = null
		if str(ConfigTools.get_val("defeat_mode", "town")) == "town":
			for m in Game.party:
				m["hp"] = 1
			Game.gold = int(Game.gold * 0.8)
		get_tree().change_scene_to_file("res://overworld3d.tscn")
		return
	Game.explore_return = null
	get_tree().change_scene_to_file("res://overworld3d.tscn")
func _drop_loot_on_deaths():
	var L = LOCS.get(loc_id, {})
	if Game.explore_ground == null:
		Game.explore_ground = []
	for u in units3:
		if u.team == 1 and u.hp <= 0:
			for row in L.get("loot", []):
				if randf() * 100.0 < float(row.get("chance", 0)):
					Game.explore_ground.append({"item": str(row.get("item", "")), "pos": [u.cell.x + 0.5, u.cell.y + 0.5], "day": Game.day})
func _on_stay_loc():
	var pp = []
	for u in units3:
		if u.team == 0:
			for m in Game.party:
				if str(m.get("char", "")) != "" and str(m.get("char", "")) == str(u.get("char", "")):
					m["hp"] = u.hp
					m["maxhp"] = u.maxhp
			pp.append([str(u.get("char", "")), u.cell.x + 0.5, u.cell.y + 0.5])
	Game.explore_return = {"loc": loc_id, "party_pos": pp}
	Game.explore_ground = null
	get_tree().change_scene_to_file("res://explore3d.tscn")

func _on_to_map():
	for u in units3:
		if u.team == 0:
			for m in Game.party:
				if str(m.get("char", "")) != "" and str(m.get("char", "")) == str(u.get("char", "")):
					m["hp"] = u.hp
					m["maxhp"] = u.maxhp
	Game.explore_return = null
	Game.explore_ground = null
	get_tree().change_scene_to_file("res://overworld3d.tscn")
# DEDUP_DONE
