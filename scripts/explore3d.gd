extends Node3D
const CliffBridge = preload("res://scripts/cliff_bridge.gd")
const FPMeleeClass = preload("res://scripts/fp_melee.gd")
var fp_melee = null
var rt_combat_active: bool = false
var party_hp_bars: Array = []
var party_hp_lbls: Array = []
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
var is_defeated: bool = false
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
var lead_base_y: float = 0.0
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
var parry_hud: Control = null
var parry_progress_bar: ProgressBar = null
var parry_prompt_lbl: Label = null
var parry_zone_rect: ColorRect = null
var test_hud: PanelContainer = null
var test_hud_lbl: Label = null
var screen_shake_amt: float = 0.0
var screen_shake_timer: float = 0.0
const ENEMY_WINDUP_TOTAL: float = 0.75
var airship: Node3D = null
var airship_state: int = 0
var deck_local_pos: Vector3 = Vector3.ZERO
var rt_projectiles: Array = []
var test_classes: Array = ["swordsman", "halberd", "archer", "assassin", "mage"]
var class_names_ru: Dictionary = {
	"swordsman": "Мечник (Щит/Блок)",
	"halberd": "Алебардист (Неблокируемый размах)",
	"archer": "Лучник (Стрелы/Перезарядка)",
	"assassin": "Убийца (Скорость/Серии)",
	"mage": "Маг (Огненный шар/Каст)"
}
var test_spawn_class_idx: int = 0
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_duration: float = 0.26
var dash_dir: Vector3 = Vector3.ZERO
var dash_cooldown: float = 0.0
var dash_iframe_timer: float = 0.0

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
	if (loc_id == "bandit_road" or loc_id == "road_bandits"):
		CliffBridge.build_3d(self, terrain)
		if airship == null:
			_spawn_airship(13.5, 8.5)
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
		if (loc_id == "bandit_road" or loc_id == "road_bandits"):
			root.position.y = CliffBridge.get_surface_y(root.position.x, root.position.z, root.position.y, terrain)
		party_n.append({"root": root, "m": m, "base_y": root.position.y})
		if i == 0:
			lead_base_y = root.position.y
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
	_setup_parry_hud(ui)
	_setup_test_hud(ui)
	
	Game.combat_mode_changed.connect(_on_combat_mode_changed)
	if not Game.test_combat_options_changed.is_connected(_update_test_hud):
		Game.test_combat_options_changed.connect(_update_test_hud)
	if Game.combat_mode == Game.CombatMode.REALTIME_FP:
		_set_fp_mode(true)
		_ensure_fp_melee()
		if fp_melee != null:
			fp_melee.visible = true

func _exit_tree():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Game.combat_mode_changed.is_connected(_on_combat_mode_changed):
		Game.combat_mode_changed.disconnect(_on_combat_mode_changed)
	if Game.test_combat_options_changed.is_connected(_update_test_hud):
		Game.test_combat_options_changed.disconnect(_update_test_hud)

func _on_combat_mode_changed(new_mode: int):
	if new_mode == Game.CombatMode.REALTIME_FP:
		_set_fp_mode(true)
		_ensure_fp_melee()
		if fp_melee != null:
			fp_melee.visible = true
	else:
		if fp_melee != null and not rt_combat_active:
			fp_melee.visible = false
	_update_hint()

func _ensure_fp_melee():
	if cam == null:
		return
	if fp_melee == null or not is_instance_valid(fp_melee):
		fp_melee = FPMeleeClass.new()
		cam.add_child(fp_melee)
		fp_melee.attack_hit.connect(_on_rt_player_attack_hit)
		fp_melee.kick_hit.connect(_on_rt_player_kick_hit)
		fp_melee.parry_success.connect(_on_rt_player_parry)
		fp_melee.block_hit.connect(_on_rt_player_block)

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
	if is_defeated or party_n.size() == 0 or not is_grounded or airship_state == 2:
		return
	if int(party_n[0].m.get("hp", 0)) <= 0:
		return
	if stamina < stamina_jump_cost * 0.4:
		return
	lead_vy = jump_force
	is_grounded = false
	stamina = maxf(0.0, stamina - stamina_jump_cost)
	stamina_cooldown = 0.45

func is_hero_invulnerable() -> bool:
	return Game.test_player_godmode or dash_iframe_timer > 0.0

func _try_dash():
	if is_defeated or party_n.size() == 0 or airship_state == 2:
		return
	if int(party_n[0].m.get("hp", 0)) <= 0:
		return
	if is_dashing or dash_cooldown > 0.0:
		return
	if not Game.test_player_godmode and stamina < 10.0:
		if hint != null:
			hint.text = "Недостаточно выносливости для рывка!"
		return
	
	if not Game.test_player_godmode:
		stamina = maxf(0.0, stamina - 16.0)
		stamina_cooldown = 0.5
	
	dash_cooldown = 0.35
	dash_duration = 0.26
	dash_timer = dash_duration
	dash_iframe_timer = 0.30
	is_dashing = true
	
	var forward = Vector3(-sin(yaw), 0, -cos(yaw))
	var right = Vector3(cos(yaw), 0, -sin(yaw))
	
	var mv = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		mv.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		mv.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		mv.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		mv.x += 1
	
	if mv.length_squared() > 0.01:
		mv = mv.normalized()
		dash_dir = (forward * (-mv.y) + right * mv.x).normalized()
	else:
		# If no WASD / arrows pressed, dash backwards!
		dash_dir = -forward
	
	var lead = party_n[0].root
	if not fp_mode:
		lead.rotation.y = atan2(dash_dir.x, dash_dir.z)
	
	# Camera dynamic FOV pulse
	if cam != null:
		var tw = create_tween()
		tw.tween_property(cam, "fov", 80.0, 0.08)
		tw.tween_property(cam, "fov", 75.0, 0.18)
	
	# Weapon viewmodel recoil during dash
	if fp_melee != null and is_instance_valid(fp_melee.weapon_node):
		var tw_wp = create_tween()
		tw_wp.tween_property(fp_melee.weapon_node, "position:z", fp_melee.rest_pos.z + 0.12, 0.08)
		tw_wp.tween_property(fp_melee.weapon_node, "position:z", fp_melee.rest_pos.z, 0.18)
	
	_screen_shake(0.025, 0.1)
	_float_text(lead.position, "💨 РЫВОК (УВОРОТ)!", Color(0.4, 0.9, 1.0))


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

func _screen_shake(amt: float, dur: float):
	screen_shake_amt = amt
	screen_shake_timer = dur

func _update_screen_shake(d: float):
	if cam == null:
		return
	if screen_shake_timer > 0.0:
		screen_shake_timer -= d
		cam.h_offset = randf_range(-screen_shake_amt, screen_shake_amt)
		cam.v_offset = randf_range(-screen_shake_amt, screen_shake_amt)
		if screen_shake_timer <= 0.0:
			cam.h_offset = 0.0
			cam.v_offset = 0.0

func _setup_parry_hud(ui: Control):
	parry_hud = Control.new()
	parry_hud.name = "ParryHUD"
	parry_hud.anchor_left = 0.5
	parry_hud.anchor_right = 0.5
	parry_hud.anchor_top = 0.5
	parry_hud.anchor_bottom = 0.5
	parry_hud.offset_left = -160
	parry_hud.offset_right = 160
	parry_hud.offset_top = 65
	parry_hud.offset_bottom = 125
	parry_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parry_hud.modulate.a = 0.0
	ui.add_child(parry_hud)

	var vb = VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 4)
	parry_hud.add_child(vb)

	parry_prompt_lbl = Label.new()
	parry_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parry_prompt_lbl.text = "⚠️ ВРАГ АТАКУЕТ!"
	parry_prompt_lbl.add_theme_font_size_override("font_size", 14)
	parry_prompt_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	parry_prompt_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	parry_prompt_lbl.add_theme_constant_override("shadow_offset_x", 1)
	parry_prompt_lbl.add_theme_constant_override("shadow_offset_y", 1)
	vb.add_child(parry_prompt_lbl)

	var bar_cont = Control.new()
	bar_cont.custom_minimum_size = Vector2(320, 20)
	vb.add_child(bar_cont)

	var track = Panel.new()
	track.set_anchors_preset(Control.PRESET_FULL_RECT)
	var track_style = StyleBoxFlat.new()
	track_style.bg_color = Color(0.08, 0.09, 0.12, 0.9)
	track_style.border_color = Color(0.5, 0.45, 0.35, 0.9)
	track_style.set_border_width_all(2)
	track_style.set_corner_radius_all(5)
	track.add_theme_stylebox_override("panel", track_style)
	bar_cont.add_child(track)

	parry_zone_rect = ColorRect.new()
	parry_zone_rect.anchor_left = 0.50
	parry_zone_rect.anchor_right = 1.0
	parry_zone_rect.anchor_top = 0.0
	parry_zone_rect.anchor_bottom = 1.0
	parry_zone_rect.color = Color(0.2, 0.85, 0.4, 0.45)
	bar_cont.add_child(parry_zone_rect)

	var zone_lbl = Label.new()
	zone_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	zone_lbl.anchor_left = 0.50
	zone_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	zone_lbl.text = "ПАРИРОВАНИЕ [ПКМ]"
	zone_lbl.add_theme_font_size_override("font_size", 10)
	zone_lbl.add_theme_color_override("font_color", Color(0.65, 1.0, 0.75))
	bar_cont.add_child(zone_lbl)

	parry_progress_bar = ProgressBar.new()
	parry_progress_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	parry_progress_bar.show_percentage = false
	parry_progress_bar.max_value = 1.0
	parry_progress_bar.value = 0.0
	
	var pb_bg = StyleBoxEmpty.new()
	parry_progress_bar.add_theme_stylebox_override("background", pb_bg)
	
	var pb_fill = StyleBoxFlat.new()
	pb_fill.bg_color = Color(1.0, 0.5, 0.2, 0.9)
	pb_fill.set_corner_radius_all(3)
	parry_progress_bar.add_theme_stylebox_override("fill", pb_fill)
	bar_cont.add_child(parry_progress_bar)

func _setup_test_hud(ui: Control):
	test_hud = PanelContainer.new()
	test_hud.name = "TestCombatHUD"
	test_hud.set_anchors_preset(Control.PRESET_CENTER_TOP)
	test_hud.offset_top = 8
	test_hud.offset_left = -340
	test_hud.offset_right = 340
	test_hud.offset_bottom = 42
	test_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.1, 0.90)
	sb.border_color = Color(0.95, 0.6, 0.2, 0.95)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	test_hud.add_theme_stylebox_override("panel", sb)
	
	test_hud_lbl = Label.new()
	test_hud_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	test_hud_lbl.add_theme_font_size_override("font_size", 12)
	test_hud_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75))
	test_hud_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	test_hud_lbl.add_theme_constant_override("shadow_offset_x", 1)
	test_hud_lbl.add_theme_constant_override("shadow_offset_y", 1)
	test_hud.add_child(test_hud_lbl)
	ui.add_child(test_hud)
	
	_update_test_hud()

