extends CombatModeBase
# РЕАЛТАЙМ-РЕЖИМ боя от 1-го лица (Game.CombatMode.REALTIME_FP = 0).
# Переключается на F6 прямо внутри боя; при выходе юниты привязываются обратно
# к клеткам, камера и мышь возвращаются сцене. HP, статусы и позиции юнитов
# принадлежат сцене (battle.units3) и потому переживают любое число переключений.
#
# Самовосстановление: enter() ставит active первым делом; process() каждый кадр
# возвращает захват мыши и флаг cam_ready, если переход камеры не завершился.

const FPMeleeClass = preload("res://scripts/combat/fp_melee.gd")

var rt_active = false
var rt_fp = null
var rt_ui: Control = null
var rt_hero_i = -1
var rt_cam_ready = false
var rt_saved_cam = {}
var rt_projectiles = []
var rt_stamina = 100.0
var rt_stamina_bar: ProgressBar = null
var rt_kills_lbl: Label = null
var rt_parry_hud: Control = null
var rt_parry_bar: ProgressBar = null
var rt_parry_lbl: Label = null
var rt_parry_zone: ColorRect = null
var rt_is_dashing = false
var rt_dash_timer = 0.0
var rt_dash_duration = 0.26
var rt_dash_dir = Vector3.ZERO
var rt_dash_cd = 0.0
var rt_iframe = 0.0

func can_enter() -> bool:
	return not (battle.game_over3 or battle.busy or battle.qte_on or battle.deploy_mode)

func block_reason() -> String:
	return "В реалтайм можно перейти только в свой ход (не в фазу врага и не в расстановку)."

