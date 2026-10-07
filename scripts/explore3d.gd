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
var current_path: Array = []
var hint: Label
var pre_played = false
var sun_light: DirectionalLight3D = null
var world_env: Environment = null
var combat_lock = false
var npcs3 = []
var fp_mode: bool = false
var prev_cam_dist: float = 4.0
var prev_pitch: float = -0.9
var prev_cam_offset: Vector3 = Vector3.ZERO
var crosshair: Control = null
var fp_cam_y: float = 0.0
var cam_tween: Tween = null
var lead_vy: float = 0.0
var lead_y_offset: float = 0.0
var is_grounded: bool = true
var jump_force: float = 5.2
var gravity: float = 16.0
var stamina: float = 100.0
var max_stamina: float = 100.0
var stamina_drain: float = 24.0
var stamina_jump_cost: float = 18.0
var stamina_recovery: float = 28.0
var stamina_cooldown: float = 0.0
var is_sprinting: bool = false
var stamina_bar: ProgressBar = null

func _ready():
	loc_id = Game.cur_loc
	CLASSES = DataLoader.load_json("res://data/classes.json")
	LOCS = DataLoader.load_json("res://data/locations.json")
	OBJ3 = DataLoader.load_json("res://data/objects.json")
	CHARS = DataLoader.load_json("res://data/chars.json")
	Game.ensure_party()
	var td = LOCS.get(loc_id, {}).get("terrain", {})
	terrain = load("res://scripts/terrain.gd").new(int(td.get("gw", 8)), int(td.get("gh", 6)), int(td.get("sub", 8)))
	add_child(terrain)
	terrain.set_materials(_mat_defs())
	if td.size() > 0:
		terrain.from_data(td)
	else:
		terrain.build()
	FogBorder.build_for_terrain(self, terrain, terrain.position if terrain != null else Vector3.ZERO)
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
	var ret = Game.explore_return
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
	sun_light = dl
	add_child(dl)
	var env = Environment.new()
	world_env = env
	DayNight.setup(env, dl, float(Game.hour))
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
	_update_hint()
	_party_bar(ui)
	_setup_stamina_bar(ui)
	_setup_crosshair(ui)

func _exit_tree():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _setup_stamina_bar(ui: Control):
	var cont = VBoxContainer.new()
	cont.name = "StaminaCont"
	cont.anchor_left = 0.5
	cont.anchor_right = 0.5
	cont.anchor_top = 1.0
	cont.anchor_bottom = 1.0
	cont.offset_left = -120
	cont.offset_right = 120
	cont.offset_top = -138
	cont.offset_bottom = -128
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cont.modulate.a = 0.0
	ui.add_child(cont)
	
	stamina_bar = ProgressBar.new()
	stamina_bar.custom_minimum_size = Vector2(240, 8)
	stamina_bar.show_percentage = false
	stamina_bar.max_value = max_stamina
	stamina_bar.value = stamina
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.1, 0.06, 0.85)
	bg_style.border_color = Color(0.2, 0.45, 0.22, 0.7)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(3)
	stamina_bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.22, 0.85, 0.35, 0.95)
	fill_style.set_corner_radius_all(3)
	stamina_bar.add_theme_stylebox_override("fill", fill_style)
	
	cont.add_child(stamina_bar)

func _try_jump():
	if party_n.size() == 0 or not is_grounded:
		return
	if stamina < stamina_jump_cost * 0.4:
		return
	lead_vy = jump_force
	is_grounded = false
	stamina = maxf(0.0, stamina - stamina_jump_cost)
	stamina_cooldown = 0.45

func _setup_crosshair(ui: Control):
	crosshair = CenterContainer.new()
	crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.visible = false
	ui.add_child(crosshair)
	var dot = ColorRect.new()
	dot.custom_minimum_size = Vector2(4, 4)
	dot.color = Color(1.0, 1.0, 1.0, 0.75)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.add_child(dot)