func _update_test_hud():
	if test_hud == null or not is_instance_valid(test_hud) or test_hud_lbl == null:
		return
	if not Game.is_combat_test:
		test_hud.visible = false
		return
	test_hud.visible = true
	var next_cls = test_classes[test_spawn_class_idx % test_classes.size()]
	var next_name = class_names_ru.get(next_cls, next_cls)
	var p_god = "ВКЛ" if Game.test_player_godmode else "ВЫКЛ"
	var e_god = "ВКЛ" if Game.test_enemy_godmode else "ВЫКЛ"
	test_hud_lbl.text = "⚔️ ТЕСТ: [1] Спавн (%s) | [2] Бессмертие: %s | [3] Враги: %s | [4] HP/Стамина | [5] Очистить | [F] Пинок | [Alt] Рывок" % [next_name, p_god, e_god]

func _update_hint():
	if hint == null:
		return
	if airship_state == 2:
		var spd = int(airship.get_speed_kmh()) if airship != null else 0
		var alt = airship.get_altitude() if airship != null else 0.0
		hint.text = "ШТУРВАЛ | %d км/ч | Выс: %.1f м | [W/S] Газ/Тормоз | [A/D] Руль | [Пробел/Shift] Высота | [E/ESC] Выйти" % [spd, alt]
		return
	var is_town = str(LOCS.get(loc_id, {}).get("type", "")) == "town"
	var town_hint = " | N таверна" if is_town else ""
	if airship_state == 1:
		if fp_mode:
			hint.text = "[Палуба: 1-е лицо] WASD идти | Shift бег | Пробел прыжок | V 3-е лицо | E действие%s" % town_hint
		else:
			hint.text = "Палуба дирижабля | WASD идти | Shift бег | Пробел прыжок | ПКМ камера | V 1-е лицо | E действие%s" % town_hint
	if Game.combat_mode == Game.CombatMode.REALTIME_FP:
		if Game.is_combat_test:
			hint.text = "⚔️ [1-е лицо] ЛКМ: удар | ПКМ: блок | [F] пинок | [Alt] рывок (i-frame) | [1-5] тест | [M] карта"
		else:
			hint.text = "⚔️ [1-е лицо] WASD идти | ЛКМ удар | ПКМ блок | [F] пинок | [Alt] рывок (i-frame) | [M] карта"
		return
	if fp_mode:
		hint.text = "[1-е лицо] WASD идти | Shift бег | [Alt] рывок | Пробел прыжок | Мышь обзор | V 3-е лицо | E действие | ESC курсор%s | M карта" % town_hint
	else:
		hint.text = "WASD/клик идти | Shift бег | [Alt] рывок | Пробел прыжок | ПКМ камера | V 1-е лицо | E подобрать | R привал | P отряд%s | M карта" % town_hint

func _set_fp_mode(enabled: bool):
	if is_defeated:
		return
	if combat_lock and not rt_combat_active and not enabled:
		return
	if Game.combat_mode == Game.CombatMode.REALTIME_FP and not enabled:
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
		
		var target_y = 1.1 if airship_state == 2 else 1.4
		cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		cam_tween.tween_property(self, "cam_dist", 0.0, 0.45)
		cam_tween.tween_property(self, "pitch", 0.0, 0.45)
		cam_tween.tween_property(self, "fp_cam_y", target_y, 0.45)
		cam_tween.finished.connect(func():
			if fp_mode:
				if party_n.size() > 0 and is_instance_valid(party_n[0].root):
					party_n[0].root.visible = false
				if crosshair != null:
					crosshair.visible = true
				_ensure_fp_melee()
				if fp_melee != null and (rt_combat_active or Game.combat_mode == Game.CombatMode.REALTIME_FP):
					fp_melee.visible = true
		)
	else:
		if party_n.size() > 0 and is_instance_valid(party_n[0].root):
			party_n[0].root.visible = true
		if crosshair != null:
			crosshair.visible = false
		if fp_melee != null:
			fp_melee.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
		var target_dist = 8.5 if airship_state == 2 else (prev_cam_dist if prev_cam_dist > 1.5 else 4.0)
		var target_pitch = -0.32 if airship_state == 2 else (prev_pitch if prev_pitch < -0.1 else -0.9)
		
		cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		cam_tween.tween_property(self, "cam_dist", target_dist, 0.45)
		cam_tween.tween_property(self, "pitch", target_pitch, 0.45)
		cam_tween.tween_property(self, "fp_cam_y", 0.0, 0.45)
	_update_hint()

func _flyout_to_third_person():
	if Game.combat_mode == Game.CombatMode.REALTIME_FP:
		return
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
		party_hp_bars.append(hp_bar)
		party_hp_lbls.append(num_lbl)
		
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

func _update_party_hp_bars():
	for i in range(mini(party_hp_bars.size(), Game.party.size())):
		var m = Game.party[i]
		var cur_hp = int(m.get("hp", 0))
		var max_hp = maxi(1, int(m.get("maxhp", 1)))
		if is_instance_valid(party_hp_bars[i]):
			party_hp_bars[i].max_value = max_hp
			party_hp_bars[i].value = cur_hp
		if is_instance_valid(party_hp_lbls[i]):
			party_hp_lbls[i].text = "%d / %d" % [cur_hp, max_hp]

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

func _spawn_airship(x: float, z: float):
	if airship != null:
		return
	var airship_script = load("res://scripts/airship.gd")
	if airship_script == null:
		return
	airship = airship_script.new()
	airship.terrain = terrain
	var gh = terrain.sample_h(x, z) if terrain != null else 0.0
	airship.position = Vector3(x, gh + 1.8, z)
	add_child(airship)

func _board_airship():
	if airship == null or party_n.size() == 0:
		return
	var lead = party_n[0].root
	airship_state = 1
	airship.current_state = airship.State.ON_DECK
	target_point = null
	current_path.clear()
	var top_pos = airship.get_ladder_top_pos(lead.global_position)
	deck_local_pos = airship.to_deck_local(top_pos)
	deck_local_pos.x = clampf(deck_local_pos.x, airship.DECK_MIN_X, airship.DECK_MAX_X)
	deck_local_pos.z = clampf(deck_local_pos.z, airship.DECK_MIN_Z, airship.DECK_MAX_Z)
	deck_local_pos.y = airship.DECK_Y
	lead.global_position = airship.to_global(deck_local_pos)
	lead_y_offset = 0.0
	lead_vy = 0.0
	is_grounded = true
	if hint != null:
		hint.text = "Вы поднялись на борт дирижабля!"

func _exit_airship_to_ground():
	if airship == null or party_n.size() == 0:
		return
	if airship.get_altitude() > 1.2:
		if hint != null:
			hint.text = "Слишком высоко! Снизьтесь на дирижабле перед спуском."
		return
	var lead = party_n[0].root
	var bot_pos = airship.get_ladder_bottom_pos(lead.global_position)
	airship_state = 0
	airship.current_state = airship.State.GROUNDED
	target_point = null
	current_path.clear()
	var gh = terrain.sample_h(bot_pos.x, bot_pos.z) if terrain != null else 0.0
	lead.global_position = Vector3(bot_pos.x, gh, bot_pos.z)
	lead_y_offset = 0.0
	lead_vy = 0.0
	is_grounded = true
	for k in range(1, party_n.size()):
		var p_root = party_n[k].root
		p_root.global_position = Vector3(bot_pos.x - 0.5 * float(k), gh, bot_pos.z)
	_update_hint()

func _enter_airship_helm():
	if airship == null:
		return
	airship_state = 2
	airship.current_state = airship.State.PILOTING
	target_point = null
	current_path.clear()
	if not fp_mode:
		cam_dist = maxf(cam_dist, 8.5)
		pitch = -0.32
	if hint != null:
		hint.text = "Управление дирижаблем активировано!"

func _exit_airship_helm():
	if airship == null:
		return
	airship_state = 1
	airship.current_state = airship.State.ON_DECK
	deck_local_pos = airship.HELM_LOCAL + Vector3(0, 0, 1.0)
	if party_n.size() > 0:
		party_n[0].root.global_position = airship.to_global(deck_local_pos)
	if not fp_mode:
		cam_dist = 4.0
		pitch = -0.7
	if hint != null:
		hint.text = "Вы отошли от штурвала."

