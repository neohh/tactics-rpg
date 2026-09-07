extends Node3D
var terrain
var LOCS = {}
var OBJ3 = {}
var CLASSES = {}
var CHARS = {}
var loc_id = ""
var yaw = 0.0
var cam_dist = 4.0
var speed = 3.0
var right_drag = false
var mid_drag = false
var pitch = -0.9
var yaw_n: Node3D
var pitch_n: Node3D
var cam: Camera3D
var cam_offset = Vector3.ZERO
var party_n = []
var enemies = []
var objects3 = []
var ground = []
var target_point = null
var hint: Label
var pre_played = false
var combat_lock = false
var npcs3 = []

func _ready():
	loc_id = Game.cur_loc
	CLASSES = _lj("res://data/classes.json")
	LOCS = _lj("res://data/locations.json")
	OBJ3 = _lj("res://data/objects.json")
	CHARS = _lj("res://data/chars.json")
	Game.ensure_party()
	var td = LOCS.get(loc_id, {}).get("terrain", {})
	terrain = load("res://scripts/terrain.gd").new(int(td.get("gw", 8)), int(td.get("gh", 6)), int(td.get("sub", 8)))
	add_child(terrain)
	terrain.set_materials(_mat_defs())
	if td.size() > 0:
		terrain.from_data(td)
	else:
		terrain.build()
	var camp = LOCS.get(loc_id, {}).get("map", {})
	for o in camp.get("objects", []):
		var oc = Vector2i(int(o["cell"][0]), int(o["cell"][1]))
		objects3.append(oc)
		_obj(Vector3(oc.x + 0.5, 0, oc.y + 0.5), o.get("k", "rock"))
	for r in camp.get("rocks", []):
		objects3.append(Vector2i(int(r[0]), int(r[1])))
		_obj(Vector3(r[0] + 0.5, 0, r[1] + 0.5), "rock")
	var sp = LOCS.get(loc_id, {}).get("spawn", null)
	var sx = 4.0
	var sy = 4.0
	if sp != null:
		sx = float(sp[0])
		sy = float(sp[1])
	elif terrain != null:
		var ks = terrain.chunk_mask.keys()
		if ks.size() > 0:
			var p = ks[0].split(",")
			sx = int(p[0]) * 8.0 + 4.0
			sy = int(p[1]) * 8.0 + 4.0
	# RETPOS_V1
	var ret = Game.explore_return
	# F2_EXP
	var any_alive = false
	for m in Game.party:
		if int(m.get("hp", 0)) > 0:
			any_alive = true
	if not any_alive:
		for m in Game.party:
			m["hp"] = maxi(1, int(m.get("maxhp", 1)))
	var i = 0
	for m in Game.party:
		if int(m.get("hp", 0)) <= 0:
			continue
		var root = _actor(str(m.get("cls", "swordsman")), Color(0.2, 0.5, 0.9), str(m.get("char", "")))
		var pos = Vector2(sx, sy)
		if i > 0:
			pos = Vector2(sx - 0.6 * float(i), sy + 0.5 * float(i % 2))
		if ret is Dictionary:
			for pp in ret.get("party_pos", []):
				if str(pp[0]) == str(m.get("char", "")):
					pos = Vector2(float(pp[1]), float(pp[2]))
		root.position = Vector3(pos.x, 0, pos.y)
		root.position.y = terrain.sample_h(root.position.x, root.position.z) if terrain != null else 0.0
		party_n.append({"root": root, "m": m})
		i += 1
	var ls = Game.loc_state_get(loc_id)
	var cd = int(ls.get("cleared_day", -999))
	var respawn = int(ConfigTools.get_val("respawn_days", 3))
	if Game.day - cd >= respawn:
		for u in camp.get("units", []):
			if int(u.get("team", 1)) == 1:
				var er = _actor(str(u.get("cls", "swordsman")), Color(0.9, 0.25, 0.25), str(u.get("char", "")))
				er.position = Vector3(int(u["cell"][0]) + 0.5, 0, int(u["cell"][1]) + 0.5)
				er.position.y = terrain.sample_h(er.position.x, er.position.z) if terrain != null else 0.0
				enemies.append({"root": er, "cls": str(u.get("cls", "swordsman"))})
	# Random encounter enemies
	var enc = Game.enc
	if enc != null:
		Game.enc = null
		if hint != null:
			hint.text = "Случайная встреча!"
		for u in enc.get("map", {}).get("units", []):
			if int(u.get("team", 1)) == 1:
				var er = _actor(str(u.get("cls", "swordsman")), Color(0.9, 0.25, 0.25), str(u.get("char", "")))
				er.position = Vector3(int(u["cell"][0]) + 0.5, 0, int(u["cell"][1]) + 0.5)
				er.position.y = terrain.sample_h(er.position.x, er.position.z) if terrain != null else 0.0
				enemies.append({"root": er, "cls": str(u.get("cls", "swordsman"))})
	if Game.explore_ground != null:
		if not ls.has("ground"):
			ls["ground"] = []
		for gg in Game.explore_ground:
			ls["ground"].append(gg)
		Game.explore_ground = null
		Game.explore_return = null
		Game.autosave()
	var ttl = int(ConfigTools.get_val("ground_ttl_days", 1))
	var alive = []
	for gg in ls.get("ground", []):
		if Game.day - int(gg.get("day", 1)) <= ttl:
			alive.append(gg)
	ls["ground"] = alive
	for gg in alive:
		_spawn_ground(gg)
	# NPCs (trader, etc.)
	for np in camp.get("npcs", []):
		_spawn_npc(np)
	var dl = DirectionalLight3D.new()
	dl.rotation_degrees = Vector3(-50, 30, 0)
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
	yaw_n = Node3D.new()
	add_child(yaw_n)
	pitch_n = Node3D.new()
	yaw_n.add_child(pitch_n)
	cam = Camera3D.new()
	cam.name = "cam"
	pitch_n.add_child(cam)
	cam.position = Vector3(0, 0, cam_dist)
	var ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	hint = Label.new()
	hint.position = Vector2(10, 10)
	ui.add_child(hint)
	hint.text = "WASD/клик — идти | ПКМ камера | колесо зум | E подобрать | R привал | P отряд | M карта"
	_party_bar(ui)