func enter(_prev_mode: int) -> void:
	if rt_active or battle.game_over3:
		return
	rt_hero_i = _rt_pick_hero()
	if rt_hero_i < 0:
		return
	rt_active = true
	rt_cam_ready = false
	rt_is_dashing = false
	rt_stamina = battle.rt_stamina_saved
	rt_saved_cam = {"dist": battle.dist, "pitch": battle.pitch, "target": battle.target, "cam_offset_y": battle.cam_offset_y}
	battle.combat_ui_root.visible = false
	battle.hl_root.visible = false
	battle.hover_hl_root.visible = false
	_build_rt_ui()
	_rt_attach_fp()
	battle.units3[rt_hero_i].root.visible = false
	var eye = battle.units3[rt_hero_i].root.position + Vector3(0, 1.4, 0)
	if battle.cam_tween != null and battle.cam_tween.is_valid():
		battle.cam_tween.kill()
	battle.cam_tween = battle.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	battle.cam_tween.tween_property(battle, "dist", 0.02, 0.45)
	battle.cam_tween.tween_property(battle, "pitch", -0.05, 0.45)
	battle.cam_tween.tween_property(battle, "cam_offset_y", 0.0, 0.45)
	battle.cam_tween.tween_property(battle, "target", eye, 0.45)
	battle.cam_tween.chain().tween_callback(func(): rt_cam_ready = true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for u in battle.units3:
		if u.team == 1 and u.hp > 0 and is_instance_valid(u.root):
			_rt_setup_enemy(u)
	battle._log_units("rt_enter_done")

func exit() -> void:
	if not rt_active:
		return
	rt_active = false
	rt_is_dashing = false
	rt_iframe = 0.0
	_teardown_visuals()

func is_active() -> bool:
	return rt_active

# Полный возврат сцены в тактический вид: мышь, HUD режима, видимость юнитов,
# привязка к клеткам, камера. Вызывается из exit() и из концовок боя.
func _teardown_visuals():
	battle.rt_stamina_saved = rt_stamina
	rt_cam_ready = false
	battle._log_units("rt_teardown_before")
	_rt_clean_projectiles()
	if rt_fp != null and is_instance_valid(rt_fp):
		rt_fp.queue_free()
	rt_fp = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if rt_ui != null and is_instance_valid(rt_ui):
		rt_ui.visible = false
	for u in battle.units3:
		if u.team == 0 and u.hp > 0 and is_instance_valid(u.root):
			u.root.visible = true
	_rt_snap_units()
	var mn = Vector3(999, 0, 999)
	var mx = Vector3(-999, 0, -999)
	var any = false
	for u in battle.units3:
		if u.hp > 0 and is_instance_valid(u.root):
			any = true
			mn = mn.min(u.root.position)
			mx = mx.max(u.root.position)
	if battle.cam_tween != null and battle.cam_tween.is_valid():
		battle.cam_tween.kill()
	battle.cam_tween = battle.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	battle.cam_tween.tween_property(battle, "dist", float(rt_saved_cam.get("dist", 8.5)), 0.45)
	battle.cam_tween.tween_property(battle, "pitch", float(rt_saved_cam.get("pitch", -0.85)), 0.45)
	battle.cam_tween.tween_property(battle, "cam_offset_y", float(rt_saved_cam.get("cam_offset_y", 0.0)), 0.45)
	if any:
		var ct = (mn + mx) * 0.5
		ct.y = battle._th(Vector2i(int(floor(ct.x)), int(floor(ct.z))))
		battle.cam_tween.tween_property(battle, "target", ct, 0.45)
	else:
		battle.cam_tween.tween_property(battle, "target", rt_saved_cam.get("target", battle.target), 0.45)
	battle._log_units("rt_teardown_after")

func _rt_pick_hero() -> int:
	if battle.selected >= 0 and battle.selected < battle.units3.size():
		var u = battle.units3[battle.selected]
		if u.team == 0 and u.hp > 0 and is_instance_valid(u.root):
			return battle.selected
	return _rt_next_alive_hero()

func _rt_next_alive_hero() -> int:
	for i in battle.units3.size():
		var u = battle.units3[i]
		if u.team == 0 and u.hp > 0 and is_instance_valid(u.root):
			return i
	return -1

func _rt_next_hero():
	var prev = rt_hero_i
	# Тест-режим: мгновенное возрождение героя вместо поражения
	# (как в explore3d._handle_hero_death). Врагов это не воскресает.
	if Game.is_combat_test and prev >= 0 and prev < battle.units3.size() and is_instance_valid(battle.units3[prev].root):
		var hero = battle.units3[prev]
		hero.hp = int(hero.maxhp)
		battle._set_hp_bar(hero)
		rt_stamina = 100.0
		for e in battle.units3:
			if e.team == 1:
				e["rt_windup"] = 0.0
				e["rt_atk_cd"] = 1.2
		hero.root.visible = false
		battle._float_text(hero.root.position, "✨ МГНОВЕННОЕ ВОЗРОЖДЕНИЕ (ТЕСТ-РЕЖИМ)!", Color(1.0, 0.9, 0.2))
		return
	rt_hero_i = _rt_next_alive_hero()
	if rt_hero_i >= 0:
		if prev >= 0 and prev < battle.units3.size() and is_instance_valid(battle.units3[prev].root):
			battle.units3[prev].root.visible = battle.units3[prev].hp > 0
		battle.units3[rt_hero_i].root.visible = false
		battle._float_text(battle.units3[rt_hero_i].root.position, "⚔️ В бой вступает следующий боец!", Color(1.0, 0.85, 0.3))
		return
	# Живых бойцов не осталось — сворачиваем режим и отдаём исход боя сцене.
	rt_active = false
	_teardown_visuals()
	battle._check_end()

func _rt_attach_fp():
	# На камере должен быть ровно один FPMelee — чистим осиротевшие (например, после QTE-дуэли гибрида).
	for c in battle.cam.get_children():
		if c is FPMelee and c != rt_fp:
			c.queue_free()
	if rt_fp != null and is_instance_valid(rt_fp):
		rt_fp.queue_free()
	rt_fp = FPMeleeClass.new()
	battle.cam.add_child(rt_fp)
	rt_fp.attack_hit.connect(_rt_on_attack_hit)
	rt_fp.kick_hit.connect(_rt_on_kick_hit)
	rt_fp.parry_success.connect(_rt_on_parry)
	rt_fp.block_hit.connect(_rt_on_block)
	rt_fp.visible = true

func _build_rt_ui():
	if rt_ui != null and is_instance_valid(rt_ui):
		rt_ui.visible = true
		return
	rt_ui = Control.new()
	rt_ui.name = "RTUI"
	rt_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	rt_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle.add_child(rt_ui)
	var klbl = Label.new()
	klbl.anchor_left = 0.0
	klbl.anchor_right = 0.0
	klbl.anchor_top = 0.0
	klbl.anchor_bottom = 0.0
	klbl.offset_left = 8
	klbl.offset_right = 380
	klbl.offset_top = 6
	klbl.offset_bottom = 22
	klbl.add_theme_font_size_override("font_size", 11)
	klbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	klbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt_ui.add_child(klbl)
	rt_kills_lbl = klbl
	var cc = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt_ui.add_child(cc)
	var dot = ColorRect.new()
	dot.color = Color(1, 1, 1, 0.85)
	dot.custom_minimum_size = Vector2(4, 4)
	# Захваченная мышь держит позицию у центра экрана: любой STOP-контрол там
	# съест события мыши до _unhandled_input. Все элементы HUD — только IGNORE.
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(dot)
	rt_parry_hud = Control.new()
	rt_parry_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	rt_parry_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt_parry_hud.modulate.a = 0.0
	rt_ui.add_child(rt_parry_hud)
	rt_parry_zone = ColorRect.new()
	rt_parry_zone.color = Color(0.2, 0.85, 0.4, 0.45)
	rt_parry_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt_parry_zone.anchor_left = 0.5
	rt_parry_zone.anchor_right = 0.5
	rt_parry_zone.anchor_top = 0.64
	rt_parry_zone.anchor_bottom = 0.64
	rt_parry_zone.offset_left = -160
	rt_parry_zone.offset_right = 160
	rt_parry_zone.offset_top = 0
	rt_parry_zone.offset_bottom = 10
	rt_parry_hud.add_child(rt_parry_zone)
	rt_parry_bar = ProgressBar.new()
	rt_parry_bar.show_percentage = false
	rt_parry_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt_parry_bar.anchor_left = 0.5
	rt_parry_bar.anchor_right = 0.5
	rt_parry_bar.anchor_top = 0.64
	rt_parry_bar.anchor_bottom = 0.64
	rt_parry_bar.offset_left = -160
	rt_parry_bar.offset_right = 160
	rt_parry_bar.offset_top = 0
	rt_parry_bar.offset_bottom = 10
	rt_parry_hud.add_child(rt_parry_bar)
	rt_parry_lbl = Label.new()
	rt_parry_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt_parry_lbl.anchor_left = 0.5
	rt_parry_lbl.anchor_right = 0.5
	rt_parry_lbl.anchor_top = 0.58
	rt_parry_lbl.anchor_bottom = 0.58
	rt_parry_lbl.offset_left = -300
	rt_parry_lbl.offset_right = 300
	rt_parry_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rt_parry_lbl.add_theme_font_size_override("font_size", 15)
	rt_parry_hud.add_child(rt_parry_lbl)
	var sb = ProgressBar.new()
	sb.min_value = 0
	sb.max_value = 100
	sb.value = 100
	sb.show_percentage = false
	sb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sb.anchor_left = 0.5
	sb.anchor_right = 0.5
	sb.anchor_top = 1.0
	sb.anchor_bottom = 1.0
	sb.offset_left = -140
	sb.offset_right = 140
	sb.offset_top = -46
	sb.offset_bottom = -34
	rt_ui.add_child(sb)
	rt_stamina_bar = sb
	var hint = Label.new()
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -400
	hint.offset_right = 400
	hint.offset_top = -26
	hint.offset_bottom = -8
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.text = "⚔️ РЕАЛТАЙМ: ЛКМ удар | ПКМ блок/пари | F пинок | Alt рывок | F6 — в пошаговый | M — выход"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	rt_ui.add_child(hint)

func input(ev: InputEvent) -> bool:
	if ev is InputEventKey and ev.pressed:
		if ev.keycode == KEY_M:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			battle._leave_battle()
			return true
		if battle.game_over3:
			return false
		if Game.is_combat_test:
			if ev.keycode == KEY_2:
				Game.test_player_godmode = not Game.test_player_godmode
				if rt_hero_i >= 0 and rt_hero_i < battle.units3.size() and is_instance_valid(battle.units3[rt_hero_i].root):
					battle._float_text(battle.units3[rt_hero_i].root.position, "🛡️ БЕССМЕРТИЕ: %s" % ("ВКЛ" if Game.test_player_godmode else "ВЫКЛ"), Color(0.3, 1.0, 0.5))
				return true
			if ev.keycode == KEY_3:
				Game.test_enemy_godmode = not Game.test_enemy_godmode
				return true
			if ev.keycode == KEY_4:
				_rt_test_restore()
				return true
		if ev.keycode == KEY_F:
			_rt_try_kick()
			return true
		if ev.keycode == KEY_ALT and not ev.is_echo():
			_rt_try_dash()
			return true
		return false
	if battle.game_over3:
		return false
	if ev is InputEventMouseButton:
		if rt_fp == null:
			return false
		if ev.button_index == MOUSE_BUTTON_RIGHT:
			if ev.pressed:
				rt_fp.start_block()
				_rt_active_parry()
			else:
				rt_fp.stop_block()
			return true
		if ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				if rt_stamina >= 8.0 and rt_fp.can_attack():
					rt_fp.start_charge()
			else:
				if rt_fp.is_charging():
					var res = rt_fp.release_charge(_rt_alive_enemies())
					rt_stamina = maxf(0.0, rt_stamina - float(res.get("stamina_cost", 8.0)))
			return true
	elif ev is InputEventMouseMotion:
		yaw_look(ev.relative)
		return true
	return false

func yaw_look(rel: Vector2):
	battle.yaw -= rel.x * 0.003
	battle.pitch = clampf(battle.pitch - rel.y * 0.003, -1.3, 0.7)
	if rt_fp != null:
		rt_fp.set_mouse_delta(rel)

func process(d: float) -> void:
	if battle.game_over3:
		return
	# Самовосстановление: захват мыши и переход камеры не должны «отваливаться».
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not rt_cam_ready and (battle.cam_tween == null or not battle.cam_tween.is_valid() or not battle.cam_tween.is_running()):
		rt_cam_ready = true
	if rt_hero_i < 0 or rt_hero_i >= battle.units3.size() or not is_instance_valid(battle.units3[rt_hero_i].root) or battle.units3[rt_hero_i].hp <= 0:
		_rt_next_hero()
		if rt_hero_i < 0:
			return
	var hero = battle.units3[rt_hero_i]
	rt_dash_cd = maxf(0.0, rt_dash_cd - d)
	rt_iframe = maxf(0.0, rt_iframe - d)
	rt_stamina = minf(100.0, rt_stamina + 26.0 * d)
	var fwd = Vector3(-sin(battle.yaw), 0, -cos(battle.yaw))
	var right = Vector3(cos(battle.yaw), 0, -sin(battle.yaw))
	var mv = Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		mv += fwd
	if Input.is_physical_key_pressed(KEY_S):
		mv -= fwd
	if Input.is_physical_key_pressed(KEY_D):
		mv += right
	if Input.is_physical_key_pressed(KEY_A):
		mv -= right
	var sprint = Input.is_physical_key_pressed(KEY_SHIFT) and rt_stamina > 1.0
	if rt_is_dashing:
		rt_dash_timer -= d
		var prog = clampf(rt_dash_timer / maxf(0.01, rt_dash_duration), 0.0, 1.0)
		_rt_move_root(hero.root, rt_dash_dir, lerpf(3.5, 12.5, prog) * d, rt_hero_i)
		if rt_dash_timer <= 0.0:
			rt_is_dashing = false
	elif mv.length_squared() > 0.0001:
		if sprint:
			rt_stamina = maxf(0.0, rt_stamina - 20.0 * d)
		_rt_move_root(hero.root, mv.normalized(), 3.6 * (1.6 if sprint else 1.0) * d, rt_hero_i)
	_rt_settle_y(hero.root, rt_hero_i, d)
	hero.cell = Vector2i(int(floor(hero.root.position.x)), int(floor(hero.root.position.z)))
	if rt_cam_ready:
		battle.yaw_n.position = hero.root.position + Vector3(0, 1.4, 0)
		battle.yaw_n.rotation = Vector3(0, battle.yaw, 0)
		battle.pitch_n.rotation = Vector3(battle.pitch, 0, 0)
		battle.cam.position = Vector3(0, 0, 0.02)
	else:
		battle._apply()
	_rt_enemies_tick(d)
	_rt_projectiles_tick(d)
	if rt_stamina_bar != null:
		rt_stamina_bar.value = rt_stamina
	if rt_kills_lbl != null and is_instance_valid(rt_kills_lbl):
		rt_kills_lbl.text = battle._kills_text() + battle._test_text()

func _rt_settle_y(root: Node3D, i: int, d: float):
	var c = Vector2i(int(floor(root.position.x)), int(floor(root.position.z)))
	var ty = battle._th(c, i)
	root.position.y = move_toward(root.position.y, ty, 6.0 * d)

func _rt_move_root(root: Node3D, dir: Vector3, step: float, u_i: int, allow_drop: bool = false) -> bool:
	if step <= 0.0 or dir.length_squared() < 0.0001:
		return false
	var flat = Vector3(dir.x, 0, dir.z).normalized()
	if _rt_move_clamped(root, flat, step, u_i, allow_drop):
		return true
	var side = Vector3(-flat.z, 0, flat.x)
	if _rt_move_clamped(root, side, step, u_i, allow_drop):
		return true
	if _rt_move_clamped(root, -side, step, u_i, allow_drop):
		return true
	return false

func _rt_move_clamped(root: Node3D, dir: Vector3, step: float, u_i: int, allow_drop: bool = false) -> bool:
	var np = root.position + dir * step
	var gw = battle.terrain.GW if battle.terrain != null else 16
	var gh = battle.terrain.GH if battle.terrain != null else 10
	np.x = clampf(np.x, 0.3, gw - 0.3)
	np.z = clampf(np.z, 0.3, gh - 0.3)
	var cc = Vector2i(int(floor(root.position.x)), int(floor(root.position.z)))
	var nc = Vector2i(int(floor(np.x)), int(floor(np.z)))
	if nc != cc:
		if battle.terrain != null and not battle.terrain.has_cell(nc.x, nc.y):
			return false
		if battle.objects3.has(nc):
			return false
		if allow_drop:
			# Погоне разрешён спуск с уступа (вверх — только по легальным ступеням),
			# иначе враги, заспавненные на высотах, застревают там на весь бой.
			if battle._th(nc, u_i) > root.position.y + 0.85:
				return false
		elif not battle._can_step(cc, nc, u_i):
			return false
	root.position = np
	return true

func _rt_alive_enemies() -> Array:
	var res = []
	for u in battle.units3:
		if u.team == 1 and u.hp > 0 and is_instance_valid(u.root):
			res.append(u)
	return res

func _rt_setup_enemy(u: Dictionary):
	u["rt_windup"] = 0.0
	u["rt_windup_total"] = 0.75
	u["rt_atk_cd"] = 0.6 + randf() * 0.8
	u["rt_is_blocking"] = false
	u["rt_block_timer"] = 0.0
	u["rt_block_cd"] = randf_range(1.5, 3.5)
	u["rt_stagger"] = 0.0
	u["rt_strafe_dir"] = 1.0 if randf() > 0.5 else -1.0
	u["rt_knocked"] = 0.0
	u["rt_unblockable"] = false
	if u.cls == "archer":
		u["rt_state"] = "reload"
		u["rt_state_t"] = randf_range(1.2, 2.2)
	elif u.cls == "mage":
		u["rt_state"] = "cast"
		u["rt_state_t"] = randf_range(1.4, 2.4)

func _rt_enemies_tick(d):
	var hero = battle.units3[rt_hero_i] if rt_hero_i >= 0 and rt_hero_i < battle.units3.size() else null
	if hero == null or not is_instance_valid(hero.root):
		return
	var hpos = hero.root.position
	var charging = rt_fp != null and rt_fp.is_charging()
	var active_windups = 0
	var min_windup = null
	var min_rem = 999.0
	for i in battle.units3.size():
		var u = battle.units3[i]
		if u.team != 1 or u.hp <= 0 or not is_instance_valid(u.root):
			continue
		var er = u.root
		if float(u.get("rt_knocked", 0.0)) > 0.0:
			u["rt_knocked"] = maxf(0.0, float(u["rt_knocked"]) - d)
			continue
		var to_h = hpos - er.position
		to_h.y = 0
		var dist_h = to_h.length()
		u.cell = Vector2i(int(floor(er.position.x)), int(floor(er.position.z)))
		_rt_settle_y(er, i, d)
		var stag = float(u.get("rt_stagger", 0.0))
		if stag > 0.0:
			u["rt_stagger"] = maxf(0.0, stag - d)
			continue
		var bcd = float(u.get("rt_block_cd", 0.0))
		if bcd > 0.0:
			u["rt_block_cd"] = maxf(0.0, bcd - d)
		if bool(u.get("rt_is_blocking", false)):
			u["rt_block_timer"] = float(u.get("rt_block_timer", 0.0)) - d
			if float(u["rt_block_timer"]) <= 0.0:
				u["rt_is_blocking"] = false
				u["rt_block_cd"] = randf_range(2.0, 3.5)
			continue
		var wu = float(u.get("rt_windup", 0.0))
		if wu > 0.0:
			active_windups += 1
			if wu < min_rem:
				min_rem = wu
				min_windup = u
			u["rt_windup"] = maxf(0.0, wu - d)
			if float(u["rt_windup"]) <= 0.0:
				_rt_enemy_strike(u)
			continue
		if charging and dist_h <= 3.2 and float(u.get("rt_block_cd", 0.0)) <= 0.0 and (u.cls == "swordsman" or u.cls == "assassin" or u.cls == "halberd") and randf() < 0.7:
			u["rt_is_blocking"] = true
			u["rt_block_timer"] = randf_range(1.6, 2.4)
			battle._float_text(er.position, "🛡️ БЛОК!", Color(0.4, 0.85, 1.0))
			continue
		var acd = float(u.get("rt_atk_cd", 0.0))
		if acd > 0.0:
			u["rt_atk_cd"] = maxf(0.0, acd - d)
		if u.cls == "archer":
			if dist_h < 5.0:
				_rt_move_root(er, -to_h.normalized(), 3.0 * d, i)
			elif dist_h > 9.5:
				_rt_move_root(er, to_h.normalized(), 2.0 * d, i, true)
			var st = str(u.get("rt_state", "reload"))
			u["rt_state_t"] = float(u.get("rt_state_t", 2.0)) - d
			if st == "reload":
				if float(u["rt_state_t"]) <= 0.0:
					u["rt_state"] = "aim"
					u["rt_state_t"] = 0.7
			elif st == "aim":
				if float(u["rt_state_t"]) <= 0.0:
					_rt_spawn_arrow(u, hpos + Vector3(0, 1.0, 0))
					u["rt_state"] = "reload"
					u["rt_state_t"] = 2.5
			else:
				u["rt_state"] = "reload"
				u["rt_state_t"] = 2.5
		elif u.cls == "mage":
			if dist_h < 4.5:
				_rt_move_root(er, -to_h.normalized(), 2.5 * d, i)
			elif dist_h > 9.0:
				_rt_move_root(er, to_h.normalized(), 1.8 * d, i, true)
			var st = str(u.get("rt_state", "cast"))
			u["rt_state_t"] = float(u.get("rt_state_t", 2.5)) - d
			if st == "cast":
				if float(u["rt_state_t"]) <= 0.0:
					_rt_spawn_fireball(u, hpos + Vector3(0, 1.0, 0))
					u["rt_state_t"] = 2.8
			else:
				u["rt_state"] = "cast"
				u["rt_state_t"] = 2.8
		elif u.cls == "assassin":
			if dist_h > 1.5:
				var f = to_h.normalized()
				var side = Vector3(-f.z, 0, f.x) * float(u.get("rt_strafe_dir", 1.0))
				if randf() < 0.02:
					u["rt_strafe_dir"] = -float(u.get("rt_strafe_dir", 1.0))
				_rt_move_root(er, (f * 0.7 + side * 0.75).normalized(), 3.6 * d, i, true)
			elif float(u.get("rt_atk_cd", 0.0)) <= 0.0:
				if active_windups == 0:
					u["rt_windup"] = 0.45
					u["rt_windup_total"] = 0.45
					u["rt_unblockable"] = false
					active_windups += 1
				else:
					u["rt_atk_cd"] = randf_range(0.4, 0.8)
		elif u.cls == "halberd":
			if dist_h > 2.8:
				_rt_move_root(er, to_h.normalized(), 2.0 * d, i, true)
			elif dist_h < 2.0:
				_rt_move_root(er, -to_h.normalized(), 1.6 * d, i)
			if dist_h <= 3.0 and float(u.get("rt_atk_cd", 0.0)) <= 0.0:
				if active_windups == 0:
					var unb = randf() < 0.45
					u["rt_unblockable"] = unb
					u["rt_windup"] = 0.85 if unb else 0.65
					u["rt_windup_total"] = float(u["rt_windup"])
					active_windups += 1
				else:
					u["rt_atk_cd"] = randf_range(0.6, 1.2)
		else:
			if dist_h > 1.6:
				_rt_move_root(er, to_h.normalized(), 2.3 * d, i, true)
			elif float(u.get("rt_atk_cd", 0.0)) <= 0.0:
				if active_windups == 0:
					u["rt_windup"] = 0.75
					u["rt_windup_total"] = 0.75
					u["rt_unblockable"] = false
					active_windups += 1
				else:
					u["rt_atk_cd"] = randf_range(0.5, 1.1)
	_rt_update_parry_hud(min_windup, min_rem, d)

func _rt_update_parry_hud(min_windup, min_rem, d):
	if rt_parry_hud == null or not is_instance_valid(rt_parry_hud):
		return
	if min_windup != null:
		rt_parry_hud.modulate.a = move_toward(rt_parry_hud.modulate.a, 1.0, d * 8.0)
		var w_total = float(min_windup.get("rt_windup_total", 0.75))
		var progress = clampf(1.0 - (min_rem / maxf(0.01, w_total)), 0.0, 1.0)
		rt_parry_bar.value = progress
		if bool(min_windup.get("rt_unblockable", false)):
			rt_parry_lbl.text = "💥 НЕБЛОКИРУЕМЫЙ! ОТПРЫГИВАЙ [ALT]!"
			rt_parry_lbl.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
			rt_parry_zone.color = Color(1.0, 0.15, 0.15, 0.8)
		elif progress >= 0.5:
			rt_parry_lbl.text = "🛡️ ЖМИ ПКМ! ОКНО ПАРИРОВАНИЯ!"
			rt_parry_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45))
			rt_parry_zone.color = Color(0.3, 1.0, 0.5, 0.75)
		else:
			rt_parry_lbl.text = "⚠️ ВРАГ ЗАМАХНУЛСЯ..."
			rt_parry_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
			rt_parry_zone.color = Color(0.2, 0.85, 0.4, 0.45)
	else:
		rt_parry_hud.modulate.a = move_toward(rt_parry_hud.modulate.a, 0.0, d * 3.5)

