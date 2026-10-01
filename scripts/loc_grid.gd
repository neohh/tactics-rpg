extends Control
const GW = 8
const GH = 6
var loc = {}:
	set(v):
		loc = v
		if content != null:
			rebuild()
var mode = "obj"
var tool = "place"
var obj_kind = "rock"
var cls = "swordsman"
var paint_mat = 0
var brush_radius = 1.5
var strength = 0.06
var CLASSES = {}
var OBJ3 = {}
signal changed
var svc: SubViewportContainer
var sv: SubViewport
var world: Node3D
var content: Node3D
var terr = null
var yaw_n: Node3D
var pitch_n: Node3D
var cam: Camera3D
var yaw = 0.6
var pitch = -0.9
var dist = 9.0
var target = Vector3(4, 0, 3)
var mid_drag = false
var right_drag = false
var sculpt_btn = ""
var brush_ind = null
var ind_alpha = 0.07
func _ready():
	CLASSES = DataLoader.load_json("res://data/classes.json")
	OBJ3 = DataLoader.load_json("res://data/objects.json")
	svc = SubViewportContainer.new()
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	add_child(svc)
	sv = SubViewport.new()
	sv.size = Vector2i(800, 500)
	svc.add_child(sv)
	world = Node3D.new()
	sv.add_child(world)
	yaw_n = Node3D.new()
	world.add_child(yaw_n)
	pitch_n = Node3D.new()
	yaw_n.add_child(pitch_n)
	cam = Camera3D.new()
	pitch_n.add_child(cam)
	cam.position = Vector3(0, 0, dist)
	var dl = DirectionalLight3D.new()
	dl.rotation_degrees = Vector3(-50, 30, 0)
	world.add_child(dl)
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.08)
	var we = WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	content = Node3D.new()
	world.add_child(content)
	svc.gui_input.connect(_on_gui)
	rebuild()
	_apply()
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
func refresh3d():
	rebuild()
func flash():
	ind_alpha = 0.3
	if brush_ind != null:
		brush_ind.mesh.material.albedo_color = Color(1, 1, 1, ind_alpha)
func rebuild():
	if content == null:
		return
	for c in content.get_children():
		c.queue_free()
	if brush_ind != null:
		brush_ind.queue_free()
		brush_ind = null
	terr = load("res://scripts/terrain.gd").new()
	content.add_child(terr)
	terr.set_materials(_mat_defs())
	var td = loc.get("terrain", {})
	if td.size() > 0:
		terr.from_data(td)
	else:
		terr.build()
	var m = loc.get("map", {})
	for o in m.get("objects", []):
		_obj3(Vector3(o["cell"][0] + 0.5, 0, o["cell"][1] + 0.5), o.get("k", "rock"))
	for r in m.get("rocks", []):
		_obj3(Vector3(r[0] + 0.5, 0, r[1] + 0.5), "rock")
	for u in m.get("units", []):
		_unit3(Vector3(u["cell"][0] + 0.5, 0, u["cell"][1] + 0.5), int(u.get("team", 1)), u.get("cls", "swordsman"))
	if tool == "sculpt":
		_make_ind()
func _make_ind():
	if brush_ind != null:
		brush_ind.queue_free()
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
	content.add_child(brush_ind)
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
func _unit3(p, team, cid):
	var cd = CLASSES.get(cid, {})
	var sc = float(cd.get("scale", 1.0))
	var tcol = Color(0.2, 0.5, 0.9) if team == 0 else Color(0.9, 0.25, 0.25)
	p.y = terr.sample_h(p.x, p.z) if terr != null else 0.0
	var img = cd.get("img", "")
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
	lb.text = str(cd.get("name", cid))
	lb.pixel_size = 0.004
	lb.position = p + Vector3(0, 1.8 * sc, 0)
	lb.modulate = Color(1, 1, 1) if team == 0 else Color(1, 0.6, 0.6)
	content.add_child(lb)
func _sync_terrain():
	loc["terrain"] = terr.to_data()
	changed.emit()
func _apply():
	yaw_n.position = target
	yaw_n.rotation = Vector3(0, yaw, 0)
	pitch_n.rotation = Vector3(pitch, 0, 0)
	cam.position = Vector3(0, 0, dist)
func _on_gui(ev):
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			dist = clampf(dist - 1.0, 4, 20)
			_apply()
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			dist = clampf(dist + 1.0, 4, 20)
			_apply()
		elif ev.button_index == MOUSE_BUTTON_MIDDLE:
			mid_drag = ev.pressed
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			if tool == "sculpt" and ev.pressed and ev.shift_pressed:
				sculpt_btn = "smooth"
				terr.push_undo()
				_brush_at(ev.position, "smooth")
			elif tool == "sculpt" and not ev.pressed and sculpt_btn == "smooth":
				sculpt_btn = ""
				_sync_terrain()
			else:
				right_drag = ev.pressed
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				if tool == "sculpt":
					sculpt_btn = "lower" if ev.ctrl_pressed else "raise"
					terr.push_undo()
					_brush_at(ev.position, sculpt_btn)
				elif tool == "paint":
					var c = _pick(ev.position)
					if c != null:
						terr.paint_at(c.x + 0.5, c.y + 0.5, brush_radius, paint_mat)
						_sync_terrain()
				else:
					var c2 = _pick(ev.position)
					if c2 == null:
						return
					var m = loc.get("map", {})
					if m.is_empty():
						m = {"rocks": [], "objects": [], "units": []}
						loc["map"] = m
					_erase(m, c2.x, c2.y)
					if tool == "place":
						if mode == "obj":
							m["objects"].append({"cell": [c2.x, c2.y], "k": obj_kind})
						elif mode == "mine" or mode == "enemy":
							m["units"].append({"cls": cls, "team": 0 if mode == "mine" else 1, "cell": [c2.x, c2.y]})
					changed.emit()
					rebuild()
			else:
				if sculpt_btn != "":
					sculpt_btn = ""
					_sync_terrain()
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
		elif tool == "paint" and ev.button_mask & MOUSE_BUTTON_MASK_LEFT:
			var c = _pick(ev.position)
			if c != null:
				terr.paint_at(c.x + 0.5, c.y + 0.5, brush_radius, paint_mat)
				_sync_terrain()
		if tool == "sculpt" and brush_ind != null:
			_move_ind(ev.position)
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
	if Vector2(sv.size) != svc.size:
		sv.size = svc.size
	var from = cam.project_ray_origin(mp)
	var dir = cam.project_ray_normal(mp)
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
	if cx < 0 or cz < 0 or cx >= GW or cz >= GH:
		return null
	return Vector2i(cx, cz)
func _erase(m, x, y):
	var no = []
	for o in m.get("objects", []):
		if o["cell"] != [x, y]:
			no.append(o)
	m["objects"] = no
	var nr = []
	for r in m.get("rocks", []):
		if r != [x, y]:
			nr.append(r)
	m["rocks"] = nr
	var nu = []
	for u in m.get("units", []):
		if u["cell"] != [x, y]:
			nu.append(u)
	m["units"] = nu

func _model_inst(path):
	if path == "" or not FileAccess.file_exists(path):
		return null
	var res = load(path)
	if res is PackedScene:
		return res.instantiate()
	return null
