extends Node

# UnitManager — управляет ТОЛЬКО данными юнитов (здоровье, статы, статусы).
# Не двигает 3D-модели, не рисует UI, не считает урон (этим займется ActionResolver).

signal unit_damaged(idx: int, amount: int)
signal unit_died(idx: int)
signal unit_healed(idx: int, amount: int)
signal unit_status_changed(idx: int, status: String, value: int)

var units: Array = []

func add_unit(data: Dictionary) -> int:
	units.append(data)
	return units.size() - 1

func get_unit(idx: int) -> Dictionary:
	if idx < 0 or idx >= units.size():
		return {}
	return units[idx]

func get_unit_at(cell: Vector2i) -> int:
	for i in units.size():
		if units[i].hp > 0 and units[i].cell == cell:
			return i
	return -1

func get_alive_count(team: int) -> int:
	var count = 0
	for u in units:
		if u.hp > 0 and u.team == team:
			count += 1
	return count

func apply_damage(idx: int, amount: int):
	if idx < 0 or idx >= units.size(): return
	var u = units[idx]
	if u.hp <= 0: return
	u.hp -= amount
	unit_damaged.emit(idx, amount)
	if u.hp <= 0:
		u.hp = 0
		unit_died.emit(idx)

func apply_heal(idx: int, amount: int):
	if idx < 0 or idx >= units.size(): return
	var u = units[idx]
	if u.hp <= 0: return
	var actual_heal = mini(amount, u.maxhp - u.hp)
	u.hp += actual_heal
	if actual_heal > 0:
		unit_healed.emit(idx, actual_heal)

func set_status(idx: int, status: String, value: int):
	if idx < 0 or idx >= units.size(): return
	units[idx][status] = value
	unit_status_changed.emit(idx, status, value)

func get_status(idx: int, status: String) -> int:
	if idx < 0 or idx >= units.size(): return 0
	return units[idx].get(status, 0)

func reset_turn_flags():
	# Вызывается в конце раунда. Сбрасывает действия и тикает статусы.
	for i in units.size():
		var u = units[i]
		u.moved = false
		u.attacked = false
		u.reacted = false
		u.acted_prev = u.get("acts", 0) > 0
		u.acts = 0
		u.spent = false
		u.tired = false
		u.fresh = false
		
		# Уменьшаем статусы (горение, метка и т.д.) в конце раунда
		for st in ["mark", "offbal", "pin", "burn"]:
			if u.get(st, 0) > 0:
				u[st] -= 1
				unit_status_changed.emit(i, st, u[st])