func _rt_enemy_strike(u: Dictionary):
	if battle.game_over3 or rt_hero_i < 0 or rt_hero_i >= battle.units3.size():
		return
	var hero = battle.units3[rt_hero_i]
	if hero.hp <= 0 or not is_instance_valid(hero.root) or not is_instance_valid(u.root):
		return
	var dist_h = (hero.root.position - u.root.position).length()
	var reach = 3.3 if u.cls == "halberd" else 2.5
	if dist_h > reach:
		battle._float_text(u.root.position, "💨 ПРОМАХ ВРАГА!", Color(0.8, 0.8, 0.8))
		u["rt_atk_cd"] = 0.8
		return
	u["rt_atk_cd"] = 1.2
	if rt_iframe > 0.0:
		battle._float_text(hero.root.position, "💨 УВОРОТ (РЫВОК)!", Color(0.3, 0.95, 1.0))
		return
	if Game.test_player_godmode:
		battle._float_text(hero.root.position, "🛡️ БЕССМЕРТИЕ (0 УРОНА)", Color(0.3, 1.0, 0.5))
		return
	var dmg = 1.0
	if u.cls == "assassin":
		var hf = Vector3(-sin(battle.yaw), 0, -cos(battle.yaw))
		var to_e = (u.root.position - hero.root.position).normalized()
		if hf.dot(to_e) < -0.4:
			dmg = 2.0
			battle._float_text(hero.root.position, "🔪 УДАР В СПИНУ!", Color(1.0, 0.2, 0.2))
	if rt_fp != null:
		var res = rt_fp.receive_hit(dmg, u, bool(u.get("rt_unblockable", false)))
		var r = str(res.get("result", "hit"))
		if r == "parry":
			_rt_riposte(u)
			return
		if r == "block":
			rt_stamina = maxf(0.0, rt_stamina - 16.0)
			u["rt_atk_cd"] = 1.2
			battle._float_text(hero.root.position, "🛡️ БЛОК!", Color(0.4, 0.8, 1.0))
			return
		if r == "guard_break":
			battle._float_text(hero.root.position, "❌ НЕЛЬЗЯ ЗАБЛОКИРОВАТЬ!", Color(1.0, 0.15, 0.15))
	hero.hp = hero.hp - int(dmg)
	battle._set_hp_bar(hero)
	battle._float_text(hero.root.position, "-%d HP" % int(dmg), Color(1.0, 0.25, 0.25))
	if hero.hp <= 0:
		hero.root.visible = false
		_rt_next_hero()