func _update_hint():
	if hint == null:
		return
	var is_town = str(LOCS.get(loc_id, {}).get("type", "")) == "town"
	var town_hint = " | N таверна" if is_town else ""
	if fp_mode:
		hint.text = "[1-е лицо] WASD идти | Shift бег | Пробел прыжок | Мышь обзор | V 3-е лицо | E действие | ESC курсор%s | M карта" % town_hint
	else:
		hint.text = "WASD/клик идти | Shift бег | Пробел прыжок | ПКМ камера | V 1-е лицо | E подобрать | R привал | P отряд%s | M карта" % town_hint

func _set_fp_mode(enabled: bool):
	if combat_lock:
		return
	fp_mode = enabled
	if cam_tween != null and cam_tween.is_valid():
		cam_tween.kill()
	
	if fp_mode:
		prev_cam_dist = cam_dist
		prev_pitch = pitch
		prev_cam_offset = cam_offset
		target_point = null
		current_path.clear()
		cam_offset = Vector3.ZERO
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
		cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		cam_tween.tween_property(self, "cam_dist", 0.0, 0.45)
		cam_tween.tween_property(self, "pitch", 0.0, 0.45)
		cam_tween.tween_property(self, "fp_cam_y", 1.4, 0.45)
		cam_tween.finished.connect(func():
			if fp_mode:
				if party_n.size() > 0 and is_instance_valid(party_n[0].root):
					party_n[0].root.visible = false
				if crosshair != null:
					crosshair.visible = true
		)
	else:
		if party_n.size() > 0 and is_instance_valid(party_n[0].root):
			party_n[0].root.visible = true
		if crosshair != null:
			crosshair.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
		var target_dist = prev_cam_dist if prev_cam_dist > 1.5 else 4.0
		var target_pitch = prev_pitch if prev_pitch < -0.1 else -0.9
		
		cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		cam_tween.tween_property(self, "cam_dist", target_dist, 0.45)
		cam_tween.tween_property(self, "pitch", target_pitch, 0.45)
		cam_tween.tween_property(self, "fp_cam_y", 0.0, 0.45)
	_update_hint()

func _flyout_to_third_person():
	if not fp_mode and fp_cam_y <= 0.05 and cam_dist >= 2.0:
		return
	fp_mode = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if crosshair != null:
		crosshair.visible = false
	if party_n.size() > 0 and is_instance_valid(party_n[0].root):
		party_n[0].root.visible = true
	_update_hint()
	
	if cam_tween != null and cam_tween.is_valid():
		cam_tween.kill()
		
	var target_dist = 8.5
	var target_pitch = -0.85
	
	cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	cam_tween.tween_property(self, "cam_dist", target_dist, 0.75)
	cam_tween.tween_property(self, "pitch", target_pitch, 0.75)
	cam_tween.tween_property(self, "fp_cam_y", 0.0, 0.75)
	await cam_tween.finished

