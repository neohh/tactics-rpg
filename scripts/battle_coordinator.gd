class_name BattleCoordinator
extends Node

# BattleCoordinator — связывает состояние, юнитов, правила и ИИ.
# Он не рисует 3D-модели напрямую, но управляет логикой боя.

signal status_message(text)
signal phase_changed(phase)
signal activations_changed(left)
signal unit_damaged(idx, amount)
signal unit_died(idx)
signal unit_healed(idx, amount)
signal unit_status_changed(idx, status, value)
signal intent_started(intent)
signal intent_finished(intent)
signal fire_added(fire)
signal fires_updated(fires)
signal battle_finished(winner)

var state = null
var units = null
var classes = {}
var environment = {}

func _ready():
	var ss = load("res://scripts/battle_state_manager.gd")
	var us = load("res://scripts/unit_manager.gd")
	if ss == null or us == null:
		push_error("BattleCoordinator: manager scripts not found")
		return
	state = ss.new()
	add_child(state)
	units = us.new()
	add_child(units)
	state.phase_changed.connect(func(p): phase_changed.emit(p))
	state.activations_changed.connect(func(l): activations_changed.emit(l))
	state.game_over_signal.connect(func(w): battle_finished.emit(w))
	units.unit_damaged.connect(func(i, a): unit_damaged.emit(i, a))
	units.unit_died.connect(func(i): unit_died.emit(i))
	units.unit_healed.connect(func(i, a): unit_healed.emit(i, a))
	units.unit_status_changed.connect(func(i, s, v): unit_status_changed.emit(i, s, v))

func setup(classes_data, env):
	classes = classes_data
	environment = {
		"gw": int(env.get("gw", 8)),
		"gh": int(env.get("gh", 6)),
		"objects": env.get("objects", []),
		"elev": env.get("elev", {}),
		"heights": env.get("heights", {}),
		"fires": env.get("fires", [])
	}
	if state != null:
		state.start_deploy()

func add_unit(data):
	var d = data.duplicate(true)
	if not d.has("hp"):
		d["hp"] = 2
	if not d.has("maxhp"):
		d["maxhp"] = int(d["hp"])
	if not d.has("facing"):
		d["facing"] = Vector2(1, 0)
	if not d.has("team"):
		d["team"] = 1
	if not d.has("cell"):
		d["cell"] = Vector2i.ZERO
	d["cls_data"] = classes.get(str(d.get("cls", "")), {})
	d["moved"] = false
	d["attacked"] = false
	d["spent"] = false
	d["acts"] = 0
	d["acted_prev"] = false
	d["tired"] = false
	d["fresh"] = false
	return units.add_unit(d)

func start_battle():
	if state != null:
		state.start_player_turn()
	status_message.emit("Твой ход: клик по своему юниту.")

func can_player_act():
	return state != null and state.can_act()

func get_unit(idx):
	if units == null:
		return {}
	return units.get_unit(idx)

func try_select(idx):
	var u = get_unit(idx)
	if u.is_empty() or int(u.get("hp", 0)) <= 0 or int(u.get("team", -1)) != 0:
		return false
	if state == null or not state.is_player_turn():
		return false
	if state.activations_left <= 0 and int(u.get("acts", 0)) == 0:
		status_message.emit("Активации закончились — заверши ход.")
		return false
	return true

func move_unit(idx, to):
	return _move_unit(idx, to, true)

func attack_unit(idx, target_idx, qte_bonus = 0.0):
	return _attack_unit(idx, target_idx, qte_bonus, true)

func heal_unit(idx, target_idx):
	return _heal_unit(idx, target_idx, true)

func cast_fire_area(idx, center):
	return _cast_fire_area(idx, center, true)

func fire_arrow(idx, target_cell):
	return _fire_arrow(idx, target_cell, true)

func shove_unit(idx, target_idx):
	return _shove_unit(idx, target_idx, true)

func end_player_turn():
	if state == null or units == null:
		return false
	if state.game_over:
		return false
	if not state.end_player_turn():
		return false
	await run_enemy_turn()
	return true

