@tool
extends EditorScript

func _run():
	# ---- world3d: партия спавнится всегда, если бой не из explore ----
	var wp = "res://scripts/world3d.gd"
	var w = _read(wp)
	if w.find("# F2_WORLD") < 0:
		var a1 = "	if camp.get(\"units\", []).size() == 0 and not from_explore:\n		if Game.party.size() > 0:"
		var r1 = "	# F2_WORLD\n	if not from_explore:\n		if Game.party.size() > 0:"
		if w.find(a1) >= 0:
			w = w.replace(a1, r1)
			_write(wp, w)
			print("FIX: world3d party-always")
		else:
			print("WARN: world3d anchor not found")
	else:
		print("SKIP: world3d")

	# ---- explore3d: страховка от мёртвой партии + защита от пустой партии ----
	var ep = "res://scripts/explore3d.gd"
	var e = _read(ep)
	if e.find("# F2_EXP") < 0:
		var a2 = "	var i = 0\n	for m in Game.party:\n		if int(m.get(\"hp\", 0)) <= 0:\n			continue"
		var r2 = "	# F2_EXP\n	var any_alive = false\n	for m in Game.party:\n		if int(m.get(\"hp\", 0)) > 0:\n			any_alive = true\n	if not any_alive:\n		for m in Game.party:\n			m[\"hp\"] = maxi(1, int(m.get(\"maxhp\", 1)))\n	var i = 0\n	for m in Game.party:\n		if int(m.get(\"hp\", 0)) <= 0:\n			continue"
		if e.find(a2) >= 0:
			e = e.replace(a2, r2)
		else:
			print("WARN: explore spawn anchor not found")
		var a3 = "func _try_combat():\n	if Game.flags"
		var r3 = "func _try_combat():\n	if party_n.size() == 0:\n		return\n	if Game.flags"
		if e.find(a3) >= 0:
			e = e.replace(a3, r3)
		var a4 = "	Game.explore_start = {\"players\": players, \"enemies\": en, \"player\": [int(party_n[0].root.position.x), int(party_n[0].root.position.z)]}"
		var r4 = "	var p0 = [0, 0]\n	if party_n.size() > 0:\n		p0 = [int(party_n[0].root.position.x), int(party_n[0].root.position.z)]\n	Game.explore_start = {\"players\": players, \"enemies\": en, \"player\": p0}"
		if e.find(a4) >= 0:
			e = e.replace(a4, r4)
		_write(ep, e)
		print("FIX: explore3d safety")
	else:
		print("SKIP: explore3d")
	print("FIX: PATCH F2 done")

func _read(p):
	var f = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return ""
	var s = f.get_as_text()
	f.close()
	return s

func _write(path, code):
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		print("FIX: cannot write ", path)
		return
	f.store_string(code)
	f.close()