func _rt_riposte(u):
	if u == null or not (u is Dictionary) or not u.has("hp") or u.hp <= 0:
		return
	u["rt_windup"] = 0.0
	u["rt_stagger"] = 2.0
	var dmg = 2
	if Game.test_enemy_godmode:
		u.hp = maxi(1, u.hp - dmg)
	else:
		u.hp = u.hp - dmg
	if is_instance_valid(u.get("root")):
		battle._float_text(u.root.position, "✨ ПАРИРОВАНИЕ! -%d" % dmg, Color(1.0, 0.88, 0.25))
	battle._set_hp_bar(u)
	if u.hp <= 0:
		_rt_enemy_dead(u)

func _rt_on_parry(attacker):
	_rt_riposte(attacker)

func _rt_on_block(_attacker, absorbed):
	rt_stamina = maxf(0.0, rt_stamina - 15.0)
	if rt_hero_i >= 0 and rt_hero_i < battle.units3.size() and is_instance_valid(battle.units3[rt_hero_i].root):
		battle._float_text(battle.units3[rt_hero_i].root.position, "🛡️ БЛОК! (-%d)" % int(absorbed), Color(0.4, 0.8, 1.0))

func _rt_on_attack_hit(u, damage, is_crit, is_heavy = false):
	if u == null or not (u is Dictionary) or not u.has("hp"):
		return
	if not is_instance_valid(u.get("root")):
		return
	if bool(u.get("rt_is_blocking", false)):
		if u.cls == "assassin":
			_rt_assassin_counter()
		elif u.cls == "halberd":
			_rt_halberd_push(u.root.position)
		else:
			battle._float_text(u.root.position, "🛡️ ЗАБЛОКИРОВАНО ВРАГОМ!", Color(0.4, 0.85, 1.0))
			u["rt_atk_cd"] = 0.3
		return
	var dmg = int(damage)
	if Game.test_enemy_godmode:
		u.hp = maxi(1, u.hp - dmg)
	else:
		u.hp = u.hp - dmg
	if is_heavy:
		u["rt_stagger"] = 1.4
		u["rt_windup"] = 0.0
	var txt = "⚔️ -%d" % dmg
	var col = Color(1.0, 0.35, 0.35)
	if is_heavy:
		txt = "💥 СИЛЬНЫЙ УДАР! -%d" % dmg
		col = Color(1.0, 0.55, 0.15)
	elif is_crit:
		txt = "✨ КРИТ! -%d" % dmg
		col = Color(1.0, 0.85, 0.2)
	battle._float_text(u.root.position, txt, col)
	battle._set_hp_bar(u)
	if rt_hero_i >= 0 and rt_hero_i < battle.units3.size() and is_instance_valid(battle.units3[rt_hero_i].root):
		var dir = u.root.position - battle.units3[rt_hero_i].root.position
		dir.y = 0
		if dir.length_squared() > 0.0001:
			_rt_move_root(u.root, dir.normalized(), 0.6 if is_heavy else 0.35, battle.units3.find(u))
	if u.hp <= 0:
		_rt_enemy_dead(u)