func _party_bar(ui):
	var bar = HBoxContainer.new()
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -336
	bar.offset_right = 336
	bar.offset_top = -86
	bar.offset_bottom = -8
	bar.add_theme_constant_override("separation", 6)
	ui.add_child(bar)
	for i in 6:
		var slot = PanelContainer.new()
		slot.custom_minimum_size = Vector2(106, 78)
		var vb = VBoxContainer.new()
		slot.add_child(vb)
		var tr = TextureRect.new()
		tr.custom_minimum_size = Vector2(48, 48)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		vb.add_child(tr)
		var nl = Label.new()
		vb.add_child(nl)
		bar.add_child(slot)
		if i < Game.party.size():
			var m = Game.party[i]
			var cid = str(m.get("char", ""))
			var img = str(CHARS.get(cid, {}).get("img", ""))
			if img == "":
				img = str(CLASSES.get(m.get("cls", ""), {}).get("img", ""))
			var t = _tex(img)
			if t != null:
				tr.texture = t
			nl.text = "%s %d/%d" % [str(CHARS.get(cid, {}).get("name", str(m.get("cls", "")))), int(m.get("hp", 0)), int(m.get("maxhp", 0))]
		else:
			nl.text = "(пусто)"

func _actor(cls, col, cid = ""):
	var root = Node3D.new()
	add_child(root)
	var cdd = CLASSES.get(cls, {})
	var imgp = ""
	if cid != "":
		imgp = str(CHARS.get(cid, {}).get("img", ""))
	if imgp == "":
		imgp = str(cdd.get("img", ""))
	var t = _tex(imgp)
	var sc = float(cdd.get("scale", 1.0))
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
		mi.albedo_color = col
		cm.material = mi
		m.mesh = cm
		m.position = Vector3(0, 0.45, 0)
		root.add_child(m)
	var lb = Label3D.new()
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var nm = str(CHARS.get(cid, {}).get("name", "")) if cid != "" else ""
	if nm == "":
		nm = str(cdd.get("name", cls))
	lb.text = nm
	lb.pixel_size = 0.004
	lb.position = Vector3(0, 1.8 * sc + 0.3, 0)
	root.add_child(lb)
	return root

func _spawn_ground(g):
	var m = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.3, 0.2, 0.3)
	var mi = StandardMaterial3D.new()
	mi.albedo_color = Color(1, 0.85, 0.2)
	mi.emission_enabled = true
	mi.emission = Color(1, 0.85, 0.2)
	bm.material = mi
	m.mesh = bm
	var p = Vector3(float(g["pos"][0]), 0, float(g["pos"][1]))
	p.y = terrain.sample_h(p.x, p.z) if terrain != null else 0.0
	m.position = p + Vector3(0, 0.15, 0)
	add_child(m)
	ground.append({"root": m, "data": g})

