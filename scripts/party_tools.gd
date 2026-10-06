class_name PartyTools
extends RefCounted

static func max_size() -> int:
	return int(ConfigTools.get_val("party_max", 6))

static func can_recruit() -> bool:
	return Game.party.size() < max_size()

static func new_member(char_id: String, cls: String, level: int = 1) -> Dictionary:
	return {"char": char_id, "cls": cls, "level": level, "xp": 0, "perk_points": 0, "perks": [], "equip": {"weapon": "", "armor": "", "trinket": ""}, "hp": 0, "maxhp": 0}

static func fill_party():
	if Game.party.size() > 0:
		return
	var defs = [
		["kael", "swordsman", "iron_sword", "leather_armor"],
		["bria", "archer", "hunting_bow", "leather_armor"],
		["dorn", "halberd", "war_hammer", "chainmail"],
		["vesna", "mage", "", "magic_robe"],
		["grik", "assassin", "iron_sword", "leather_armor"]
	]
	for d in defs:
		if Game.party.size() >= max_size():
			break
		var m = new_member(d[0], d[1], 1)
		m["equip"]["weapon"] = d[2]
		m["equip"]["armor"] = d[3]
		ensure_hp(m)
		Game.party.append(m)

static func hire(char_id: String, cls: String, price: int, level: int = 1) -> bool:
	if Game.gold < price or not can_recruit():
		return false
	Game.gold -= price
	var m = new_member(char_id, cls, level)
	ensure_hp(m)
	Game.party.append(m)
	return true

static func dismiss(idx: int):
	if idx < 0 or idx >= Game.party.size():
		return
	var m = Game.party[idx]
	Game.party.remove_at(idx)
	Game.party_pool.append(m)

static func return_from_pool(idx: int) -> bool:
	if idx < 0 or idx >= Game.party_pool.size():
		return false
	if not can_recruit():
		return false
	var m = Game.party_pool[idx]
	Game.party_pool.remove_at(idx)
	Game.party.append(m)
	return true

static func set_leader(idx: int):
	if idx <= 0 or idx >= Game.party.size():
		return
	var m = Game.party[idx]
	Game.party.remove_at(idx)
	Game.party.push_front(m)

static func add_xp(member: Dictionary, amount: int) -> int:
	member["xp"] = int(member.get("xp", 0)) + amount
	var ups = 0
	while member["xp"] >= StatsTools.xp_next(int(member.get("level", 1))):
		member["xp"] -= StatsTools.xp_next(int(member.get("level", 1)))
		member["level"] = int(member.get("level", 1)) + 1
		member["perk_points"] = int(member.get("perk_points", 0)) + 1
		ups += 1
	return ups

static func ensure_hp(member: Dictionary):
	if int(member.get("maxhp", 0)) <= 0:
		var d = StatsTools.derived(_classes().get(member.get("cls", ""), {}), int(member.get("level", 1)), member.get("perks", []), member.get("equip", {}))
		member["maxhp"] = d["hp"]
		member["hp"] = d["hp"]

static func _classes():
	var f = FileAccess.open("res://data/classes.json", FileAccess.READ)
	if f == null:
		return {}
	var j = JSON.parse_string(f.get_as_text())
	f.close()
	return {} if j == null else j