func _rt_on_kick_hit(u):
	if u == null or not (u is Dictionary) or not u.has("hp"):
		return
	if not is_instance_valid(u.get("root")):
		return
	var was_block = bool(u.get("rt_is_blocking", false))
	u["rt_is_blocking"] = false
	u["rt_windup"] = 0.0
	u["rt_stagger"] = 2.0 if was_block else 1.6
	u["rt_atk_cd"] = 1.4
	if Game.test_enemy_godmode:
		u.hp = maxi(1, u.hp - 1)
	else:
		u.hp = u.hp - 1
	battle._float_text(u.root.position, "💥 БЛОК ПРОБИТ ПИНКОМ!" if was_block else "🦶 ПИНОК!", Color(1.0, 0.85, 0.2))
	battle._set_hp_bar(u)
	if rt_hero_i >= 0 and rt_hero_i < battle.units3.size() and is_instance_valid(battle.units3[rt_hero_i].root):
		var dir = u.root.position - battle.units3[rt_hero_i].root.position
		dir.y = 0
		if dir.length_squared() > 0.0001:
			_rt_move_root(u.root, dir.normalized(), 2.2, battle.units3.find(u))
	if u.hp <= 0:
		_rt_enemy_dead(u)

func _rt_assassin_counter():
	if rt_hero_i < 0 or rt_hero_i >= battle.units3.size():
		return
	var hero = battle.units3[rt_hero_i]
	if not is_instance_valid(hero.root):
		return
	if Game.test_player_godmode:
		battle._float_text(hero.root.position, "🛡️ БЕССМЕРТИЕ (0 УРОНА)", Color(0.3, 1.0, 0.5))
		return
	hero.hp = maxi(0, hero.hp - 1)
	battle._set_hp_bar(hero)
	battle._float_text(hero.root.position, "🗡️ КОНТРПАРИРОВАНИЕ ВРАГА! -1 HP", Color(1.0, 0.45, 0.2))
	if hero.hp <= 0:
		hero.root.visible = false
		_rt_next_hero()