func _interact_ahead():
	if airship != null:
		if airship_state == 2:
			_exit_airship_helm()
			return
		elif airship_state == 1:
			var lead_pos = party_n[0].root.global_position if party_n.size() > 0 else Vector3.ZERO
			var d_helm = (lead_pos - airship.get_helm_pos()).length()
			var d_ladder = (lead_pos - airship.get_ladder_top_pos(lead_pos)).length()
			if d_helm < 1.8:
				_enter_airship_helm()
				return
			elif d_ladder < 1.8:
				_exit_airship_to_ground()
				return
		elif airship_state == 0:
			var lead_pos = party_n[0].root.global_position if party_n.size() > 0 else Vector3.ZERO
			var d_ladder = (lead_pos - airship.get_ladder_bottom_pos(lead_pos)).length()
			if d_ladder < 2.5:
				_board_airship()
				return
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
	_update_screen_shake(d)
	if is_defeated:
		return
	if party_n.size() == 0 or not is_instance_valid(party_n[0].get("root")):
		return
	var lead = party_n[0].root
	if not is_instance_valid(lead):
		return
	var hero_alive = not is_defeated and party_n.size() > 0 and int(party_n[0].m.get("hp", 0)) > 0

	if airship != null:
		airship.process_flight(d)

	if airship_state == 2:
		# Lock leader to helm
		var helm_p = airship.get_helm_pos()
		lead.global_position = helm_p - airship.global_transform.basis.z * (-0.7)
		lead.rotation.y = airship.rotation.y
		
		# Keep party members on deck
		for k in range(1, party_n.size()):
			var p_offset = Vector3(0.8 if k % 2 == 1 else -0.8, airship.DECK_Y, 0.5 + float(k) * 0.8)
			party_n[k].root.global_position = airship.to_global(p_offset)
			party_n[k].root.rotation.y = airship.rotation.y
		
		# Camera update in piloting mode
		if cam != null:
			if fp_mode:
				lead.rotation.y = yaw
				yaw_n.position = helm_p + Vector3(0, 1.1, 0)
				yaw_n.rotation = Vector3(0, yaw, 0)
				pitch_n.rotation = Vector3(pitch, 0, 0)
				cam.position = Vector3(0, 0, 0)
			else:
				var target_cam_yaw = airship.rotation.y
				yaw = lerp_angle(yaw, target_cam_yaw, d * 3.5)
				yaw_n.position = airship.global_position + Vector3(0, 2.2, 0)
				yaw_n.rotation = Vector3(0, yaw, 0)
				pitch_n.rotation = Vector3(pitch, 0, 0)
				cam.position = Vector3(0, 0, maxf(cam_dist, 8.5))
		
		if hint != null:
			var spd = int(airship.get_speed_kmh())
			var alt = airship.get_altitude()
			hint.text = "ШТУРВАЛ | %d км/ч | Выс: %.1f м | [W/S] Газ/Тормоз | [A/D] Руль | [Пробел] Вверх | [Shift] Вниз | [E/ESC] Выйти" % [spd, alt]
		return
	elif airship_state == 1:
		# Walking on deck mode
		if not is_grounded:
			lead_vy -= gravity * d
			lead_y_offset += lead_vy * d
			if lead_y_offset <= 0.0:
				lead_y_offset = 0.0
				lead_vy = 0.0
				is_grounded = true

		var mv = Vector2()
		var can_act_deck = (not combat_lock or rt_combat_active) and hero_alive
		if can_act_deck:
			if Input.is_key_pressed(KEY_W):
				mv.y -= 1
			if Input.is_key_pressed(KEY_S):
				mv.y += 1
			if Input.is_key_pressed(KEY_A):
				mv.x -= 1
			if Input.is_key_pressed(KEY_D):
				mv.x += 1

		var wants_sprint = Input.is_key_pressed(KEY_SHIFT) and can_act_deck
		var is_moving = mv.length() > 0 and can_act_deck
		is_sprinting = wants_sprint and is_moving and stamina > 2.0
		var cur_speed = 6.2 if is_sprinting else 3.2
		if is_sprinting:
			stamina = maxf(0.0, stamina - stamina_drain * d)
			stamina_cooldown = 0.4
		else:
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

		if mv.length() > 0:
			mv = mv.normalized()
			var forward = Vector3(-sin(yaw), 0, -cos(yaw))
			var right = Vector3(cos(yaw), 0, -sin(yaw))
			var world_dir = (forward * (-mv.y) + right * mv.x).normalized()
			var local_dir = airship.global_transform.basis.inverse() * world_dir
			deck_local_pos.x += local_dir.x * cur_speed * d
			deck_local_pos.z += local_dir.z * cur_speed * d
			if not fp_mode:
				lead.rotation.y = atan2(world_dir.x, world_dir.z)

		deck_local_pos.x = clampf(deck_local_pos.x, airship.DECK_MIN_X, airship.DECK_MAX_X)
		deck_local_pos.z = clampf(deck_local_pos.z, airship.DECK_MIN_Z, airship.DECK_MAX_Z)
		deck_local_pos.y = airship.DECK_Y + lead_y_offset
		lead.global_position = airship.to_global(deck_local_pos)
		if fp_mode:
			lead.rotation.y = yaw

		for k in range(1, party_n.size()):
			var p_offset = Vector3(0.7 if k % 2 == 1 else -0.7, airship.DECK_Y, clampf(deck_local_pos.z + 1.0 + float(k) * 0.6, airship.DECK_MIN_Z, airship.DECK_MAX_Z))
			party_n[k].root.global_position = airship.to_global(p_offset)
			party_n[k].root.rotation.y = lead.rotation.y

		if cam != null:
			yaw_n.position = lead.global_position + Vector3(0, fp_cam_y, 0) + cam_offset
			yaw_n.rotation = Vector3(0, yaw, 0)
			pitch_n.rotation = Vector3(pitch, 0, 0)
			cam.position = Vector3(0, 0, cam_dist)

		if hint != null:
			var d_helm = (lead.global_position - airship.get_helm_pos()).length()
			var d_ladder = (lead.global_position - airship.get_ladder_top_pos(lead.global_position)).length()
			if d_helm < 1.8:
				hint.text = "[E] Встать за штурвал (пилотирование) | [V] Вид"
			elif d_ladder < 1.8:
				if airship.get_altitude() <= 0.8:
					hint.text = "[E] Спуститься по трапу на землю"
				else:
					hint.text = "Высота %.1f м! Снизьтесь на дирижабле перед спуском" % airship.get_altitude()
			else:
				var is_town = str(LOCS.get(loc_id, {}).get("type", "")) == "town"
				var town_hint = " | N таверна" if is_town else ""
				if fp_mode:
					hint.text = "[Палуба: 1-е лицо] WASD идти | Shift бег | Пробел прыжок | V 3-е лицо%s" % town_hint
				else:
					hint.text = "Палуба дирижабля | WASD идти | Shift бег | Пробел прыжок | ПКМ камера | V 1-е лицо%s" % town_hint
		return

	# Ground exploration mode (airship_state == 0)
	if not is_grounded:
		lead_vy -= gravity * d
		lead_y_offset += lead_vy * d
		if lead_y_offset <= 0.0:
			lead_y_offset = 0.0
			lead_vy = 0.0
			is_grounded = true

	var mv = Vector2()
	var can_act = (not combat_lock or rt_combat_active) and hero_alive
	if can_act:
		if Input.is_key_pressed(KEY_W):
			mv.y -= 1
		if Input.is_key_pressed(KEY_S):
			mv.y += 1
		if Input.is_key_pressed(KEY_A):
			mv.x -= 1
		if Input.is_key_pressed(KEY_D):
			mv.x += 1

	var wants_sprint = Input.is_key_pressed(KEY_SHIFT) and can_act
	var is_moving = (mv.length() > 0 or current_path.size() > 0 or target_point != null) and can_act
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
	if Game.test_player_godmode:
		stamina = max_stamina

	if stamina_bar != null:
		stamina_bar.value = stamina
		var parent_c = stamina_bar.get_parent() as Control
		if parent_c != null:
			var target_alpha = 0.0 if (stamina >= max_stamina - 0.5 and not wants_sprint and not rt_combat_active) else 1.0
			parent_c.modulate.a = move_toward(parent_c.modulate.a, target_alpha, d * 3.5)

	if dash_cooldown > 0.0:
		dash_cooldown = maxf(0.0, dash_cooldown - d)
	if dash_iframe_timer > 0.0:
		dash_iframe_timer = maxf(0.0, dash_iframe_timer - d)

	if is_dashing:
		dash_timer -= d
		var progress = clampf(dash_timer / maxf(0.01, dash_duration), 0.0, 1.0)
		var cur_dash_speed = lerpf(3.5, 12.5, progress)
		_try_move(lead, dash_dir, cur_dash_speed * d)
		if dash_timer <= 0.0:
			is_dashing = false
	elif can_act and mv.length() > 0:
		target_point = null
		current_path.clear()
		mv = mv.normalized()
		var forward = Vector3(-sin(yaw), 0, -cos(yaw))
		var right = Vector3(cos(yaw), 0, -sin(yaw))
		var dir = (forward * (-mv.y) + right * mv.x).normalized()
		_try_move(lead, dir, cur_speed * d)
		if not fp_mode:
			lead.rotation.y = atan2(dir.x, dir.z)
	elif can_act and (current_path.size() > 0 or target_point != null):
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
	if not is_instance_valid(lead):
		return
	var ground_h = terrain.sample_h(lead.position.x, lead.position.z) if terrain != null else 0.0
	if (loc_id == "bandit_road" or loc_id == "road_bandits"):
		ground_h = CliffBridge.get_surface_y(lead.position.x, lead.position.z, lead.position.y, terrain)
		var c = Vector2i(int(floor(lead.position.x)), int(floor(lead.position.z)))
		if CliffBridge.is_bridge_cell(c) and lead.position.y < 1.4:
			lead_y_offset = minf(lead_y_offset, 0.7)
	var vert_speed = maxf(cur_speed * 1.6, 5.5)
	lead_base_y = move_toward(lead_base_y, ground_h, vert_speed * d)
	lead.position.y = lead_base_y + lead_y_offset
	for k in range(1, party_n.size()):
		var pn = party_n[k]
		var ph = terrain.sample_h(pn.root.position.x, pn.root.position.z) if terrain != null else 0.0
		if (loc_id == "bandit_road" or loc_id == "road_bandits"):
			ph = CliffBridge.get_surface_y(pn.root.position.x, pn.root.position.z, pn.root.position.y, terrain)
		var cur_by = float(pn.get("base_y", pn.root.position.y))
		cur_by = move_toward(cur_by, ph, vert_speed * d)
		pn["base_y"] = cur_by
		pn.root.position.y = cur_by
	if cam != null:
		if Game.combat_mode == Game.CombatMode.REALTIME_FP and not fp_mode and not is_defeated:
			_set_fp_mode(true)
		if fp_mode:
			lead.rotation.y = yaw
		yaw_n.position = lead.position + Vector3(0, fp_cam_y, 0) + cam_offset
		yaw_n.rotation = Vector3(0, yaw, 0)
		pitch_n.rotation = Vector3(pitch, 0, 0)
		cam.position = Vector3(0, 0, cam_dist)
	if not combat_lock and not rt_combat_active and not is_defeated:
		if hero_alive:
			for i in range(enemies.size() - 1, -1, -1):
				var en = enemies[i]
				if not is_instance_valid(en.get("root")) or int(en.get("hp", 1)) <= 0:
					enemies.remove_at(i)
					continue
				if (en.root.position - lead.position).length() < 2.0:
					if Game.combat_mode == Game.CombatMode.REALTIME_FP:
						_start_realtime_combat()
					else:
						combat_lock = true
						_try_combat()
					break
	if rt_combat_active:
		_process_realtime_combat(d)
	if airship != null and not combat_lock and hint != null:
		var d_lad = (lead.global_position - airship.get_ladder_bottom_pos(lead.global_position)).length()
		if d_lad < 2.5:
			hint.text = "[E] Подняться по трапу на дирижабль | " + hint.text

func _can_occupy(pos: Vector3, from_pos: Vector3 = Vector3.ZERO) -> bool:
	var cx = int(floor(pos.x))
	var cz = int(floor(pos.z))
	if terrain != null and not terrain.has_cell(cx, cz):
		return false
	if objects3.has(Vector2i(cx, cz)):
		return false
	if from_pos != Vector3.ZERO and (loc_id == "bandit_road" or loc_id == "road_bandits"):
		if not CliffBridge.can_step_height(from_pos.x, from_pos.z, pos.x, pos.z, from_pos.y, terrain):
			return false
	return true

func _try_move(node, dir, step):
	var np = node.position + dir * step
	var gw = (terrain.GW if terrain != null else 8)
	var gh = (terrain.GH if terrain != null else 6)
	np.x = clampf(np.x, 0.3, gw - 0.3)
	np.z = clampf(np.z, 0.3, gh - 0.3)
	
	if (loc_id == "bandit_road" or loc_id == "road_bandits") and node.position.y > 1.2:
		var c = Vector2i(int(floor(np.x)), int(floor(np.z)))
		if CliffBridge.is_bridge_cell(c):
			np.z = clampf(np.z, 5.15, 5.85)
	
	if _can_occupy(np, node.position):
		node.position = np
		return
	
	# Sliding attempt along X
	var npx = Vector3(np.x, node.position.y, node.position.z)
	if _can_occupy(npx, node.position):
		node.position = npx
		return
		
	# Sliding attempt along Z
	var npz = Vector3(node.position.x, node.position.y, np.z)
	if _can_occupy(npz, node.position):
		node.position = npz
		return

func _try_combat():
	if airship_state == 2 or (airship != null and airship.get_altitude() > 1.2):
		combat_lock = false
		return
	if party_n.size() == 0:
		combat_lock = false
		return
	if Game.flags.get("peace_" + loc_id, false) or Game.flags.get("paid_bandits_" + loc_id, false):
		combat_lock = false
		return
	var pre = str(LOCS.get(loc_id, {}).get("dlg", {}).get("pre", ""))
	if pre != "" and not pre_played:
		pre_played = true
		await _play_dlg(pre)
		if Game.flags.get("peace_" + loc_id, false) or Game.flags.get("paid_bandits_" + loc_id, false):
			combat_lock = false
			return
	if Game.combat_mode == Game.CombatMode.REALTIME_FP:
		combat_lock = false
		_start_realtime_combat()
	else:
		_start_combat()