func _party_bar(ui):
	var bar = HBoxContainer.new()
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -330
	bar.offset_right = 330
	bar.offset_top = -120
	bar.offset_bottom = -10
	bar.add_theme_constant_override("separation", 8)
	ui.add_child(bar)
	for i in 6:
		var slot = PanelContainer.new()
		slot.custom_minimum_size = Vector2(96, 110)
		
		# Copper rounded border style
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.07, 0.08, 0.10, 0.92)
		style.border_color = Color(0.78, 0.48, 0.22, 1.0) # Copper / bronze
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		style.content_margin_left = 2
		style.content_margin_top = 2
		style.content_margin_right = 2
		style.content_margin_bottom = 2
		slot.add_theme_stylebox_override("panel", style)
		
		var slot_box = VBoxContainer.new()
		slot_box.add_theme_constant_override("separation", 2)
		slot.add_child(slot_box)
		
		# Portrait image area with relative overlays (HP text, name)
		var img_cont = Control.new()
		img_cont.custom_minimum_size = Vector2(92, 82)
		img_cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		img_cont.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slot_box.add_child(img_cont)
		
		var tr = TextureRect.new()
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img_cont.add_child(tr)
		
		# Name overlay (top-left or bottom)
		var nl = Label.new()
		nl.anchor_top = 0.0
		nl.anchor_bottom = 0.0
		nl.offset_left = 4
		nl.offset_top = 2
		nl.add_theme_font_size_override("font_size", 11)
		nl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		nl.add_theme_constant_override("shadow_offset_x", 1)
		nl.add_theme_constant_override("shadow_offset_y", 1)
		img_cont.add_child(nl)
		
		# Numbers in bottom right corner (e.g. "9 / 9")
		var num_lbl = Label.new()
		num_lbl.anchor_left = 1.0
		num_lbl.anchor_right = 1.0
		num_lbl.anchor_top = 1.0
		num_lbl.anchor_bottom = 1.0
		num_lbl.offset_left = -66
		num_lbl.offset_top = -20
		num_lbl.offset_right = -4
		num_lbl.offset_bottom = -2
		num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		num_lbl.add_theme_font_size_override("font_size", 12)
		num_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
		num_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		num_lbl.add_theme_constant_override("shadow_offset_x", 1)
		num_lbl.add_theme_constant_override("shadow_offset_y", 1)
		img_cont.add_child(num_lbl)
		
		# Red HP bar at the bottom
		var hp_bar = ProgressBar.new()
		hp_bar.custom_minimum_size = Vector2(92, 10)
		hp_bar.show_percentage = false
		
		var hp_bg = StyleBoxFlat.new()
		hp_bg.bg_color = Color(0.2, 0.05, 0.05, 1.0) # dark blood background
		hp_bg.set_corner_radius_all(2)
		hp_bar.add_theme_stylebox_override("background", hp_bg)
		
		var hp_fill = StyleBoxFlat.new()
		hp_fill.bg_color = Color(0.88, 0.12, 0.12, 1.0) # Bright red
		hp_fill.set_corner_radius_all(2)
		hp_bar.add_theme_stylebox_override("fill", hp_fill)
		
		slot_box.add_child(hp_bar)
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
			var cur_hp = int(m.get("hp", 0))
			var max_hp = maxi(1, int(m.get("maxhp", 1)))
			nl.text = str(CHARS.get(cid, {}).get("name", str(m.get("cls", ""))))
			num_lbl.text = "%d / %d" % [cur_hp, max_hp]
			hp_bar.max_value = max_hp
			hp_bar.value = cur_hp
		else:
			nl.text = "(пусто)"
			num_lbl.text = ""
			hp_bar.visible = false
			style.border_color = Color(0.35, 0.35, 0.35, 0.4)

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
		sp.material_override = DayNight.get_actor_material(t)
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
		sp.material_override = DayNight.get_actor_material(t)
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
	if fp_mode:
		return
	_interact_npc(i)

func _interact_npc(i: int):
	if party_n.size() == 0 or i < 0 or i >= npcs3.size():
		return
	var lead = party_n[0].root
	var npc_root = npcs3[i].root
	if (Vector2(lead.position.x, lead.position.z) - Vector2(npc_root.position.x, npc_root.position.z)).length() > 3.0:
		if hint != null:
			hint.text = "Слишком далеко от %s" % str(npcs3[i].cid)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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

func _interact_ahead():
	if _try_pick():
		return
	if party_n.size() == 0:
		return
	var lead = party_n[0].root
	var best_i = -1
	var min_dist = 3.0
	for i in npcs3.size():
		var nr = npcs3[i].root
		var d = (lead.position - nr.position).length()
		if d < min_dist:
			var to_npc = (nr.position - lead.position).normalized()
			var fwd = Vector3(-sin(yaw), 0, -cos(yaw))
			if fwd.dot(to_npc) > 0.2:
				min_dist = d
				best_i = i
	if best_i >= 0:
		_interact_npc(best_i)