func _rt_halberd_push(from_pos: Vector3):
	if rt_hero_i < 0 or rt_hero_i >= battle.units3.size():
		return
	var hero = battle.units3[rt_hero_i]
	if not is_instance_valid(hero.root):
		return
	var dir = hero.root.position - from_pos
	dir.y = 0
	if dir.length_squared() < 0.0001:
		dir = Vector3(0, 0, 1)
	_rt_move_root(hero.root, dir.normalized(), 1.5, rt_hero_i)
	battle._float_text(hero.root.position, "💨 ТОЛЧОК!", Color(0.7, 0.85, 1.0))

func _rt_try_kick():
	if rt_fp == null or rt_stamina < 10.0:
		return
	rt_stamina = maxf(0.0, rt_stamina - 10.0)
	rt_fp.try_kick(_rt_alive_enemies())

func _rt_test_restore():
	if rt_hero_i < 0 or rt_hero_i >= battle.units3.size():
		return
	var hero = battle.units3[rt_hero_i]
	hero.hp = int(hero.maxhp)
	battle._set_hp_bar(hero)
	rt_stamina = 100.0
	if is_instance_valid(hero.root):
		battle._float_text(hero.root.position, "💖 HP И СТАМИНА ВОССТАНОВЛЕНЫ", Color(0.2, 1.0, 0.5))