func _spawn_npc(np):
	var cid = str(np.get("char", ""))
	var cd = CHARS.get(cid, {})
	var cc = np.get("cell", [2, 2])
	var c = Vector2i(int(cc[0]), int(cc[1]))
	var root = Node3D.new()
	root.position = Vector3(c.x + 0.5, 0, c.y + 0.5)
	root.position.y = terrain.sample_h(root.position.x, root.position.z) if terrain != null else 0.0
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
	if not (ev is InputEventMouseButton) or not ev.pressed or ev.button_index != MOUSE_BUTTON_LEFT:
		return
	if party_n.size() == 0:
		return
	var lead = party_n[0].root
	var npc_root = npcs3[i].root
	if (Vector2(lead.position.x, lead.position.z) - Vector2(npc_root.position.x, npc_root.position.z)).length() > 3.0:
		if hint != null:
			hint.text = "Слишком далеко от %s" % str(npcs3[i].cid)
		return
	var cid = npcs3[i]["cid"]
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
		_play_dlg(dn)

func _process(d):
	if party_n.size() == 0:
		return
	var lead = party_n[0].root
	var mv = Vector2()
	if Input.is_key_pressed(KEY_W):
		mv.y -= 1
	if Input.is_key_pressed(KEY_S):
		mv.y += 1
	if Input.is_key_pressed(KEY_A):
		mv.x -= 1
	if Input.is_key_pressed(KEY_D):
		mv.x += 1
	if mv.length() > 0:
		target_point = null
		mv = mv.normalized()
		var forward = Vector3(-sin(yaw), 0, -cos(yaw))
		var right = Vector3(cos(yaw), 0, -sin(yaw))
		var dir = (forward * (-mv.y) + right * mv.x).normalized()
		_try_move(lead, dir, speed * d)
		lead.rotation.y = atan2(dir.x, dir.z)
	elif target_point != null:
		var to = target_point - lead.position
		to.y = 0
		var dl = to.length()
		if dl < 0.1:
			target_point = null
		else:
			var dir = to.normalized()
			_try_move(lead, dir, min(dl, speed * d))
			lead.rotation.y = atan2(dir.x, dir.z)
	for k in range(1, party_n.size()):
		var prev = party_n[k - 1].root
		var cur = party_n[k].root
		var to2 = prev.position - cur.position
		to2.y = 0
		var dl2 = to2.length()
		if dl2 > 0.9:
			var dir2 = to2.normalized()
			var step = min(dl2 - 0.7, speed * d)
			if step > 0:
				_try_move(cur, dir2, step)
				cur.rotation.y = atan2(dir2.x, dir2.z)
	for pn in party_n:
		pn.root.position.y = terrain.sample_h(pn.root.position.x, pn.root.position.z) if terrain != null else 0.0
	if cam != null:
		yaw_n.position = Vector3(lead.position.x, 0, lead.position.z) + cam_offset
		yaw_n.rotation = Vector3(0, yaw, 0)
		pitch_n.rotation = Vector3(pitch, 0, 0)
		cam.position = Vector3(0, 0, cam_dist)
	if not combat_lock:
		for en in enemies:
			if (en.root.position - lead.position).length() < 1.4:
				combat_lock = true
				_try_combat()
				break

func _try_move(node, dir, step):
	var np = node.position + dir * step
	if terrain != null and not terrain.has_cell(int(np.x), int(np.z)):
		return
	if objects3.has(Vector2i(int(np.x), int(np.z))):
		return
	node.position = np
	node.position.x = clampf(node.position.x, 0.3, (terrain.GW if terrain != null else 8) - 0.3)
	node.position.z = clampf(node.position.z, 0.3, (terrain.GH if terrain != null else 6) - 0.3)

func _try_combat():
	if party_n.size() == 0:
		return
	if Game.flags.get("peace_" + loc_id, false) or Game.flags.get("paid_bandits", false):
		return
	var pre = str(LOCS.get(loc_id, {}).get("dlg", {}).get("pre", ""))
	if pre != "" and not pre_played:
		pre_played = true
		await _play_dlg(pre)
	_start_combat()