func _process(d):
	DayNight.update(d, float(Game.hour), world_env, sun_light)
	if party_n.size() == 0:
		return
	var lead = party_n[0].root

	# Vertical physics (Jump & Gravity)
	if not is_grounded:
		lead_vy -= gravity * d
		lead_y_offset += lead_vy * d
		if lead_y_offset <= 0.0:
			lead_y_offset = 0.0
			lead_vy = 0.0
			is_grounded = true

	var mv = Vector2()
	if not combat_lock:
		if Input.is_key_pressed(KEY_W):
			mv.y -= 1
		if Input.is_key_pressed(KEY_S):
			mv.y += 1
		if Input.is_key_pressed(KEY_A):
			mv.x -= 1
		if Input.is_key_pressed(KEY_D):
			mv.x += 1

	var wants_sprint = Input.is_key_pressed(KEY_SHIFT) and not combat_lock
	var is_moving = (mv.length() > 0 or current_path.size() > 0 or target_point != null) and not combat_lock
	is_sprinting = wants_sprint and is_moving and stamina > 2.0
	
	var cur_speed = speed
	if is_sprinting:
		cur_speed = 6.2
		stamina = maxf(0.0, stamina - stamina_drain * d)
		stamina_cooldown = 0.4
	else:
		cur_speed = 3.2
		if stamina_cooldown > 0.0:
			stamina_cooldown = maxf(0.0, stamina_cooldown - d)
		elif stamina < max_stamina:
			stamina = minf(max_stamina, stamina + stamina_recovery * d)

	if stamina_bar != null:
		stamina_bar.value = stamina
		var parent_c = stamina_bar.get_parent() as Control
		if parent_c != null:
			var target_alpha = 0.0 if (stamina >= max_stamina - 0.5 and not wants_sprint) else 1.0
			parent_c.modulate.a = move_toward(parent_c.modulate.a, target_alpha, d * 3.5)

	if not combat_lock and mv.length() > 0:
		target_point = null
		current_path.clear()
		mv = mv.normalized()
		var forward = Vector3(-sin(yaw), 0, -cos(yaw))
		var right = Vector3(cos(yaw), 0, -sin(yaw))
		var dir = (forward * (-mv.y) + right * mv.x).normalized()
		_try_move(lead, dir, cur_speed * d)
		if not fp_mode:
			lead.rotation.y = atan2(dir.x, dir.z)
	elif not combat_lock and (current_path.size() > 0 or target_point != null):
		var target_pos = target_point
		if current_path.size() > 0:
			var wp = current_path[0]
			target_pos = Vector3(float(wp.x) + 0.5, 0, float(wp.y) + 0.5)
			if current_path.size() == 1 and target_point != null:
				target_pos = target_point
		var to = target_pos - lead.position
		to.y = 0
		var dl = to.length()
		if dl < 0.2:
			if current_path.size() > 0:
				current_path.pop_front()
				if current_path.is_empty():
					target_point = null
			else:
				target_point = null
		else:
			var dir = to.normalized()
			_try_move(lead, dir, min(dl, cur_speed * d))
			lead.rotation.y = atan2(dir.x, dir.z)
	for k in range(1, party_n.size()):
		var prev = party_n[k - 1].root
		var cur = party_n[k].root
		var to2 = prev.position - cur.position
		to2.y = 0
		var dl2 = to2.length()
		if dl2 > 0.9:
			var dir2 = to2.normalized()
			var step = min(dl2 - 0.7, maxf(cur_speed * 1.15, 3.8) * d)
			if step > 0:
				_try_move(cur, dir2, step)
				cur.rotation.y = atan2(dir2.x, dir2.z)
	var ground_h = terrain.sample_h(lead.position.x, lead.position.z) if terrain != null else 0.0
	lead.position.y = ground_h + lead_y_offset
	for k in range(1, party_n.size()):
		var pn = party_n[k]
		pn.root.position.y = terrain.sample_h(pn.root.position.x, pn.root.position.z) if terrain != null else 0.0
	if cam != null:
		if fp_mode:
			lead.rotation.y = yaw
		yaw_n.position = lead.position + Vector3(0, fp_cam_y, 0) + cam_offset
		yaw_n.rotation = Vector3(0, yaw, 0)
		pitch_n.rotation = Vector3(pitch, 0, 0)
		cam.position = Vector3(0, 0, cam_dist)
	if not combat_lock:
		for en in enemies:
			if (en.root.position - lead.position).length() < 1.4:
				combat_lock = true
				_try_combat()
				break

