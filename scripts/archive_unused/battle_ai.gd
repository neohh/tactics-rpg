class_name BattleAI
extends RefCounted

# BattleAI — принимает решения для врагов.
# Не меняет состояние игры напрямую, только возвращает намерения (intents).

# Возвращает список намерений для всех врагов на текущий ход.
# Каждое намерение — словарь: {"actor_idx": int, "action": String, "target_idx": int, "move_to": Vector2i}
static func get_enemy_intents(units: Array, classes: Dictionary, terrain_gw: int, terrain_gh: int, objects: Array, elev: Dictionary, fires: Array) -> Array:
	var intents = []
	var enemy_acts = 2
	
	for i in units.size():
		var u = units[i]
		if u.team != 1 or u.hp <= 0:
			continue
		if enemy_acts <= 0:
			break
			
		var intent = _decide_single(i, units, classes, terrain_gw, terrain_gh, objects, elev, fires)
		if intent.size() > 0:
			enemy_acts -= 1
			intents.append(intent)
			
	return intents

# Принимает решение для одного юнита
static func _decide_single(idx: int, units: Array, classes: Dictionary, terrain_gw: int, terrain_gh: int, objects: Array, elev: Dictionary, fires: Array) -> Dictionary:
	var u = units[idx]
	var cls_data = classes.get(u.cls, {})
	
	# 1. Ищем ближайшего игрока
	var target_idx = _find_nearest_player(u.cell, units)
	if target_idx < 0:
		return {}
		
	var target = units[target_idx]
	var result = {"actor_idx": idx}
	
	# 2. Если можем атаковать сразу — атакуем
	if u.cls != "mage" and _can_hit(u.cell, target.cell, cls_data):
		result["action"] = "attack"
		result["target_idx"] = target_idx
		return result
		
	# 3. Специальные навыки
	if u.cls == "swordsman" and not u.attacked:
		var shove_target = _find_shove_target(idx, units, terrain_gw, terrain_gh, objects, elev, fires)
		if shove_target >= 0:
			result["action"] = "shove"
			result["target_idx"] = shove_target
			return result
			
	if u.cls == "archer" and not u.attacked and u.get("uses", 0) < 2:
		var fire_target = _find_fire_arrow_target(idx, units, cls_data, fires)
		if fire_target.size() > 0:
			result["action"] = "fire_arrow"
			result["target_cell"] = fire_target
			return result
			
	if u.cls == "mage":
		# Маг: лечит союзников или кидает огонь
		var heal_target = _find_heal_target(idx, units, cls_data)
		if heal_target >= 0:
			result["action"] = "heal"
			result["target_idx"] = heal_target
			return result
		var fire_cell = _find_mage_fire_target(idx, units, cls_data)
		if fire_cell.size() > 0:
			result["action"] = "mage_fire"
			result["target_cell"] = fire_cell
			return result
	
	# 4. Если не можем атаковать — двигаемся к цели
	var move_cell = _find_best_move(u.cell, target.cell, units, classes, objects, elev, fires, u.cls)
	if move_cell.size() > 0:
		result["action"] = "move"
		result["move_to"] = Vector2i(move_cell[0], move_cell[1])
		# После движения проверяем, можем ли атаковать
		if u.cls != "mage" and _can_hit(Vector2i(move_cell[0], move_cell[1]), target.cell, cls_data):
			result["then_attack"] = target_idx
		return result
		
	return {}

# === Вспомогательные функции ===

static func _find_nearest_player(cell: Vector2i, units: Array) -> int:
	var best_idx = -1
	var best_dist = 999
	for i in units.size():
		var u = units[i]
		if u.team == 0 and u.hp > 0:
			var d = _cheb(cell, u.cell)
			if d < best_dist:
				best_dist = d
				best_idx = i
	return best_idx

static func _can_hit(from: Vector2i, to: Vector2i, cls_data: Dictionary) -> bool:
	var ar = int(cls_data.get("ar", 1))
	if _cheb(from, to) > ar:
		return false
	# Проверка диагонали для ближнего боя
	var d = to - from
	if ar == 1 and abs(d.x) == 1 and abs(d.y) == 1:
		# Упрощённая проверка: если по диагонали, считаем что можно бить
		return true
	return true