func run_enemy_turn():
	if state == null or units == null:
		return
	status_message.emit("Ход врагов…")
	var intents = BattleAI.get_enemy_intents(units.units, classes, int(environment.get("gw", 8)), int(environment.get("gh", 6)), environment.get("objects", []), environment.get("elev", {}), environment.get("fires", []))
	for intent in intents:
		if state.game_over:
			break
		intent_started.emit(intent)
		await execute_intent(intent)
		intent_finished.emit(intent)
		await get_tree().process_frame
	_end_round()
	if not _check_game_over():
		state.end_enemy_turn()
		status_message.emit("Твой ход: клик по своему юниту.")

func execute_intent(intent):
	var action = str(intent.get("action", ""))
	var actor = int(intent.get("actor_idx", -1))
	if actor < 0:
		return
	match action:
		"move":
			var to = _to_vec2(intent.get("move_to", Vector2i.ZERO))
			_move_unit(actor, to, false)
			if intent.has("then_attack"):
				_attack_unit(actor, int(intent.get("then_attack", -1)), 0.0, false)
		"attack":
			_attack_unit(actor, int(intent.get("target_idx", -1)), 0.0, false)
		"heal":
			_heal_unit(actor, int(intent.get("target_idx", -1)), false)
		"mage_fire":
			_cast_fire_area(actor, _to_vec2(intent.get("target_cell", Vector2i.ZERO)), false)
		"fire_arrow":
			_fire_arrow(actor, _to_vec2(intent.get("target_cell", Vector2i.ZERO)), false)
		"shove":
			_shove_unit(actor, int(intent.get("target_idx", -1)), false)

func connect_ui(ui):
	if ui == null:
		return
	if ui.has_signal("end_turn_pressed"):
		ui.end_turn_pressed.connect(func(): end_player_turn())
	if ui.has_signal("start_pressed"):
		ui.start_pressed.connect(func(): start_battle())
	if state != null and ui.has_method("set_activations"):
		state.activations_changed.connect(func(left): ui.set_activations(left))
	if ui.has_method("set_status"):
		status_message.connect(func(t): ui.set_status(t))

func _move_unit(idx, to, spend_action):
	if units == null:
		return false
	var u = units.get_unit(idx)
	if u.is_empty() or int(u.get("hp", 0)) <= 0:
		return false
	if not _is_cell_free(to, idx):
		return false
	if spend_action and not _spend_activation(idx):
		return false
	var from = u.get("cell", to)
	u["facing"] = _dir_to(to - from)
	u["cell"] = to
	u["moved"] = true
	if _is_fire_at(to):
		units.set_status(idx, "burn", 2)
	return true

func _attack_unit(ai, ti, qte_bonus, spend_action):
	if units == null:
		return false
	var a = units.get_unit(ai)
	var t = units.get_unit(ti)
	if a.is_empty() or t.is_empty():
		return false
	if int(a.get("hp", 0)) <= 0 or int(t.get("hp", 0)) <= 0:
		return false
	if int(a.get("team", 0)) == int(t.get("team", 1)):
		return false
	if spend_action and not _spend_activation(ai):
		return false
	a["attacked"] = true
	var zone = ActionResolver.calc_zone(a.get("cell", Vector2i.ZERO), t.get("cell", Vector2i.ZERO), t.get("facing", Vector2(1, 0)))
	var result = ActionResolver.resolve_attack(a, t, zone, qte_bonus)
	if result.get("hit", false):
		units.apply_damage(ti, int(result.get("dmg", 0)))
		for st in result.get("statuses_applied", []):
			if st == "mark":
				units.set_status(ti, "mark", 2)
			elif st == "offbal":
				units.set_status(ti, "offbal", 2)
	status_message.emit(str(result.get("log", "")))
	_check_game_over()
	return true