func _rt_try_dash():
	if rt_is_dashing or rt_dash_cd > 0.0 or rt_stamina < 10.0:
		return
	var fwd = Vector3(-sin(battle.yaw), 0, -cos(battle.yaw))
	var right = Vector3(cos(battle.yaw), 0, -sin(battle.yaw))
	var mv = Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		mv += fwd
	if Input.is_physical_key_pressed(KEY_S):
		mv -= fwd
	if Input.is_physical_key_pressed(KEY_D):
		mv += right
	if Input.is_physical_key_pressed(KEY_A):
		mv -= right
	if mv.length_squared() < 0.0001:
		mv = fwd
	rt_dash_dir = mv.normalized()
	rt_is_dashing = true
	rt_dash_timer = rt_dash_duration
	rt_dash_cd = 0.35
	rt_iframe = 0.26
	rt_stamina = maxf(0.0, rt_stamina - 10.0)

func _rt_active_parry():
	if rt_hero_i < 0 or rt_hero_i >= battle.units3.size():
		return
	var hero = battle.units3[rt_hero_i]
	if not is_instance_valid(hero.root):
		return
	for u in _rt_alive_enemies():
		var wu = float(u.get("rt_windup", 0.0))
		var reach = 3.9 if u.cls == "halberd" else 3.2
		if wu > 0.0 and wu <= 0.45 and not bool(u.get("rt_unblockable", false)) and (hero.root.position - u.root.position).length() <= reach:
			_rt_riposte(u)
			return