func _start_combat():
	var pts = []
	for pn in party_n:
		pts.append([pn.root.position.x, pn.root.position.z])
	for en in enemies:
		pts.append([en.root.position.x, en.root.position.z])
	var cells = ExploreTools.snap_to_cells(pts, _is_free_cell)
	var players = []
	for i in party_n.size():
		var m = party_n[i].m
		players.append({"cell": cells[i], "cls": str(m.get("cls", "swordsman")), "char": str(m.get("char", "")), "hp": int(m.get("hp", 2)), "maxhp": int(m.get("maxhp", 2))})
	var en = []
	for i in enemies.size():
		en.append(cells[party_n.size() + i])
	var p0 = [0, 0]
	if party_n.size() > 0:
		p0 = [int(party_n[0].root.position.x), int(party_n[0].root.position.z)]
	Game.explore_start = {"players": players, "enemies": en, "player": p0}
	var pp = []
	for pn in party_n:
		pp.append([str(pn.m.get("char", "")), pn.root.position.x, pn.root.position.z])
	Game.explore_return = {"loc": loc_id, "party_pos": pp}
	get_tree().change_scene_to_file("res://world3d.tscn")

func _is_free_cell(x, y):
	if terrain != null and not terrain.has_cell(x, y):
		return false
	if objects3.has(Vector2i(x, y)):
		return false
	return true

func _try_pick():
	if party_n.size() == 0:
		return
	var lp = party_n[0].root.position
	var ls = Game.loc_state_get(loc_id)
	var arr = ls.get("ground", [])
	for i in range(arr.size() - 1, -1, -1):
		var gg = arr[i]
		var gp = Vector3(float(gg["pos"][0]), 0, float(gg["pos"][1]))
		if (gp - lp).length() < 1.2:
			Game.add_item(str(gg.get("item", "")))
			arr.remove_at(i)
			if i < ground.size() and is_instance_valid(ground[i].root):
				ground[i].root.queue_free()
			ground.remove_at(i)
			if hint != null:
				hint.text = "Подобрано: %s" % str(gg.get("item", ""))
			Game.autosave()
			return

func _play_dlg(dn):
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
	add_child(d)
	await d.play(data)

func _unhandled_input(ev):
	if ev is InputEventKey and ev.pressed:
		if ev.keycode == KEY_M:
			get_tree().change_scene_to_file("res://overworld3d.tscn")
			return
		if ev.keycode == KEY_R:
			var c = load("res://scripts/camp_ui.gd").new()
			add_child(c)
			return
		if ev.keycode == KEY_P:
			var pu = load("res://scripts/party_ui.gd").new()
			add_child(pu)
			return
		if ev.keycode == KEY_I:
			var hub = load("res://scripts/game_hub.gd").new()
			add_child(hub)
			return
		if ev.keycode == KEY_E:
			_try_pick()
			return
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_RIGHT:
			right_drag = ev.pressed
		elif ev.button_index == MOUSE_BUTTON_MIDDLE:
			mid_drag = ev.pressed
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = clampf(cam_dist - 0.5, 2, 8)
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = clampf(cam_dist + 0.5, 2, 8)
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var p = _ray_ground(ev.position)
			if p != null:
				target_point = p
	elif ev is InputEventMouseMotion:
		if right_drag:
			yaw -= ev.relative.x * 0.005
			pitch = clampf(pitch - ev.relative.y * 0.005, -1.45, -0.15)
		elif mid_drag:
			var k = cam_dist * 0.0016
			var right = yaw_n.global_transform.basis.x
			var fwd = -yaw_n.global_transform.basis.z
			cam_offset -= right * ev.relative.x * k
			cam_offset += fwd * ev.relative.y * k

func _ray_ground(m):
	var c3 = get_viewport().get_camera_3d()
	if c3 == null:
		return null
	var from = c3.project_ray_origin(m)
	var dir = c3.project_ray_normal(m)
	if abs(dir.y) < 0.0001:
		return null
	var t = -from.y / dir.y
	if t < 0:
		return null
	var p = from + dir * t
	if terrain != null and not terrain.has_cell(int(p.x), int(p.z)):
		return null
	return p

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

func _mat_defs():
	var m = _lj("res://data/materials.json")
	var d = []
	for k in m:
		d.append({"col": Color(str(m[k].get("color", "#888888"))), "tex": str(m[k].get("tex", ""))})
	return d

func _obj(p, k):
	p.y = terrain.sample_h(p.x, p.z) if terrain != null else 0.0
	var od = OBJ3.get(k, {})
	var oimg = str(od.get("img", ""))
	var ot = _tex(oimg) if oimg != "" else null
	if ot != null:
		var h = 1.2 * float(od.get("scale", 1.0))
		var sp = Sprite3D.new()
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.pixel_size = h / float(ot.get_height())
		sp.texture = ot
		sp.position = p + Vector3(0, h * 0.5, 0)
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