func _heal_unit(hi, ti, spend_action):
	if units == null:
		return false
	var h = units.get_unit(hi)
	var t = units.get_unit(ti)
	if h.is_empty() or t.is_empty():
		return false
	if int(h.get("hp", 0)) <= 0 or int(t.get("hp", 0)) <= 0:
		return false
	if int(h.get("team", -1)) != int(t.get("team", -2)):
		return false
	if int(h.get("heal_uses", 0)) <= 0:
		return false
	if h.get("attacked", false):
		return false
	if _cheb(h.get("cell", Vector2i.ZERO), t.get("cell", Vector2i.ZERO)) > 4:
		return false
	if int(t.get("hp", 0)) >= int(t.get("maxhp", 0)):
		return false
	if spend_action and not _spend_activation(hi):
		return false
	h["attacked"] = true
	h["heal_uses"] = int(h.get("heal_uses", 0)) - 1
	units.apply_heal(ti, 1)
	status_message.emit("Лечение: +1 HP.")
	return true

func _cast_fire_area(ci, center, spend_action):
	if units == null:
		return false
	var u = units.get_unit(ci)
	if u.is_empty() or int(u.get("hp", 0)) <= 0:
		return false
	if str(u.get("cls", "")) != "mage":
		return false
	if int(u.get("fire_uses", 0)) <= 0:
		return false
	if u.get("attacked", false):
		return false
	if _cheb(u.get("cell", Vector2i.ZERO), center) > 4:
		return false
	if spend_action and not _spend_activation(ci):
		return false
	u["attacked"] = true
	u["fire_uses"] = int(u.get("fire_uses", 0)) - 1
	var cells = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var c = center + Vector2i(dx, dy)
			if _is_valid_cell(c):
				cells.append(c)
	if cells.size() == 0:
		return false
	var fire = {"cells": cells, "left": 2, "dmg": 1}
	environment["fires"].append(fire)
	fire_added.emit(fire)
	for i in units.units.size():
		var uu = units.units[i]
		if int(uu.get("hp", 0)) > 0 and cells.has(uu.get("cell", Vector2i(-999, -999))):
			units.set_status(i, "burn", 2)
	status_message.emit("Огонь накрыл область!")
	return true

func _fire_arrow(ai, c, spend_action):
	if units == null:
		return false
	var a = units.get_unit(ai)
	if a.is_empty() or int(a.get("hp", 0)) <= 0:
		return false
	if a.get("attacked", false):
		return false
	var ar = int(a.get("cls_data", {}).get("ar", 1))
	if _cheb(a.get("cell", Vector2i.ZERO), c) > ar:
		return false
	if spend_action and not _spend_activation(ai):
		return false
	a["attacked"] = true
	var fire = {"cells": [c], "left": 2, "dmg": 1}
	environment["fires"].append(fire)
	fire_added.emit(fire)
	status_message.emit("Огненная стрела!")
	return true

func _shove_unit(ai, ti, spend_action):
	if units == null:
		return false
	var a = units.get_unit(ai)
	var t = units.get_unit(ti)
	if a.is_empty() or t.is_empty():
		return false
	if int(a.get("hp", 0)) <= 0 or int(t.get("hp", 0)) <= 0:
		return false
	if int(a.get("team", 0)) == int(t.get("team", 1)):
		return false
	if a.get("attacked", false):
		return false
	if _cheb(a.get("cell", Vector2i.ZERO), t.get("cell", Vector2i.ZERO)) > 1:
		return false
	if spend_action and not _spend_activation(ai):
		return false
	a["attacked"] = true
	var dir = _dir_to(t.get("cell", Vector2i.ZERO) - a.get("cell", Vector2i.ZERO))
	var dest = t.get("cell", Vector2i.ZERO) + Vector2i(roundi(dir.x), roundi(dir.y))
	var terrain_valid = _is_valid_cell(dest)
	var elev_diff = _th(t.get("cell", Vector2i.ZERO)) - _th(dest)
	var blocked = _is_cell_blocked(dest, ti)
	var result = ActionResolver.resolve_shove(terrain_valid, elev_diff, blocked)
	if int(result.get("dmg", 0)) > 0:
		units.apply_damage(ti, int(result.get("dmg", 0)))
	else:
		t["cell"] = dest
		if _is_fire_at(dest):
			units.set_status(ti, "burn", 2)
	status_message.emit(str(result.get("log", "")))
	_check_game_over()
	return true