func _start_realtime_combat():
	combat_lock = false
	rt_combat_active = true
	_set_fp_mode(true)
	
	if fp_melee == null or not is_instance_valid(fp_melee):
		fp_melee = FPMeleeClass.new()
		cam.add_child(fp_melee)
		fp_melee.attack_hit.connect(_on_rt_player_attack_hit)
		fp_melee.kick_hit.connect(_on_rt_player_kick_hit)
		fp_melee.parry_success.connect(_on_rt_player_parry)
		fp_melee.block_hit.connect(_on_rt_player_block)
	fp_melee.visible = true
	
	# Setup all enemies with archetype stats
	for i in range(enemies.size()):
		_setup_realtime_enemy(enemies[i], i)
	
	if hint != null:
		hint.text = "⚔️ БОЙ [1-Е ЛИЦО]: ЛКМ Удар | ПКМ Блок/Парирование | F Пинок | Alt Рывок"
	if party_n.size() > 0 and is_instance_valid(party_n[0].get("root")):
		_float_text(party_n[0].root.position, "В БОЙ!", Color(1.0, 0.4, 0.3))

func _setup_realtime_enemy(en: Dictionary, i: int = 0):
	var cls = str(en.get("cls", "swordsman"))
	var max_hp = 3
	if cls == "assassin" or cls == "archer" or cls == "mage":
		max_hp = 2
	elif cls == "swordsman" or cls == "halberd":
		max_hp = 3
	
	en["cls"] = cls
	en["hp"] = max_hp
	en["maxhp"] = max_hp
	en["atk_cd"] = 0.5 + float(i) * 0.5 + randf_range(0.1, 0.3)
	en["windup"] = 0.0
	en["windup_total"] = 0.75
	en["is_unblockable"] = false
	en["is_blocking"] = false
	en["block_timer"] = 0.0
	en["block_cd"] = randf_range(1.5, 3.5)
	en["stagger"] = 0.0
	en["staggered"] = false
	en["strafe_dir"] = 1.0 if randf() > 0.5 else -1.0
	en["combo_step"] = 0
	
	if cls == "archer":
		en["state"] = "reload"
		en["state_timer"] = randf_range(1.4, 2.4)
		en["state_total"] = 2.5
	elif cls == "mage":
		en["state"] = "cast"
		en["state_timer"] = randf_range(1.6, 2.6)
		en["state_total"] = 2.8
	else:
		en["state"] = "aggro"
	
	_update_enemy_hp_display(en)
	_update_enemy_status_display(en)

func _update_enemy_status_display(en: Dictionary):
	if not is_instance_valid(en.get("root")):
		return
	var er = en.root
	var s_lbl = er.get_node_or_null("EnemyStatusLbl") as Label3D
	if s_lbl == null:
		s_lbl = Label3D.new()
		s_lbl.name = "EnemyStatusLbl"
		s_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s_lbl.pixel_size = 0.0055
		s_lbl.position = Vector3(0, 2.15, 0)
		er.add_child(s_lbl)
	
	var stagger = float(en.get("stagger", 0.0))
	var is_blocking = bool(en.get("is_blocking", false))
	var windup = float(en.get("windup", 0.0))
	var state = str(en.get("state", "aggro"))
	var state_timer = float(en.get("state_timer", 0.0))
	var state_total = float(en.get("state_total", 2.5))
	
	if stagger > 0.0:
		s_lbl.visible = true
		s_lbl.text = "💫 ОГЛУШЁН! (%.1fc)" % stagger
		s_lbl.modulate = Color(1.0, 0.88, 0.2)
		_set_actor_tint(er, Color(0.4, 0.7, 1.0))
	elif is_blocking:
		s_lbl.visible = true
		s_lbl.text = "🛡️ БЛОК ЩИТОМ"
		s_lbl.modulate = Color(0.35, 0.85, 1.0)
		_set_actor_tint(er, Color(0.5, 0.9, 1.5))
	elif windup > 0.0:
		s_lbl.visible = true
		var is_unb = bool(en.get("is_unblockable", false))
		var pulse = sin(Time.get_ticks_msec() * 0.03) * 0.35 + 0.65
		if is_unb:
			s_lbl.text = "💥 НЕБЛОКИРУЕМЫЙ! (%.1fc)" % windup
			s_lbl.modulate = Color(1.0, 0.15 * pulse, 0.15 * pulse)
			_set_actor_tint(er, Color(2.6 * pulse, 0.2, 0.2))
		else:
			s_lbl.text = "⚠️ ЗАМАХ! (%.1fc)" % windup
			s_lbl.modulate = Color(1.0, 0.5 + 0.5 * pulse, 0.15)
			_set_actor_tint(er, Color(2.2 * pulse, 1.1 * pulse, 0.3))
	elif state == "reload":
		s_lbl.visible = true
		var pips_cnt = int(clampf(1.0 - state_timer / maxf(0.01, state_total), 0.0, 1.0) * 5)
		var pips = ""
		for p in range(5):
			pips += "■" if p < pips_cnt else "□"
		s_lbl.text = "🏹 ЗАРЯДКА [%s] %.1fc" % [pips, maxf(0.0, state_timer)]
		s_lbl.modulate = Color(0.5, 0.95, 0.5)
		_set_actor_tint(er, Color(1.0, 1.0, 1.0))
	elif state == "aim":
		s_lbl.visible = true
		s_lbl.text = "⚠️ ВЫСТРЕЛ! (%.1fc)" % maxf(0.0, state_timer)
		s_lbl.modulate = Color(1.0, 0.85, 0.2)
		_set_actor_tint(er, Color(1.8, 1.5, 0.4))
	elif state == "cast":
		s_lbl.visible = true
		var pips_cnt = int(clampf(1.0 - state_timer / maxf(0.01, state_total), 0.0, 1.0) * 5)
		var pips = ""
		for p in range(5):
			pips += "■" if p < pips_cnt else "□"
		s_lbl.text = "🔮 КАСТ [%s] %.1fc" % [pips, maxf(0.0, state_timer)]
		s_lbl.modulate = Color(0.9, 0.45, 1.0)
		_set_actor_tint(er, Color(1.8, 0.5, 2.0))
	else:
		s_lbl.visible = false
		_set_actor_tint(er, Color(1.0, 1.0, 1.0))

func _show_enemy_telegraph(en: Dictionary, _remaining_time: float):
	_update_enemy_status_display(en)

func _hide_enemy_telegraph(en: Dictionary):
	_update_enemy_status_display(en)

func _update_enemy_hp_display(en: Dictionary):
	if not is_instance_valid(en.get("root")):
		return
	var er = en.root
	var hp_lbl = er.get_node_or_null("EnemyHPLbl") as Label3D
	if hp_lbl == null:
		hp_lbl = Label3D.new()
		hp_lbl.name = "EnemyHPLbl"
		hp_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		hp_lbl.pixel_size = 0.0045
		hp_lbl.position = Vector3(0, 1.85, 0)
		er.add_child(hp_lbl)
	
	var cur_hp = int(en.get("hp", 0))
	var max_hp = int(en.get("maxhp", 3))
	var pips = ""
	for i in range(max_hp):
		pips += "■" if i < cur_hp else "□"
	hp_lbl.text = "%s %d/%d HP" % [pips, cur_hp, max_hp]
	hp_lbl.modulate = Color(1.0, 0.25, 0.25) if cur_hp <= 1 else Color(1.0, 0.85, 0.4)
	hp_lbl.visible = cur_hp > 0

func _spawn_archer_arrow(en: Dictionary, target_pos: Vector3):
	if not is_instance_valid(en.get("root")):
		return
	var origin = en.root.position + Vector3(0, 1.25, 0)
	var dir = (target_pos - origin).normalized()
	
	var node = Node3D.new()
	var mesh_inst = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.015
	cm.bottom_radius = 0.015
	cm.height = 0.75
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.22, 0.12)
	mat.roughness = 0.8
	mesh_inst.mesh = cm
	mesh_inst.material_override = mat
	mesh_inst.rotation.x = deg_to_rad(90)
	node.add_child(mesh_inst)
	
	var tip = MeshInstance3D.new()
	var tm = CylinderMesh.new()
	tm.top_radius = 0.0
	tm.bottom_radius = 0.035
	tm.height = 0.12
	var tip_mat = StandardMaterial3D.new()
	tip_mat.albedo_color = Color(0.8, 0.8, 0.85)
	tip_mat.metallic = 0.9
	tip.mesh = tm
	tip.material_override = tip_mat
	tip.rotation.x = deg_to_rad(90)
	tip.position = Vector3(0, 0, -0.38)
	node.add_child(tip)
	
	node.position = origin
	add_child(node)
	if dir.length_squared() > 0.001:
		node.look_at(origin + dir, Vector3.UP)
	
	rt_projectiles.append({
		"node": node,
		"type": "arrow",
		"pos": origin,
		"dir": dir,
		"speed": 14.0,
		"damage": 1,
		"lifetime": 3.0
	})
	_float_text(origin, "🏹 ВЫСТРЕЛ!", Color(0.5, 0.9, 0.5))

func _spawn_mage_fireball(en: Dictionary, target_pos: Vector3):
	if not is_instance_valid(en.get("root")):
		return
	var origin = en.root.position + Vector3(0, 1.25, 0)
	var dir = (target_pos - origin).normalized()
	
	var node = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.45, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.1)
	mat.emission_energy_multiplier = 3.0
	node.mesh = sm
	node.material_override = mat
	node.position = origin
	add_child(node)
	
	rt_projectiles.append({
		"node": node,
		"type": "fireball",
		"pos": origin,
		"dir": dir,
		"speed": 7.0,
		"damage": 1,
		"lifetime": 3.5
	})
	_float_text(origin, "🔥 ОГНЕННЫЙ ШАР!", Color(1.0, 0.5, 0.2))

func _process_projectiles(d: float):
	if party_n.size() == 0 or not is_instance_valid(party_n[0].get("root")):
		return
	var lead = party_n[0].root
	var lead_pos = lead.position + Vector3(0, 1.0, 0)
	
	for i in range(rt_projectiles.size() - 1, -1, -1):
		var p = rt_projectiles[i]
		if not is_instance_valid(p.get("node")):
			rt_projectiles.remove_at(i)
			continue
		
		p["pos"] += p["dir"] * float(p["speed"]) * d
		p["node"].position = p["pos"]
		p["lifetime"] -= d
		
		var dist_to_hero = (p["pos"] - lead_pos).length()
		if dist_to_hero < 0.85:
			_on_hero_hit_by_projectile(p)
			if is_instance_valid(p["node"]):
				p["node"].queue_free()
			rt_projectiles.remove_at(i)
			continue
			
		if p["lifetime"] <= 0.0:
			if is_instance_valid(p["node"]):
				p["node"].queue_free()
			rt_projectiles.remove_at(i)