func _rt_enemy_dead(u: Dictionary):
	if u.hp > 0:
		return
	if not bool(u.get("rt_kill_counted", false)):
		u["rt_kill_counted"] = true
		battle._count_kill(u)
	if is_instance_valid(u.root):
		u.root.visible = false
	battle._set_hp_bar(u)
	var any = false
	for e in battle.units3:
		if e.team == 1 and e.hp > 0:
			any = true
			break
	if not any:
		rt_active = false
		_teardown_visuals()
	battle._check_end()

func _rt_spawn_arrow(u: Dictionary, target_pos: Vector3):
	if not is_instance_valid(u.get("root")):
		return
	var origin = u.root.position + Vector3(0, 1.25, 0)
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
	battle.add_child(node)
	if dir.length_squared() > 0.001:
		node.look_at(origin + dir, Vector3.UP)
	rt_projectiles.append({"node": node, "type": "arrow", "pos": origin, "dir": dir, "speed": 14.0, "damage": 1, "lifetime": 3.0})
	battle._float_text(origin, "🏹 ВЫСТРЕЛ!", Color(0.5, 0.9, 0.5))

func _rt_spawn_fireball(u: Dictionary, target_pos: Vector3):
	if not is_instance_valid(u.get("root")):
		return
	var origin = u.root.position + Vector3(0, 1.25, 0)
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
	battle.add_child(node)
	rt_projectiles.append({"node": node, "type": "fireball", "pos": origin, "dir": dir, "speed": 7.0, "damage": 1, "lifetime": 3.5})
	battle._float_text(origin, "🔥 ОГНЕННЫЙ ШАР!", Color(1.0, 0.5, 0.2))

func _rt_projectiles_tick(d):
	if rt_hero_i < 0 or rt_hero_i >= battle.units3.size() or not is_instance_valid(battle.units3[rt_hero_i].root):
		return
	var hero_pos = battle.units3[rt_hero_i].root.position + Vector3(0, 1.0, 0)
	for i in range(rt_projectiles.size() - 1, -1, -1):
		var p = rt_projectiles[i]
		if not is_instance_valid(p.get("node")):
			rt_projectiles.remove_at(i)
			continue
		p["pos"] += p["dir"] * float(p["speed"]) * d
		p["node"].position = p["pos"]
		p["lifetime"] -= d
		if (p["pos"] - hero_pos).length() < 0.85:
			_rt_hero_hit_by_projectile(p)
			if is_instance_valid(p["node"]):
				p["node"].queue_free()
			rt_projectiles.remove_at(i)
			continue
		if float(p["lifetime"]) <= 0.0:
			if is_instance_valid(p["node"]):
				p["node"].queue_free()
			rt_projectiles.remove_at(i)

func _rt_hero_hit_by_projectile(p):
	if battle.game_over3 or rt_hero_i < 0 or rt_hero_i >= battle.units3.size():
		return
	var hero = battle.units3[rt_hero_i]
	if hero.hp <= 0 or not is_instance_valid(hero.root):
		return
	if rt_iframe > 0.0:
		battle._float_text(hero.root.position, "💨 УВОРОТ!", Color(0.3, 0.95, 1.0))
		return
	if rt_fp != null and rt_fp.is_blocking():
		rt_stamina = maxf(0.0, rt_stamina - 14.0)
		battle._float_text(hero.root.position, "🛡️ ЗАБЛОКИРОВАНО!", Color(0.4, 0.85, 1.0))
		return
	if Game.test_player_godmode:
		battle._float_text(hero.root.position, "🛡️ БЕССМЕРТИЕ (0 УРОНА)", Color(0.3, 1.0, 0.5))
		return
	var dmg = int(p.get("damage", 1))
	hero.hp = hero.hp - dmg
	battle._set_hp_bar(hero)
	battle._float_text(hero.root.position, "-%d HP" % dmg, Color(1.0, 0.3, 0.3))
	if hero.hp <= 0:
		hero.root.visible = false
		_rt_next_hero()

func _rt_clean_projectiles():
	for p in rt_projectiles:
		if is_instance_valid(p.get("node")):
			p["node"].queue_free()
	rt_projectiles.clear()

func _rt_snap_units():
	var taken = {}
	for u in battle.units3:
		if not is_instance_valid(u.root) or u.hp <= 0:
			continue
		var c0 = Vector2i(int(floor(u.root.position.x)), int(floor(u.root.position.z)))
		var c = _rt_free_cell_near(c0, taken)
		taken[c] = true
		u.cell = c
		u.root.position = battle._p(c) + Vector3(0, battle._th(c, battle.units3.find(u)), 0)

func _rt_free_cell_near(c0: Vector2i, taken: Dictionary) -> Vector2i:
	if _rt_cell_free(c0, taken):
		return c0
	for r in range(1, 5):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(abs(dx), abs(dy)) != r:
					continue
				var c = c0 + Vector2i(dx, dy)
				if _rt_cell_free(c, taken):
					return c
	return c0

func _rt_cell_free(c: Vector2i, taken: Dictionary) -> bool:
	if taken.has(c):
		return false
	if battle.terrain != null and not battle.terrain.has_cell(c.x, c.y):
		return false
	if battle.objects3.has(c):
		return false
	return true
