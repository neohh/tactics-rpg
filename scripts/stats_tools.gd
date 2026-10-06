class_name StatsTools
extends RefCounted

static func perks_data() -> Dictionary:
	return DataLoader.load_json("res://data/perks.json")

static func equip_agg(equip: Dictionary) -> Dictionary:
	var items = DataLoader.load_json("res://data/items.json")
	var agg = {"mods": {}, "grants": [], "on_hit": []}
	for slot in equip:
		var iid = str(equip[slot])
		if iid == "":
			continue
		var it = items.get(iid, {})
		for k in it.get("mods", {}):
			agg["mods"][k] = agg["mods"].get(k, 0) + it["mods"][k]
		for g in it.get("grants", []):
			if not agg["grants"].has(g):
				agg["grants"].append(g)
		if it.has("on_hit"):
			agg["on_hit"].append(it["on_hit"])
	return agg

static func derived(cls_data: Dictionary, level: int, perks: Array, equip: Dictionary) -> Dictionary:
	var s = {"hp": int(cls_data.get("hp", 2)), "move": int(cls_data.get("move", 3)), "ar": int(cls_data.get("ar", 1)), "cf": float(cls_data.get("cf", 0.6)), "cb": float(cls_data.get("cb", 0.6)), "armor": 0.0, "hit_bonus": 0.0, "dmg_bonus": 0, "skills": [], "on_hit": []}
	var g = cls_data.get("growth", {})
	var lv = maxi(1, level) - 1
	s["hp"] += int(g.get("hp", 0)) * lv
	s["move"] += int(g.get("move", 0)) * lv
	s["ar"] += int(g.get("ar", 0)) * lv
	s["cf"] += float(g.get("cf", 0.0)) * lv
	s["cb"] += float(g.get("cb", 0.0)) * lv
	var P = perks_data()
	for pid in perks:
		var pd = P.get(pid, {})
		_apply(s, pd.get("mods", {}))
		for sk in pd.get("grants", []):
			if not s["skills"].has(sk):
				s["skills"].append(sk)
	var agg = equip_agg(equip)
	_apply(s, agg["mods"])
	for sk in agg["grants"]:
		if not s["skills"].has(sk):
			s["skills"].append(sk)
	s["on_hit"] = agg["on_hit"]
	s["cf"] = clampf(s["cf"], 0.05, 0.95)
	s["cb"] = clampf(s["cb"], 0.05, 0.95)
	var fat = get_game_fatigue()
	if fat >= 3:
		s["move"] = maxi(1, int(s["move"]) - 1)
		s["hit_bonus"] = float(s["hit_bonus"]) - 0.15
	return s

static func get_game_fatigue() -> int:
	var root = Engine.get_main_loop()
	if root != null and root.has_method("root"):
		var g = root.root.get_node_or_null("/root/Game")
		if g != null and "fatigue" in g:
			return int(g.fatigue)
	return 0

static func _apply(s: Dictionary, mods: Dictionary):
	for k in mods:
		var cur = s.get(k, 0)
		s[k] = cur + mods[k]

static func xp_next(level: int) -> int:
	var b = float(ConfigTools.get_val("xp_base", 10))
	var m = float(ConfigTools.get_val("xp_mul", 1.5))
	return int(round(b * pow(m, maxi(0, level - 1))))

static func xp_for_kill(cls_data: Dictionary, enemy_lvl: int) -> int:
	return int(cls_data.get("xp", 5)) * maxi(1, enemy_lvl)

static func activations_for(count: int) -> int:
	if count >= int(ConfigTools.get_val("act_big_at", 5)):
		return int(ConfigTools.get_val("act_big", 3))
	return int(ConfigTools.get_val("act_base", 2))