func _on_hero_hit_by_projectile(p: Dictionary):
	if is_defeated or party_n.size() == 0 or not is_instance_valid(party_n[0].get("root")):
		return
	var lead = party_n[0].root
	var ptype = str(p.get("type", "arrow"))
	var dmg = int(p.get("damage", 1))
	
	if is_hero_invulnerable():
		_float_text(lead.position, "💨 УВОРОТ (I-FRAME)!", Color(0.3, 0.95, 1.0))
		return
	
	if fp_melee != null and fp_melee.is_blocking():
		stamina = maxf(0.0, stamina - (12.0 if ptype == "arrow" else 16.0))
		stamina_cooldown = 0.5
		_screen_shake(0.03, 0.08)
		if ptype == "arrow":
			_float_text(lead.position, "🛡️ СТРЕЛА ЗАБЛОКИРОВАНА!", Color(0.4, 0.85, 1.0))
			if parry_prompt_lbl != null:
				parry_prompt_lbl.text = "🛡️ СТРЕЛА ЗАБЛОКИРОВАНА!"
				parry_prompt_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
		else:
			_float_text(lead.position, "🛡️ ОГОНЬ ЗАБЛОКИРОВАН!", Color(1.0, 0.6, 0.2))
			if parry_prompt_lbl != null:
				parry_prompt_lbl.text = "🛡️ ОГОНЬ ЗАБЛОКИРОВАН!"
				parry_prompt_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		return
	
	if Game.test_player_godmode:
		_float_text(lead.position, "🛡️ БЕССМЕРТИЕ (0 УРОНА)", Color(0.3, 1.0, 0.5))
		return
	
	var hero = party_n[0].m
	hero["hp"] = max(0, int(hero.get("hp", 2)) - dmg)
	_update_party_hp_bars()
	_screen_shake(0.065, 0.14)
	if ptype == "arrow":
		_float_text(lead.position, "🏹 ПОПАДАНИЕ СТРЕЛЫ! -%d HP" % dmg, Color(1.0, 0.3, 0.3))
	else:
		_float_text(lead.position, "🔥 УДАР МАГИЕЙ! -%d HP" % dmg, Color(1.0, 0.25, 0.1))
	if int(hero.get("hp", 0)) <= 0:
		_handle_hero_death()

func _clean_up_projectiles():
	for p in rt_projectiles:
		if is_instance_valid(p.get("node")):
			p["node"].queue_free()
	rt_projectiles.clear()


func _try_fp_attack():
	_start_fp_attack()
	_release_fp_attack()

func _start_fp_attack():
	if is_defeated or party_n.size() == 0 or int(party_n[0].m.get("hp", 0)) <= 0:
		return
	if fp_melee == null or not fp_melee.can_attack():
		return
	if not Game.test_player_godmode and stamina < 8.0:
		if hint != null:
			hint.text = "Недостаточно выносливости для удара!"
		return
	fp_melee.start_charge()

func _release_fp_attack():
	if is_defeated or party_n.size() == 0 or int(party_n[0].m.get("hp", 0)) <= 0:
		return
	if fp_melee == null or not fp_melee.is_charging():
		return
	
	var valid_enemies = []
	for en in enemies:
		if is_instance_valid(en.get("root")) and int(en.get("hp", 3)) > 0:
			valid_enemies.append(en)
	
	var res = fp_melee.release_charge(valid_enemies)
	var is_heavy = bool(res.get("is_heavy", false))
	var cost = float(res.get("stamina_cost", 8.0))
	if not Game.test_player_godmode:
		stamina = maxf(0.0, stamina - cost)
		stamina_cooldown = 0.4
	
	if hint != null:
		hint.text = "💥 ТЯЖЁЛЫЙ УДАР!" if is_heavy else "⚔️ БЫСТРЫЙ УДАР!"

func _try_fp_kick():
	if is_defeated or party_n.size() == 0 or int(party_n[0].m.get("hp", 0)) <= 0:
		return
	if fp_melee == null or not fp_melee.can_kick():
		return
	if not Game.test_player_godmode and stamina < 10.0:
		if hint != null:
			hint.text = "Недостаточно выносливости для пинка!"
		return
	if not Game.test_player_godmode:
		stamina = maxf(0.0, stamina - 10.0)
		stamina_cooldown = 0.4
	
	var valid_enemies = []
	for en in enemies:
		if is_instance_valid(en.get("root")) and int(en.get("hp", 3)) > 0:
			valid_enemies.append(en)
	
	fp_melee.try_kick(valid_enemies)

func _on_rt_player_kick_hit(target):
	if not rt_combat_active and not is_defeated:
		_start_realtime_combat()
	if target is Dictionary and target.has("hp"):
		var was_blocking = bool(target.get("is_blocking", false))
		target["is_blocking"] = false
		target["windup"] = 0.0
		
		# Interrupt cast/aim
		if target.get("state") == "cast":
			target["state_timer"] = 2.8
			if is_instance_valid(target.get("root")):
				_float_text(target.root.position, "💥 КАСТ СБИТ!", Color(1.0, 0.4, 0.8))
		elif target.get("state") == "aim":
			target["state"] = "reload"
			target["state_timer"] = 2.5
			if is_instance_valid(target.get("root")):
				_float_text(target.root.position, "💥 ПРИЦЕЛ СБИТ!", Color(1.0, 0.6, 0.4))
		
		if Game.test_enemy_godmode:
			target["hp"] = max(1, int(target["hp"]) - 1)
		else:
			target["hp"] = int(target["hp"]) - 1
		
		target["stagger"] = 2.0 if was_blocking else 1.6
		target["staggered"] = true
		target["atk_cd"] = 1.5 if was_blocking else 1.2
		
		if is_instance_valid(target.get("root")):
			var er = target.root
			var kick_txt = "💥 БЛОК ПРОБИТ ПИНКОМ! [СТАН]" if was_blocking else "🦶 ПИНОК! [ОТБРОШЕН]"
			_float_text(er.position, kick_txt, Color(1.0, 0.85, 0.2) if was_blocking else Color(1.0, 0.65, 0.2))
			_update_enemy_hp_display(target)
			_update_enemy_status_display(target)
			_screen_shake(0.06 if was_blocking else 0.05, 0.16 if was_blocking else 0.14)
			
			_set_actor_tint(er, Color(4.0, 4.0, 4.0))
			var tw = er.create_tween()
			tw.tween_interval(0.07)
			tw.tween_callback(func():
				if is_instance_valid(er):
					_set_actor_tint(er, Color(0.4, 0.7, 1.0))
			)
			
			if party_n.size() > 0 and is_instance_valid(party_n[0].get("root")):
				var push_dir = (er.position - party_n[0].root.position).normalized()
				push_dir.y = 0
				_try_move(er, push_dir, 1.8 if was_blocking else 1.5)
			
			tw.parallel().tween_property(er, "scale", Vector3(1.35, 0.65, 1.35), 0.08)
			tw.tween_property(er, "scale", Vector3(1.0, 1.0, 1.0), 0.12)
		
		if not Game.test_enemy_godmode and target["hp"] <= 0:
			_update_enemy_status_display(target)
			_on_enemy_killed(target)

func _on_rt_player_attack_hit(target, damage, is_crit, is_heavy = false):
	if not rt_combat_active and not is_defeated:
		_start_realtime_combat()
	if target is Dictionary and target.has("hp"):
		var er = target.get("root")
		
		# Check if enemy is blocking with shield!
		if bool(target.get("is_blocking", false)):
			if is_heavy:
				# Heavy attack crushes enemy block!
				target["is_blocking"] = false
				target["stagger"] = 1.6
				target["staggered"] = true
				target["windup"] = 0.0
				if is_instance_valid(er):
					_float_text(er.position, "💥 БЛОК СОКРУШЁН! -%d" % int(damage), Color(1.0, 0.55, 0.15))
			else:
				# Fast light strike is blocked by shield!
				if is_instance_valid(er):
					_float_text(er.position, "🛡️ ЗАБЛОКИРОВАНО ВРАГОМ!", Color(0.4, 0.85, 1.0))
					_screen_shake(0.035, 0.09)
					_set_actor_tint(er, Color(0.5, 1.2, 2.5))
					var tw = er.create_tween()
					tw.tween_interval(0.08)
					tw.tween_callback(func():
						if is_instance_valid(er):
							_update_enemy_status_display(target)
					)
				target["atk_cd"] = 0.3 # Enemy quick counter-attack window
				return
		
		# Interrupt cast/aim upon damage
		if target.get("state") == "cast":
			target["state_timer"] = 2.8
			if is_instance_valid(er):
				_float_text(er.position, "💥 КАСТ СБИТ!", Color(1.0, 0.4, 0.8))
		elif target.get("state") == "aim":
			target["state"] = "reload"
			target["state_timer"] = 2.5
			if is_instance_valid(er):
				_float_text(er.position, "💥 ПРИЦЕЛ СБИТ!", Color(1.0, 0.6, 0.4))

		if Game.test_enemy_godmode:
			target["hp"] = max(1, int(target["hp"]) - int(damage))
		else:
			target["hp"] = int(target["hp"]) - int(damage)
		
		var txt = ""
		var col = Color(1.0, 0.85, 0.2)
		if is_heavy:
			txt = "💥 СИЛЬНЫЙ УДАР! -%d" % int(damage)
			col = Color(1.0, 0.55, 0.15)
			target["stagger"] = 1.4
			target["staggered"] = true
			target["windup"] = 0.0
			_update_enemy_status_display(target)
		elif is_crit:
			txt = "✨ КРИТ! -%d" % int(damage)
			col = Color(1.0, 0.85, 0.2)
		else:
			txt = "⚔️ -%d" % int(damage)
			col = Color(1.0, 0.35, 0.35)
			
		if is_instance_valid(er):
			_float_text(er.position, txt, col)
			_update_enemy_hp_display(target)
			_update_enemy_status_display(target)
			_screen_shake(0.07 if is_heavy else (0.045 if is_crit else 0.025), 0.12 if is_heavy else 0.09)
			
			# White hit flash on enemy
			_set_actor_tint(er, Color(4.0, 4.0, 4.0))
			var tw = er.create_tween()
			tw.tween_interval(0.07)
			tw.tween_callback(func():
				if is_instance_valid(er):
					_set_actor_tint(er, Color(1.0, 1.0, 1.0))
			)
			
			# Knockback & recoil
			if party_n.size() > 0 and is_instance_valid(party_n[0].get("root")):
				var push_dir = (er.position - party_n[0].root.position).normalized()
				push_dir.y = 0
				var push_dist = 0.7 if is_heavy else 0.35
				_try_move(er, push_dir, push_dist)
			
			tw.parallel().tween_property(er, "scale", Vector3(1.35 if is_heavy else 1.25, 0.7 if is_heavy else 0.8, 1.35 if is_heavy else 1.25), 0.07)
			tw.tween_property(er, "scale", Vector3(1.0, 1.0, 1.0), 0.12)
		
		if not Game.test_enemy_godmode and target["hp"] <= 0:
			_update_enemy_status_display(target)
			_on_enemy_killed(target)