func _spend_activation(idx):
	if state == null or units == null:
		return false
	var u = units.get_unit(idx)
	if u.is_empty() or int(u.get("team", -1)) != 0:
		return false
	if u.get("spent", false):
		return true
	if not state.spend_activation():
		return false
	u["spent"] = true
	u["acts"] = int(u.get("acts", 0)) + 1
	if int(u.get("acts", 0)) >= 2:
		u["tired"] = true
		u["moved"] = false
		u["attacked"] = false
	elif not u.get("acted_prev", false):
		u["fresh"] = true
	return true

func _end_round():
	if units == null:
		return
	for i in units.units.size():
		var u = units.units[i]
		if int(u.get("hp", 0)) <= 0:
			continue
		var b = int(u.get("burn", 0))
		if b > 0:
			b -= 1
			units.set_status(i, "burn", b)
			if b > 0:
				units.apply_damage(i, 1)
		for st in ["mark", "offbal", "pin"]:
			var v = int(u.get(st, 0))
			if v > 0:
				units.set_status(i, st, v - 1)
	for f in environment.get("fires", []):
		for i in units.units.size():
			var u = units.units[i]
			if int(u.get("hp", 0)) > 0 and f.get("cells", []).has(u.get("cell", Vector2i(-999, -999))):
				units.apply_damage(i, int(f.get("dmg", 1)))
	for i in units.units.size():
		var u = units.units[i]
		u["moved"] = false
		u["attacked"] = false
		u["reacted"] = false
		u["acted_prev"] = int(u.get("acts", 0)) > 0
		u["acts"] = 0
		u["spent"] = false
		u["tired"] = false
		u["fresh"] = false
	_age_fires()
	_check_game_over()

func _age_fires():
	var alive = []
	for f in environment.get("fires", []):
		f["left"] = int(f.get("left", 0)) - 1
		if int(f.get("left", 0)) > 0:
			alive.append(f)
	environment["fires"] = alive
	fires_updated.emit(environment["fires"])

func _check_game_over():
	if state == null or units == null:
		return false
	var p = units.get_alive_count(0)
	var e = units.get_alive_count(1)
	var w = state.check_game_over(p, e)
	if w != "":
		state.is_busy = false
		if w == "player":
			status_message.emit("ПОБЕДА!")
		else:
			status_message.emit("ПОРАЖЕНИЕ…")
		return true
	return false

func _is_valid_cell(c):
	if c.x < 0 or c.y < 0:
		return false
	if c.x >= int(environment.get("gw", 8)) or c.y >= int(environment.get("gh", 6)):
		return false
	return true

func _is_cell_free(c, ignore_idx = -1):
	if not _is_valid_cell(c):
		return false
	for o in environment.get("objects", []):
		if o is Vector2i and o == c:
			return false
		if o is Vector2 and Vector2i(int(o.x), int(o.y)) == c:
			return false
		if o is Dictionary:
			var oc = o.get("cell", [])
			if oc.size() >= 2 and Vector2i(int(oc[0]), int(oc[1])) == c:
				return false
	var ui = units.get_unit_at(c)
	if ui >= 0 and ui != ignore_idx:
		return false
	return true

func _is_cell_blocked(c, ignore_idx = -1):
	return not _is_cell_free(c, ignore_idx)

func _is_fire_at(c):
	for f in environment.get("fires", []):
		if f.get("cells", []).has(c):
			return true
	return false

func _th(c):
	var k = _cell_key(c)
	var h = float(environment.get("heights", {}).get(k, 0.0))
	var e = float(environment.get("elev", {}).get(k, 0.0))
	return h + e

func _cell_key(c):
	return str(c.x) + "," + str(c.y)

func _cheb(a, b):
	return maxi(abs(a.x - b.x), abs(a.y - b.y))

func _dir_to(d):
	if d == Vector2i.ZERO:
		return Vector2(1, 0)
	if abs(d.x) >= abs(d.y):
		return Vector2(sign(d.x), 0)
	return Vector2(0, sign(d.y))

func _to_vec2(v):
	if v is Vector2i:
		return v
	if v is Vector2:
		return Vector2i(int(v.x), int(v.y))
	if v is Dictionary:
		return Vector2i(int(v.get("x", 0)), int(v.get("y", 0)))
	if v is Array and v.size() >= 2:
		return Vector2i(int(v[0]), int(v[1]))
	return Vector2i.ZERO