func _can_occupy(pos: Vector3) -> bool:
	var cx = int(floor(pos.x))
	var cz = int(floor(pos.z))
	if terrain != null and not terrain.has_cell(cx, cz):
		return false
	if objects3.has(Vector2i(cx, cz)):
		return false
	return true

func _try_move(node, dir, step):
	var np = node.position + dir * step
	var gw = (terrain.GW if terrain != null else 8)
	var gh = (terrain.GH if terrain != null else 6)
	np.x = clampf(np.x, 0.3, gw - 0.3)
	np.z = clampf(np.z, 0.3, gh - 0.3)
	
	if _can_occupy(np):
		node.position = np
		return
	
	# Sliding attempt along X
	var npx = Vector3(np.x, node.position.y, node.position.z)
	if _can_occupy(npx):
		node.position = npx
		return
		
	# Sliding attempt along Z
	var npz = Vector3(node.position.x, node.position.y, np.z)
	if _can_occupy(npz):
		node.position = npz
		return

func _try_combat():
	if party_n.size() == 0:
		return
	if Game.flags.get("peace_" + loc_id, false) or Game.flags.get("paid_bandits_" + loc_id, false):
		return
	if fp_mode or fp_cam_y > 0.1 or cam_dist < 2.5:
		await _flyout_to_third_person()
	var pre = str(LOCS.get(loc_id, {}).get("dlg", {}).get("pre", ""))
	if pre != "" and not pre_played:
		pre_played = true
		await _play_dlg(pre)
		if Game.flags.get("peace_" + loc_id, false) or Game.flags.get("paid_bandits_" + loc_id, false):
			return
	_start_combat()

func _start_combat():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	Game.explore_start = {
		"players": players,
		"enemies": en,
		"player": p0,
		"cam_yaw": yaw,
		"cam_pitch": pitch,
		"cam_dist": maxf(cam_dist, 8.5)
	}
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

func _find_path(from: Vector2i, to: Vector2i) -> Array:
	if from == to:
		return [to]
	var gw = terrain.GW if terrain != null else 8
	var gh = terrain.GH if terrain != null else 6
	var visited = {from: true}
	var parent = {}
	var q: Array = [from]
	var found = false
	while q.size() > 0:
		var cur = q.pop_front()
		if cur == to:
			found = true
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt = cur + d
			if nxt.x < 0 or nxt.y < 0 or nxt.x >= gw or nxt.y >= gh:
				continue
			if visited.has(nxt):
				continue
			if not _is_free_cell(nxt.x, nxt.y):
				continue
			visited[nxt] = true
			parent[nxt] = cur
			q.append(nxt)
	if not found:
		return []
	var path: Array = []
	var curr = to
	while curr != from:
		path.append(curr)
		curr = parent[curr]
	path.reverse()
	return path

func _try_pick() -> bool:
	if party_n.size() == 0:
		return false
	var lp = party_n[0].root.position
	var ls = Game.loc_state_get(loc_id)
	var arr = ls.get("ground", [])
	for i in range(arr.size() - 1, -1, -1):
		var gg = arr[i]
		var gp = Vector3(float(gg["pos"][0]), 0, float(gg["pos"][1]))
		if (gp - lp).length() < 1.4:
			Game.add_item(str(gg.get("item", "")))
			arr.remove_at(i)
			if i < ground.size() and is_instance_valid(ground[i].root):
				ground[i].root.queue_free()
			ground.remove_at(i)
			if hint != null:
				hint.text = "Подобрано: %s" % str(gg.get("item", ""))
			Game.autosave()
			return true
	return false