func _apply_parry_riposte(en: Dictionary):
	if not is_instance_valid(en.get("root")):
		return
	var er = en.root
	var now = Time.get_ticks_msec()
	if now - int(en.get("last_riposted_time", 0)) < 450:
		return
	en["last_riposted_time"] = now
	en["windup"] = 0.0
	_hide_enemy_telegraph(en)
	
	# Stagger the enemy
	en["stagger"] = 2.0
	en["staggered"] = true
	
	# Counter-attack (riposte) damage!
	var riposte_dmg = 2
	if Game.test_enemy_godmode:
		en["hp"] = max(1, int(en.get("hp", 3)) - riposte_dmg)
	else:
		en["hp"] = max(0, int(en.get("hp", 3)) - riposte_dmg)
	
	# White flash on enemy
	_set_actor_tint(er, Color(4.0, 4.0, 4.0))
	var tw = er.create_tween()
	tw.tween_interval(0.08)
	tw.tween_callback(func():
		if is_instance_valid(er):
			_set_actor_tint(er, Color(0.4, 0.7, 1.0))
	)
	
	# Pushback away from hero
	if party_n.size() > 0 and is_instance_valid(party_n[0].get("root")):
		var push_dir = (er.position - party_n[0].root.position).normalized()
		push_dir.y = 0
		_try_move(er, push_dir, 0.6)
	
	_screen_shake(0.08, 0.2)
	_float_text(er.position, "✨ ПАРИРОВАНИЕ & РИПОСТ! -%d HP" % riposte_dmg, Color(1.0, 0.88, 0.25))
	_update_enemy_hp_display(en)
	
	if parry_prompt_lbl != null:
		parry_prompt_lbl.text = "✨ ИДЕАЛЬНОЕ ПАРИРОВАНИЕ! КОНТРУДАР (-%d HP)!" % riposte_dmg
		parry_prompt_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
	
	if fp_melee != null:
		fp_melee._trigger_riposte_anim()
	
	if not Game.test_enemy_godmode and int(en.get("hp", 0)) <= 0:
		_on_enemy_killed(en)

func _try_rt_active_parry():
	if not rt_combat_active or is_defeated or party_n.size() == 0 or not is_instance_valid(party_n[0].get("root")):
		return
	var lead = party_n[0].root
	for en in enemies:
		if not is_instance_valid(en.get("root")):
			continue
		var dist = (lead.position - en.root.position).length()
		var reach = 3.6 if en.get("cls") == "halberd" else 3.2
		if dist <= reach:
			if bool(en.get("is_unblockable", false)):
				continue
			var windup = float(en.get("windup", 0.0))
			# Enemy in active parry window (final 0.45s of windup)
			if windup > 0.0 and windup <= 0.45:
				_apply_parry_riposte(en)
				break

func _on_rt_player_parry(attacker):
	if attacker is Dictionary:
		_apply_parry_riposte(attacker)

func _on_rt_player_block(_attacker, absorbed):
	stamina = maxf(0.0, stamina - 15.0)
	stamina_cooldown = 0.5
	if parry_prompt_lbl != null:
		parry_prompt_lbl.text = "🛡️ УДАР ЗАБЛОКИРОВАН (-%d)" % int(absorbed)
		parry_prompt_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	if party_n.size() > 0 and is_instance_valid(party_n[0].get("root")):
		_float_text(party_n[0].root.position, "🛡️ БЛОК! (-%d)" % int(absorbed), Color(0.4, 0.8, 1.0))
	_screen_shake(0.03, 0.08)

func _on_enemy_killed(target: Dictionary):
	if is_instance_valid(target.get("root")):
		_float_text(target.root.position, "💀 УБИТ!", Color(1.0, 0.2, 0.2))
	target["hp"] = 0
	enemies.erase(target)
	
	var loot_table = LOCS.get(loc_id, {}).get("loot", [])
	for l in loot_table:
		if randf() * 100.0 < float(l.get("chance", 35)):
			var it = str(l.get("item", ""))
			if it != "" and is_instance_valid(target.get("root")):
				_spawn_ground({"pos": [target.root.position.x, target.root.position.z], "item": it, "day": Game.day})
	for m in Game.party:
		PartyTools.add_xp(m, 5)
	_update_party_hp_bars()
	
	if is_instance_valid(target.get("root")):
		var er = target.root
		var tw = er.create_tween()
		tw.tween_property(er, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
		tw.finished.connect(func():
			if is_instance_valid(er):
				er.queue_free()
		)

func _set_actor_tint(root: Node3D, col: Color):
	if root == null or not is_instance_valid(root):
		return
	for c in root.get_children():
		if c is Sprite3D:
			c.modulate = col
		elif c is MeshInstance3D and c.material_override is StandardMaterial3D:
			c.material_override.albedo_color = col

func _process_realtime_combat(d: float):
	if is_defeated or party_n.size() == 0 or not is_instance_valid(party_n[0].get("root")):
		return
	if int(party_n[0].m.get("hp", 0)) <= 0:
		return
	var lead = party_n[0].root
	var lead_pos = lead.position

	# 1. Update ranged projectiles
	_process_projectiles(d)

	# 2. Check if player is charging an attack (for enemy reactivity)
	var is_player_charging = (fp_melee != null and fp_melee.is_charging())

	# Count active windups & find imminent attacker for parry HUD
	var active_windups = 0
	var min_windup_enemy = null
	var min_rem_windup = 999.0

	var alive_enemies = 0
	for i in range(enemies.size() - 1, -1, -1):
		var en = enemies[i]
		if not is_instance_valid(en.get("root")):
			enemies.remove_at(i)
			continue
		var er = en.root
		var hp = int(en.get("hp", 3))
		if hp <= 0:
			enemies.remove_at(i)
			continue
		alive_enemies += 1

		var to_player = lead_pos - er.position
		to_player.y = 0
		var dist = to_player.length()

		if dist > 0.05:
			er.rotation.y = atan2(to_player.x, to_player.z)

		var cls = str(en.get("cls", "swordsman"))

		# Check Stagger
		var stagger = float(en.get("stagger", 0.0))
		if stagger > 0.0:
			en["stagger"] = maxf(0.0, stagger - d)
			_update_enemy_status_display(en)
			continue
		else:
			en["staggered"] = false

		# Check Enemy Block
		var is_blocking = bool(en.get("is_blocking", false))
		var block_cd = float(en.get("block_cd", 0.0))
		if block_cd > 0.0:
			en["block_cd"] = maxf(0.0, block_cd - d)

		if is_blocking:
			var block_timer = float(en.get("block_timer", 0.0)) - d
			en["block_timer"] = block_timer
			if block_timer <= 0.0:
				en["is_blocking"] = false
				en["block_cd"] = randf_range(2.0, 3.5)
			else:
				if dist > 1.4:
					_try_move(er, to_player.normalized(), 0.8 * d)
				_update_enemy_status_display(en)
				continue

		# Check Active Windup
		var windup = float(en.get("windup", 0.0))
		if windup > 0.0:
			active_windups += 1
			if windup < min_rem_windup:
				min_rem_windup = windup
				min_windup_enemy = en
			
			en["windup"] = maxf(0.0, windup - d)
			_update_enemy_status_display(en)
			if en["windup"] <= 0.0:
				_enemy_realtime_strike(en)
			continue

		# Reaction to player charging attack (raising shield / dodge / poke)
		if is_player_charging and dist <= 3.2:
			if cls == "swordsman" and en.get("block_cd", 0.0) <= 0.0 and randf() < 0.7:
				en["is_blocking"] = true
				en["block_timer"] = randf_range(1.6, 2.4)
				_float_text(er.position, "🛡️ БЛОК!", Color(0.4, 0.85, 1.0))
				_update_enemy_status_display(en)
				continue
			elif cls == "assassin" and randf() < 0.5:
				var back_dir = -to_player.normalized()
				_try_move(er, back_dir, 2.2 * d * 8.0)
			elif cls == "halberd" and en.get("atk_cd", 0.0) <= 0.0 and active_windups == 0 and randf() < 0.45:
				en["windup"] = 0.5
				en["windup_total"] = 0.5
				en["is_unblockable"] = false
				active_windups += 1
				min_windup_enemy = en
				min_rem_windup = 0.5
				_update_enemy_status_display(en)
				continue

		# Attack Cooldown
		var atk_cd = float(en.get("atk_cd", 0.0))
		if atk_cd > 0.0:
			en["atk_cd"] = maxf(0.0, atk_cd - d)

		# Class-specific Movement & Actions
		if cls == "archer":
			if dist < 5.0:
				_try_move(er, -to_player.normalized(), 3.0 * d)
			elif dist > 9.5:
				_try_move(er, to_player.normalized(), 2.0 * d)
			
			var state = str(en.get("state", "reload"))
			var state_timer = float(en.get("state_timer", 2.0)) - d
			en["state_timer"] = state_timer
			
			if state == "reload":
				if state_timer <= 0.0:
					en["state"] = "aim"
					en["state_timer"] = 0.7
					en["state_total"] = 0.7
			elif state == "aim":
				if state_timer <= 0.0:
					_spawn_archer_arrow(en, lead_pos + Vector3(0, 1.1, 0))
					en["state"] = "reload"
					en["state_timer"] = 2.5
					en["state_total"] = 2.5
			else:
				en["state"] = "reload"
				en["state_timer"] = 2.5
				en["state_total"] = 2.5
			_update_enemy_status_display(en)

		elif cls == "mage":
			if dist < 4.5:
				_try_move(er, -to_player.normalized(), 2.5 * d)
			elif dist > 9.0:
				_try_move(er, to_player.normalized(), 1.8 * d)
			
			var state = str(en.get("state", "cast"))
			var state_timer = float(en.get("state_timer", 2.5)) - d
			en["state_timer"] = state_timer
			
			if state == "cast":
				if state_timer <= 0.0:
					_spawn_mage_fireball(en, lead_pos + Vector3(0, 1.0, 0))
					en["state"] = "cast"
					en["state_timer"] = 2.8
					en["state_total"] = 2.8
			else:
				en["state"] = "cast"
				en["state_timer"] = 2.8
				en["state_total"] = 2.8
			_update_enemy_status_display(en)

		elif cls == "assassin":
			var fwd = to_player.normalized()
			var side = Vector3(-fwd.z, 0, fwd.x) * float(en.get("strafe_dir", 1.0))
			if randf() < 0.025:
				en["strafe_dir"] = -float(en.get("strafe_dir", 1.0))
			
			if dist > 1.5:
				var move_dir = (fwd * 0.7 + side * 0.75).normalized()
				_try_move(er, move_dir, 3.6 * d)
			elif dist <= 1.5 and atk_cd <= 0.0:
				if active_windups == 0:
					en["windup"] = 0.45
					en["windup_total"] = 0.45
					en["is_unblockable"] = false
					en["combo_step"] = 0
					active_windups += 1
					min_windup_enemy = en
					min_rem_windup = 0.45
				else:
					en["atk_cd"] = randf_range(0.4, 0.8)
			_update_enemy_status_display(en)

		elif cls == "halberd":
			if dist > 2.8:
				_try_move(er, to_player.normalized(), 2.0 * d)
			elif dist < 2.0:
				_try_move(er, -to_player.normalized(), 1.6 * d)
			
			if dist <= 3.0 and atk_cd <= 0.0:
				if active_windups == 0:
					var is_unb = randf() < 0.45
					en["is_unblockable"] = is_unb
					en["windup"] = 0.85 if is_unb else 0.65
					en["windup_total"] = en["windup"]
					active_windups += 1
					min_windup_enemy = en
					min_rem_windup = en["windup"]
				else:
					en["atk_cd"] = randf_range(0.6, 1.2)
			_update_enemy_status_display(en)

		else:
			# Swordsman
			if dist > 1.6:
				_try_move(er, to_player.normalized(), 2.3 * d)
			elif dist <= 1.6 and atk_cd <= 0.0:
				if active_windups == 0:
					en["windup"] = 0.75
					en["windup_total"] = 0.75
					en["is_unblockable"] = false
					active_windups += 1
					min_windup_enemy = en
					min_rem_windup = 0.75
				else:
					en["atk_cd"] = randf_range(0.5, 1.1)
			_update_enemy_status_display(en)

		var eh = terrain.sample_h(er.position.x, er.position.z) if terrain != null else 0.0
		er.position.y = eh

	# Update Parry Timing Bar HUD
	if parry_hud != null and is_instance_valid(parry_hud):
		if min_windup_enemy != null and min_rem_windup < 900.0:
			parry_hud.modulate.a = move_toward(parry_hud.modulate.a, 1.0, d * 8.0)
			var w_total = float(min_windup_enemy.get("windup_total", 0.75))
			var progress = clampf(1.0 - (min_rem_windup / maxf(0.01, w_total)), 0.0, 1.0)
			parry_progress_bar.value = progress
			var is_unb = bool(min_windup_enemy.get("is_unblockable", false))
			if is_unb:
				parry_prompt_lbl.text = "💥 НЕБЛОКИРУЕМЫЙ! ОТПРЫГИВАЙ [ПРОБЕЛ]!"
				parry_prompt_lbl.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
				parry_zone_rect.color = Color(1.0, 0.15, 0.15, 0.8)
			elif progress >= 0.50:
				parry_prompt_lbl.text = "🛡️ ЖМИ ПКМ! ОКНО ПАРИРОВАНИЯ!"
				parry_prompt_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45))
				parry_zone_rect.color = Color(0.3, 1.0, 0.5, 0.75)
			else:
				parry_prompt_lbl.text = "⚠️ ВРАГ ЗАМАХНУЛСЯ..."
				parry_prompt_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
				parry_zone_rect.color = Color(0.2, 0.85, 0.4, 0.45)
		else:
			parry_hud.modulate.a = move_toward(parry_hud.modulate.a, 0.0, d * 3.5)

	if alive_enemies == 0 and enemies.size() == 0:
		_end_realtime_combat(true)

