class_name ActionResolver
extends RefCounted

# ActionResolver — чистая логика боя. 
# Не знает про 3D-модели, UI, анимации и твики состояния.
# Только математика, шансы, урон и статусы.

# Расчет зоны атаки (лоб/спина/бок)
static func calc_zone(attacker_cell: Vector2i, defender_cell: Vector2i, defender_facing: Vector2) -> String:
	var d = Vector2(attacker_cell.x - defender_cell.x, attacker_cell.y - defender_cell.y).normalized()
	var f = defender_facing.normalized()
	var dot = f.x * d.x + f.y * d.y
	if dot <= -0.7: return "back"
	if dot >= 0.7: return "front"
	return "side"

# Расчет шанса попадания
static func calc_hit_chance(cls_data: Dictionary, defender: Dictionary, zone: String, tired: bool, fresh: bool) -> float:
	var cf = float(cls_data.get("cf", 0.6))
	var cb = float(cls_data.get("cb", 0.6))
	var chance = cb if zone == "back" else (cf if zone == "front" else (cf + cb) * 0.5)
	if tired: chance *= 0.9
	if fresh: chance *= 1.1
	if defender.get("mark", 0) > 0: chance *= 1.2
	return chance

# Применение базовой атаки (возвращает словарь с результатами)
static func resolve_attack(attacker: Dictionary, defender: Dictionary, zone: String, qte_bonus: float) -> Dictionary:
	var cls_data = attacker.get("cls_data", {})
	var chance = calc_hit_chance(cls_data, defender, zone, attacker.get("tired", false), attacker.get("fresh", false))
	chance += qte_bonus
	
	var result = {"hit": false, "dmg": 0, "zone": zone, "log": "", "statuses_applied": []}
	
	if randf() < chance:
		result.hit = true
		var dmg = 1
		var prey = str(cls_data.get("prey", ""))
		if prey != "" and prey == str(defender.get("cls", "")):
			dmg += 1
			result.statuses_applied.append("prey_bonus")
		
		if defender.get("offbal", 0) > 0:
			dmg += 1
			result.statuses_applied.append("offbal_bonus")
			
		result.dmg = dmg
		
		# Навешиваем статусы от атакующего (пассивки классов)
		if attacker.get("cls", "") == "assassin":
			result.statuses_applied.append("mark")
		if attacker.get("cls", "") == "swordsman":
			result.statuses_applied.append("offbal")
			
		result.log = "Попадание (%s, -%d)." % [zone, dmg]
	else:
		result.log = "Промах (%s, %d%%)." % [zone, int(chance * 100)]
		
	return result

# Расчет урона от толчка (swordsman)
# Мы передаем сюда уже готовые факты (есть ли клетка, перепад высот, заблокирован ли путь),
# чтобы Resolver не лез в terrain.gd и objects3.
static func resolve_shove(dest_terrain_valid: bool, elev_diff: float, is_blocked: bool) -> Dictionary:
	var result = {"dmg": 0, "log": "", "knocked_out": false}
	
	if not dest_terrain_valid or elev_diff > 0.5:
		result.dmg = 2
		result.log = "-2 падение/сбил!"
	elif is_blocked:
		result.dmg = 1
		result.log = "-1 удар!"
	else:
		result.log = "Толчок успешен."
		
	return result