func _play_dlg(dn):
	if dn == "":
		return
	var data = DataLoader.load_json("res://data/dialogs/%s.json" % dn, {})
	if data.is_empty():
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var d = load("res://scripts/dialog.gd").new()
	d.chars = CHARS
	add_child(d)
	await d.play(data)
	if fp_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(ev):
	if combat_lock:
		return
	if ev is InputEventKey and ev.pressed:
		if ev.keycode == KEY_V:
			_set_fp_mode(not fp_mode)
			return
		if ev.keycode == KEY_ESCAPE:
			if fp_mode and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				return
		if ev.keycode == KEY_M:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			Game.clear_transient_state()
			get_tree().change_scene_to_file("res://overworld3d.tscn")
			return
		if ev.keycode == KEY_R:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			var c = load("res://scripts/camp_ui.gd").new()
			add_child(c)
			return
		if ev.keycode == KEY_P:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			var pu = load("res://scripts/party_ui.gd").new()
			add_child(pu)
			return
		if ev.keycode == KEY_N and str(LOCS.get(loc_id, {}).get("type", "")) == "town":
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			var tv = load("res://scripts/tavern.gd").new()
			add_child(tv)
			return
		if ev.keycode == KEY_I:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			var hub = load("res://scripts/game_hub.gd").new()
			add_child(hub)
			return
		if ev.keycode == KEY_SPACE:
			_try_jump()
			return
		if ev.keycode == KEY_E:
			if fp_mode:
				_interact_ahead()
			else:
				_try_pick()
			return
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_RIGHT:
			if not fp_mode:
				right_drag = ev.pressed
		elif ev.button_index == MOUSE_BUTTON_MIDDLE:
			if not fp_mode:
				mid_drag = ev.pressed
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			if not fp_mode:
				cam_dist = clampf(cam_dist - 0.5, 2, 8)
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if not fp_mode:
				cam_dist = clampf(cam_dist + 0.5, 2, 8)
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if fp_mode:
				if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				else:
					_interact_ahead()
				return
			var p = _ray_ground(ev.position)
			if p != null and party_n.size() > 0:
				var lead = party_n[0].root
				var from_c = Vector2i(int(floor(lead.position.x)), int(floor(lead.position.z)))
				var to_c = Vector2i(int(floor(p.x)), int(floor(p.z)))
				
				# If destination is obstacle, try adjacent free cell
				var dest_c = to_c
				if not _is_free_cell(dest_c.x, dest_c.y):
					var best_adj = null
					var min_ad = 9999.0
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
						var adj = to_c + d
						if _is_free_cell(adj.x, adj.y):
							var ddist = Vector2(adj.x + 0.5 - p.x, adj.y + 0.5 - p.z).length()
							if ddist < min_ad:
								min_ad = ddist
								best_adj = adj
					if best_adj != null:
						dest_c = best_adj
				
				var path = _find_path(from_c, dest_c)
				if path.size() > 0 or from_c == dest_c:
					current_path = path
					target_point = p
				else:
					target_point = null
					current_path.clear()
					if hint != null:
						hint.text = "Сюда нельзя добраться!"
	elif ev is InputEventMouseMotion:
		if fp_mode and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			yaw -= ev.relative.x * 0.003
			pitch = clampf(pitch - ev.relative.y * 0.003, -1.4, 1.4)
		elif right_drag:
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

func _tex(path):
	if path == "" or not FileAccess.file_exists(path):
		return null
	var im = Image.new()
	if im.load(path) != OK:
		return null
	return ImageTexture.create_from_image(im)

func _mat_defs():
	var m = DataLoader.load_json("res://data/materials.json")
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
		sp.material_override = DayNight.get_tree_material(ot)
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

func _apply_graphics_settings():
	FogBorder.build_for_terrain(self, terrain, terrain.position if terrain != null else Vector3.ZERO)
	DayNight.setup(world_env, sun_light, float(Game.hour))