func _enemy_realtime_strike(en: Dictionary):
	_update_enemy_status_display(en)
	if is_defeated or party_n.size() == 0 or not is_instance_valid(party_n[0].get("root")):
		return
	if int(party_n[0].m.get("hp", 0)) <= 0:
		return
	if not is_instance_valid(en.get("root")):
		return
	var lead = party_n[0].root
	var dist = (lead.position - en.root.position).length()
	var reach = 3.3 if en.get("cls") == "halberd" else 2.5
	if dist > reach:
		_float_text(en.root.position, "💨 ПРОМАХ ВРАГА!", Color(0.8, 0.8, 0.8))
		en["atk_cd"] = 0.8
		return
	
	if is_hero_invulnerable():
		_float_text(lead.position, "💨 УВОРОТ (I-FRAME)!", Color(0.3, 0.95, 1.0))
		_screen_shake(0.02, 0.08)
		en["atk_cd"] = 0.8
		return
	
	var is_unb = bool(en.get("is_unblockable", false))
	var strike_dmg = 1.0
	
	# Assassin backstab bonus
	if en.get("cls") == "assassin":
		var hero_fwd = -lead.global_transform.basis.z
		hero_fwd.y = 0
		var to_en = (en.root.position - lead.position).normalized()
		to_en.y = 0
		if hero_fwd.dot(to_en) < -0.4:
			strike_dmg = 2.0
			_float_text(lead.position, "🔪 УДАР В СПИНУ!", Color(1.0, 0.2, 0.2))

	if fp_melee != null:
		var res = fp_melee.receive_hit(strike_dmg, en, is_unb)
		var result = str(res.get("result", "hit"))
		if result == "parry":
			_apply_parry_riposte(en)
			return
		elif result == "block":
			stamina = maxf(0.0, stamina - 16.0)
			stamina_cooldown = 0.6
			en["atk_cd"] = 1.2
			_float_text(lead.position, "🛡️ БЛОК!", Color(0.4, 0.8, 1.0))
			if parry_prompt_lbl != null:
				parry_prompt_lbl.text = "🛡️ УДАР ЗАБЛОКИРОВАН (-1)"
				parry_prompt_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
			_screen_shake(0.03, 0.08)
			return
		elif result == "guard_break":
			_float_text(lead.position, "❌ НЕЛЬЗЯ ЗАБЛОКИРОВАТЬ! СТАН!", Color(1.0, 0.15, 0.15))
			_screen_shake(0.1, 0.25)
	
	if Game.test_player_godmode:
		_float_text(lead.position, "🛡️ БЕССМЕРТИЕ (0 УРОНА)", Color(0.3, 1.0, 0.5))
		en["atk_cd"] = 1.0
		return

	var hero = party_n[0].m
	hero["hp"] = max(0, int(hero.get("hp", 2)) - int(strike_dmg))
	_float_text(lead.position, "-%d HP" % int(strike_dmg), Color(1.0, 0.25, 0.25))
	_update_party_hp_bars()
	_screen_shake(0.08, 0.2)
	if parry_prompt_lbl != null:
		parry_prompt_lbl.text = "💥 ПОЛУЧЕН УРОН!"
		parry_prompt_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	en["atk_cd"] = 1.4
	
	# Assassin combo follow-up chance
	if en.get("cls") == "assassin" and int(en.get("combo_step", 0)) == 0 and randf() < 0.55:
		en["combo_step"] = 1
		en["windup"] = 0.35
		en["windup_total"] = 0.35
		en["is_unblockable"] = false
		_float_text(en.root.position, "⚡ СЕРИЯ УДАРОВ!", Color(1.0, 0.8, 0.3))
		return
	else:
		en["combo_step"] = 0

	if int(hero.get("hp", 0)) <= 0:
		if Game.is_combat_test:
			hero["hp"] = int(hero.get("maxhp", 3))
			stamina = max_stamina
			is_defeated = false
			combat_lock = false
			_update_party_hp_bars()
			_float_text(lead.position, "✨ МГНОВЕННОЕ ВОЗРОЖДЕНИЕ (ТЕСТ-РЕЖИМ)!", Color(1.0, 0.9, 0.2))
			for nearby_en in enemies:
				nearby_en["windup"] = 0.0
				nearby_en["atk_cd"] = 1.2
				_update_enemy_status_display(nearby_en)
			return
		_handle_hero_death()

func _handle_hero_death():
	if Game.is_combat_test:
		if party_n.size() > 0:
			party_n[0].m["hp"] = int(party_n[0].m.get("maxhp", 3))
		stamina = max_stamina
		is_defeated = false
		combat_lock = false
		_update_party_hp_bars()
		return
	if party_n.size() == 0:
		_end_realtime_combat(false)
		return
	
	var fallen = party_n[0]
	var fallen_cid = str(fallen.m.get("char", ""))
	var fallen_name = str(CHARS.get(fallen_cid, {}).get("name", fallen.m.get("cls", "Герой")))
	if is_instance_valid(fallen.get("root")):
		_float_text(fallen.root.position, "💀 %s пал!" % fallen_name, Color(1.0, 0.2, 0.2))
	
	# Check if another living party member exists
	var found_next = false
	while party_n.size() > 1:
		var dead_node = party_n.pop_front()
		if is_instance_valid(dead_node.get("root")):
			var tw = dead_node.root.create_tween()
			tw.tween_property(dead_node.root, "scale", Vector3(0.05, 0.05, 0.05), 0.35)
			tw.finished.connect(func():
				if is_instance_valid(dead_node.root):
					dead_node.root.queue_free()
			)
		
		var next_hero = party_n[0]
		if int(next_hero.m.get("hp", 0)) > 0:
			found_next = true
			var next_cid = str(next_hero.m.get("char", ""))
			var next_name = str(CHARS.get(next_cid, {}).get("name", next_hero.m.get("cls", "Боец")))
			if is_instance_valid(next_hero.get("root")):
				_float_text(next_hero.root.position, "⚔️ В бой вступает %s!" % next_name, Color(1.0, 0.85, 0.3))
			if hint != null:
				hint.text = "Лидер пал! В бой вступает %s!" % next_name
			if fp_mode and is_instance_valid(next_hero.root):
				next_hero.root.visible = false
			_update_party_hp_bars()
			break
	
	if not found_next:
		is_defeated = true
		combat_lock = true
		if party_n.size() > 0 and is_instance_valid(party_n[0].get("root")):
			var tw = party_n[0].root.create_tween()
			tw.tween_property(party_n[0].root, "scale", Vector3(0.05, 0.05, 0.05), 0.35)
			# Do NOT queue_free() the leader on defeat!
		_end_realtime_combat(false)

func _end_realtime_combat(victory: bool):
	rt_combat_active = false
	_clean_up_projectiles()
	if parry_hud != null:
		parry_hud.modulate.a = 0.0
	for en in enemies:
		_hide_enemy_telegraph(en)
	if victory:
		combat_lock = false
		Game.flags["clear_" + loc_id] = true
		Game.clear_hook(loc_id)
		var ls = Game.loc_state_get(loc_id)
		ls["cleared_day"] = Game.day
		if hint != null:
			hint.text = "✨ ПОБЕДА! Все враги повержены."
		if Game.combat_mode == Game.CombatMode.REALTIME_FP:
			_set_fp_mode(true)
		else:
			_flyout_to_third_person()
	else:
		combat_lock = true
		is_defeated = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if fp_melee != null:
			fp_melee.visible = false
		if crosshair != null:
			crosshair.visible = false
		if hint != null:
			hint.text = "💀 Отряд повержен! Нажмите [M] для возвращения на карту."
		_show_defeat_overlay()

func _show_defeat_overlay():
	var old = get_node_or_null("DefeatUI")
	if old != null:
		old.queue_free()
	var ui_def = Control.new()
	ui_def.name = "DefeatUI"
	ui_def.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_def.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ui_def)
	
	var bg = ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.65)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_def.add_child(bg)
	
	var center = VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 16)
	ui_def.add_child(center)
	
	var lb = Label.new()
	lb.text = "💀 ПОРАЖЕНИЕ…"
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", 42)
	lb.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	center.add_child(lb)
	
	var sub = Label.new()
	sub.text = "Ваш отряд пал в бою от первого лица."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	center.add_child(sub)
	
	var btn_exit = Button.new()
	btn_exit.text = "🗺️ Вернуться на карту [M]"
	btn_exit.custom_minimum_size = Vector2(240, 44)
	btn_exit.pressed.connect(_apply_defeat_and_exit)
	center.add_child(btn_exit)