static func _find_shove_target(idx: int, units: Array, terrain_gw: int, terrain_gh: int, objects: Array, elev: Dictionary, fires: Array) -> int:
	var u = units[idx]
	for j in units.size():
		var t = units[j]
		if t.team != 0 or t.hp <= 0 or _cheb(u.cell, t.cell) > 1:
			continue
		var dir = _dir_to(t.cell - u.cell)
		var dest = t.cell + Vector2i(roundi(dir.x), roundi(dir.y))
		# Проверяем, выгодно ли толкать
		if dest.x < 0 or dest.y < 0 or dest.x >= terrain_gw or dest.y >= terrain_gh:
			return j
		if _get_elev(t.cell, elev) - _get_elev(dest, elev) > 0.5:
			return j
		if _is_fire_at(dest, fires):
			return j
	return -1

static func _find_fire_arrow_target(idx: int, units: Array, cls_data: Dictionary, fires: Array) -> Dictionary:
	var u = units[idx]
	var ar = int(cls_data.get("ar", 1))
	var best_j = -1
	var best_d = 99
	for j in units.size():
		var t = units[j]
		if t.team == 0 and t.hp > 0 and not _is_fire_at(t.cell, fires):
			var d = _cheb(u.cell, t.cell)
			if d <= ar and d < best_d:
				best_d = d
				best_j = j
	if best_j >= 0:
		return {"x": units[best_j].cell.x, "y": units[best_j].cell.y}
	return {}

static func _find_heal_target(idx: int, units: Array, cls_data: Dictionary) -> int:
	var u = units[idx]
	if u.get("heal_uses", 0) <= 0:
		return -1
	for j in units.size():
		var t = units[j]
		if t.team == 1 and t.hp > 0 and t.hp < t.maxhp and _cheb(u.cell, t.cell) <= 4:
			return j
	return -1

static func _find_mage_fire_target(idx: int, units: Array, cls_data: Dictionary) -> Dictionary:
	var u = units[idx]
	if u.get("fire_uses", 0) <= 0:
		return {}
	# Ищем скопление игроков
	for j in units.size():
		var t = units[j]
		if t.team == 0 and t.hp > 0 and _cheb(u.cell, t.cell) <= 4:
			return {"x": t.cell.x, "y": t.cell.y}
	return {}

static func _find_best_move(from: Vector2i, target_cell: Vector2i, units: Array, classes: Dictionary, objects: Array, elev: Dictionary, fires: Array, cls: String) -> Dictionary:
	# Упрощённый BFS для поиска лучшего шага
	# В реальной реализации здесь будет полноценный pathfinding
	var best = {}
	var best_score = 999
	var mv = int(classes.get(cls, {}).get("move", 3))
	
	# Перебираем соседние клетки (упрощённо)
	for dx in range(-mv, mv + 1):
		for dy in range(-mv, mv + 1):
			if abs(dx) + abs(dy) > mv:
				continue
			var c = from + Vector2i(dx, dy)
			if c.x < 0 or c.y < 0:
				continue
			# Проверяем, свободна ли клетка
			var occupied = false
			for u in units:
				if u.hp > 0 and u.cell == c:
					occupied = true
					break
			if occupied or objects.has(c):
				continue
			if _is_fire_at(c, fires):
				continue
			var score = _cheb(c, target_cell)
			# Ассасины предпочитают заходить со спины
			if cls == "assassin":
				var target_unit = null
				for u in units:
					if u.cell == target_cell:
						target_unit = u
						break
				if target_unit != null:
					var zone = _zone_of(target_unit, c)
					if zone == "back":
						score -= 2
					elif zone == "side":
						score -= 1
			if score < best_score:
				best_score = score
				best = {"x": c.x, "y": c.y}
	return best

static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

static func _dir_to(d: Vector2i) -> Vector2:
	if abs(d.x) >= abs(d.y):
		return Vector2(sign(d.x), 0)
	return Vector2(0, sign(d.y))

static func _get_elev(c: Vector2i, elev: Dictionary) -> float:
	return float(elev.get(str(c.x) + "," + str(c.y), 0.0))

static func _is_fire_at(c: Vector2i, fires: Array) -> bool:
	for f in fires:
		if f.get("cells", []).has(c):
			return true
	return false

static func _zone_of(target: Dictionary, from: Vector2i) -> String:
	var d = Vector2(from.x - target.cell.x, from.y - target.cell.y).normalized()
	var f = target.get("facing", Vector2(1, 0)).normalized()
	var dot = f.x * d.x + f.y * d.y
	if dot <= -0.7:
		return "back"
	if dot >= 0.7:
		return "front"
	return "side"