func _apply_defeat_and_exit():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if str(ConfigTools.get_val("defeat_mode", "town")) == "town":
		for m in Game.party:
			m["hp"] = 1
		Game.gold = int(Game.gold * 0.8)
	Game.clear_transient_state()
	get_tree().change_scene_to_file("res://overworld3d.tscn")

func _float_text(pos: Vector3, txt: String, col: Color):
	var lb = Label3D.new()
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.text = txt
	lb.pixel_size = 0.006
	lb.modulate = col
	lb.position = pos + Vector3(0, 1.8, 0)
	add_child(lb)
	var tw = create_tween()
	tw.tween_property(lb, "position:y", lb.position.y + 0.8, 0.8)
	tw.parallel().tween_property(lb, "modulate:a", 0.0, 0.8)
	tw.tween_callback(lb.queue_free)

func _start_combat():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var pts = []
	for pn in party_n:
		if is_instance_valid(pn.get("root")):
			pts.append([pn.root.position.x, pn.root.position.z])
	var valid_enemies = []
	for en in enemies:
		if is_instance_valid(en.get("root")) and int(en.get("hp", 1)) > 0:
			valid_enemies.append(en)
			pts.append([en.root.position.x, en.root.position.z])
	if valid_enemies.size() == 0:
		combat_lock = false
		return
	var cells = ExploreTools.snap_to_cells(pts, _is_free_cell)
	var players = []
	for i in party_n.size():
		var m = party_n[i].m
		players.append({"cell": cells[i], "cls": str(m.get("cls", "swordsman")), "char": str(m.get("char", "")), "hp": int(m.get("hp", 2)), "maxhp": int(m.get("maxhp", 2))})
	var en = []
	for i in valid_enemies.size():
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
		"cam_dist": 0.0 if fp_mode else cam_dist,
		"cam_offset_y": 1.4 if fp_mode else fp_cam_y,
		"fp_mode": fp_mode
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
	if (loc_id == "bandit_road" or loc_id == "road_bandits"):
		var cur_y = party_n[0].root.position.y if party_n.size() > 0 else 0.0
		var target_y = target_point.y if target_point != null else 0.0
		var gw = terrain.GW if terrain != null else 16
		var gh = terrain.GH if terrain != null else 10
		return CliffBridge.find_path_3d(from, cur_y, to, target_y, gw, gh, _is_free_cell)
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

func _spawn_test_enemy():
	if party_n.size() == 0 or not is_instance_valid(party_n[0].get("root")):
		return
	var lead = party_n[0].root
	var fwd = Vector3(-sin(yaw), 0, -cos(yaw))
	var spawn_pos = lead.position + fwd * 3.5
	var gw = (terrain.GW if terrain != null else 12)
	var gh = (terrain.GH if terrain != null else 12)
	spawn_pos.x = clampf(spawn_pos.x, 1.0, gw - 1.0)
	spawn_pos.z = clampf(spawn_pos.z, 1.0, gh - 1.0)
	spawn_pos.y = terrain.sample_h(spawn_pos.x, spawn_pos.z) if terrain != null else 0.0
	
	var cls = test_classes[test_spawn_class_idx % test_classes.size()]
	test_spawn_class_idx += 1
	var er = _actor(cls, Color(0.9, 0.25, 0.25), "")
	er.position = spawn_pos
	
	var en = {
		"root": er,
		"cls": cls
	}
	enemies.append(en)
	_setup_realtime_enemy(en, enemies.size())
	var name_ru = class_names_ru.get(cls, cls)
	_float_text(spawn_pos, "✨ СПАВН: %s" % name_ru, Color(0.4, 0.85, 1.0))
	_start_realtime_combat()
	_update_test_hud()

func _toggle_test_player_godmode():
	Game.test_player_godmode = not Game.test_player_godmode
	if party_n.size() > 0 and is_instance_valid(party_n[0].get("root")):
		var txt = "🛡️ БЕССМЕРТИЕ ИГРОКА: " + ("ВКЛ" if Game.test_player_godmode else "ВЫКЛ")
		var col = Color(0.3, 1.0, 0.4) if Game.test_player_godmode else Color(1.0, 0.4, 0.4)
		_float_text(party_n[0].root.position, txt, col)
	_update_test_hud()

func _toggle_test_enemy_godmode():
	Game.test_enemy_godmode = not Game.test_enemy_godmode
	if party_n.size() > 0 and is_instance_valid(party_n[0].get("root")):
		var txt = "👾 БЕССМЕРТИЕ ВРАГОВ: " + ("ВКЛ" if Game.test_enemy_godmode else "ВЫКЛ")
		var col = Color(0.3, 1.0, 0.4) if Game.test_enemy_godmode else Color(1.0, 0.4, 0.4)
		_float_text(party_n[0].root.position, txt, col)
	_update_test_hud()

func _restore_test_hero():
	if party_n.size() > 0:
		party_n[0].m["hp"] = int(party_n[0].m.get("maxhp", 3))
	stamina = max_stamina
	_update_party_hp_bars()
	if party_n.size() > 0 and is_instance_valid(party_n[0].get("root")):
		_float_text(party_n[0].root.position, "💖 ЗДОРОВЬЕ И ВЫНОСЛИВОСТЬ 100%", Color(0.2, 1.0, 0.5))
	_update_test_hud()

func _kill_all_enemies():
	var count = enemies.size()
	for en in enemies:
		if is_instance_valid(en.get("root")):
			_float_text(en.root.position, "💀 УСТРАНЁН", Color(1.0, 0.2, 0.2))
			en.root.queue_free()
	enemies.clear()
	_clean_up_projectiles()
	if party_n.size() > 0 and is_instance_valid(party_n[0].get("root")):
		_float_text(party_n[0].root.position, "💀 УНИЧТОЖЕНО ВРАГОВ: %d" % count, Color(1.0, 0.7, 0.2))
	if parry_hud != null:
		parry_hud.modulate.a = 0.0
	_update_test_hud()

func _unhandled_input(ev):
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_M:
		if is_defeated or (party_n.size() > 0 and int(party_n[0].m.get("hp", 0)) <= 0):
			_apply_defeat_and_exit()
			return
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Game.clear_transient_state()
		get_tree().change_scene_to_file("res://overworld3d.tscn")
		return
	if is_defeated:
		return
	if combat_lock and not rt_combat_active:
		return
	if party_n.size() == 0 or int(party_n[0].m.get("hp", 0)) <= 0:
		return
	if ev is InputEventKey and ev.pressed:
		if ev.keycode == KEY_V:
			if Game.combat_mode == Game.CombatMode.REALTIME_FP:
				if hint != null:
					hint.text = "В режиме реалтайм-боя зафиксирован вид от 1-го лица!"
				return
			_set_fp_mode(not fp_mode)
			return
		if ev.keycode == KEY_F and fp_mode:
			_try_fp_kick()
			return
		if ev.keycode == KEY_ALT and not ev.is_echo():
			_try_dash()
			get_viewport().set_input_as_handled()
			return
		if Game.is_combat_test:
			if ev.keycode == KEY_1:
				_spawn_test_enemy()
				return
			elif ev.keycode == KEY_2:
				_toggle_test_player_godmode()
				return
			elif ev.keycode == KEY_3:
				_toggle_test_enemy_godmode()
				return
			elif ev.keycode == KEY_4:
				_restore_test_hero()
				return
			elif ev.keycode == KEY_5:
				_kill_all_enemies()
				return
			elif ev.keycode == KEY_F1:
				if test_hud != null:
					test_hud.visible = not test_hud.visible
				return
		if ev.keycode == KEY_ESCAPE:
			if airship_state == 2:
				_exit_airship_helm()
				return
			if fp_mode and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
			if airship_state == 2:
				return
			_try_jump()
			return
		if ev.keycode == KEY_E:
			if airship != null:
				if airship_state == 2:
					_exit_airship_helm()
					return
				elif airship_state == 1:
					var lead_pos = party_n[0].root.global_position if party_n.size() > 0 else Vector3.ZERO
					var d_helm = (lead_pos - airship.get_helm_pos()).length()
					var d_ladder = (lead_pos - airship.get_ladder_top_pos(lead_pos)).length()
					if d_helm < 1.8:
						_enter_airship_helm()
						return
					elif d_ladder < 1.8:
						_exit_airship_to_ground()
						return
				elif airship_state == 0:
					var lead_pos = party_n[0].root.global_position if party_n.size() > 0 else Vector3.ZERO
					var d_ladder = (lead_pos - airship.get_ladder_bottom_pos(lead_pos)).length()
					if d_ladder < 2.5:
						_board_airship()
						return
			if fp_mode:
				_interact_ahead()
			else:
				_try_pick()
			return
	if ev is InputEventMouseButton:
		if is_defeated or party_n.size() == 0 or int(party_n[0].m.get("hp", 0)) <= 0:
			return
		if ev.button_index == MOUSE_BUTTON_RIGHT:
			if fp_mode and fp_melee != null:
				if ev.pressed:
					fp_melee.start_block()
					_try_rt_active_parry()
				else:
					fp_melee.stop_block()
			elif not fp_mode:
				right_drag = ev.pressed
		elif ev.button_index == MOUSE_BUTTON_MIDDLE:
			if not fp_mode:
				mid_drag = ev.pressed
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			if not fp_mode:
				var min_d = 4.0 if airship_state == 2 else 2.0
				var max_d = 16.0 if airship_state == 2 else 8.0
				cam_dist = clampf(cam_dist - 0.5, min_d, max_d)
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if not fp_mode:
				var min_d = 4.0 if airship_state == 2 else 2.0
				var max_d = 16.0 if airship_state == 2 else 8.0
				cam_dist = clampf(cam_dist + 0.5, min_d, max_d)
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if not ev.pressed:
				if fp_mode and fp_melee != null and fp_melee.is_charging():
					_release_fp_attack()
				return
			if airship_state != 0:
				if fp_mode:
					if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
						Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
					else:
						_interact_ahead()
				return
			if fp_mode:
				if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				else:
					if fp_melee != null and fp_melee.can_attack():
						_start_fp_attack()
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
				
				target_point = p
				var path = _find_path(from_c, dest_c)
				if path.size() > 0 or from_c == dest_c:
					current_path = path
				else:
					target_point = null
					current_path.clear()
					if hint != null:
						hint.text = "Сюда нельзя добраться!"
	elif ev is InputEventMouseMotion:
		if fp_mode and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			yaw -= ev.relative.x * 0.003
			pitch = clampf(pitch - ev.relative.y * 0.003, -1.4, 1.4)
			if fp_melee != null:
				fp_melee.set_mouse_delta(ev.relative)
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
	if (loc_id == "bandit_road" or loc_id == "road_bandits"):
		var p_surf = CliffBridge.raycast_surface(from, dir, terrain)
		if p_surf != null:
			return p_surf
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
	if k == "airship":
		_spawn_airship(p.x, p.z)
		return
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
