extends Control
var DATA = {}
var id = ""
func setup(all, qid):
	DATA = all
	id = qid
	_build()
func _q():
	return DATA.get(id, {})
func _build():
	for c in get_children():
		c.queue_free()
	var Q = _q()
	var r1 = HBoxContainer.new()
	var l1 = Label.new()
	l1.text = "Название"
	r1.add_child(l1)
	var te = LineEdit.new()
	te.text = str(Q.get("title", ""))
	te.custom_minimum_size = Vector2(180, 26)
	te.text_changed.connect(_set_title)
	r1.add_child(te)
	r1.position = Vector2(0, 0)
	add_child(r1)
	var r2 = HBoxContainer.new()
	var l2 = Label.new()
	l2.text = "Награда, золото"
	r2.add_child(l2)
	var gs = SpinBox.new()
	gs.max_value = 9999
	gs.value = int(Q.get("reward", {}).get("gold", 0))
	gs.value_changed.connect(_set_gold)
	r2.add_child(gs)
	r2.position = Vector2(0, 30)
	add_child(r2)
	var l3 = Label.new()
	l3.text = "Стадии: clear=зачистить loc | talk=поговорить с who | goto=прибыть в loc (играет dlg) | done=конец"
	l3.position = Vector2(0, 60)
	add_child(l3)
	var act = Label.new()
	act.text = _activation_text()
	act.autowrap_mode = TextServer.AUTOWRAP_WORD
	act.custom_minimum_size = Vector2(520, 0)
	add_child(act)
	var sb = VBoxContainer.new()
	sb.position = Vector2(0, 85)
	add_child(sb)
	_stages_ui(sb)
	
func _stages_ui(sb):
	for c in sb.get_children():
		c.queue_free()
	var Q = _q()
	var st = Q.get("stages", {})
	var keys = st.keys()
	keys.sort_custom(func(x, y): return int(x) < int(y))
	var chain = []
	for k in keys:
		chain.append(_st_icon(st[k]) + " " + _st_where(st[k]))
	var sum = Label.new()
	sum.text = "ЦЕПЬ: " + " -> ".join(chain) + " | награда: " + str(Q.get("reward", {}).get("gold", 0)) + "g"
	sum.autowrap_mode = TextServer.AUTOWRAP_WORD
	sum.custom_minimum_size = Vector2(520, 0)
	sb.add_child(sum)
	for key in keys:
		var stt = st[key]
		var p = PanelContainer.new()
		var vb = VBoxContainer.new()
		p.add_child(vb)
		var hd = HBoxContainer.new()
		var num = Label.new()
		num.text = "Стадия " + key + ":"
		num.custom_minimum_size = Vector2(80, 24)
		hd.add_child(num)
		var ic = Label.new()
		ic.text = _st_icon(stt) + " " + _st_where(stt)
		ic.custom_minimum_size = Vector2(240, 24)
		hd.add_child(ic)
		var del = Button.new()
		del.text = "x"
		del.pressed.connect(_del_stage.bind(key))
		hd.add_child(del)
		vb.add_child(hd)
		var rw = HBoxContainer.new()
		var ty = OptionButton.new()
		var tcur_type = "done" if stt.get("done", false) else str(stt.get("type", "clear"))
		var types = ["clear", "talk", "goto", "done"]
		var tcur = 0
		for i2 in types.size():
			ty.add_item(types[i2])
			if types[i2] == tcur_type:
				tcur = i2
		ty.selected = tcur
		ty.item_selected.connect(_set_st_type2.bind(key))
		rw.add_child(ty)
		var tg = OptionButton.new()
		tg.add_item("(—)")
		var tsel = 0
		if tcur_type == "talk":
			var ch = _rj("res://data/chars.json")
			var ci = 0
			for cid in ch:
				ci += 1
				tg.add_item(str(ch[cid].get("name", cid)))
				if cid == str(stt.get("who", "")):
					tsel = ci
		else:
			var lo = _rj("res://data/locations.json")
			var li = 0
			for lid in lo:
				li += 1
				tg.add_item(str(lo[lid].get("name", lid)))
				if lid == str(stt.get("loc", "")):
					tsel = li
		tg.selected = tsel
		tg.item_selected.connect(_set_st_target2.bind(key))
		rw.add_child(tg)
		var dg = OptionButton.new()
		dg.add_item("(без диалога)")
		var dsel = 0
		var df = _dlg_files()
		for i3 in df.size():
			dg.add_item(df[i3])
			if df[i3] == str(stt.get("dlg", "")):
				dsel = i3 + 1
		dg.selected = dsel
		dg.item_selected.connect(_set_st_dlg2.bind(key))
		rw.add_child(dg)
		vb.add_child(rw)
		var tx = LineEdit.new()
		tx.placeholder_text = "текст в журнале"
		tx.text = str(stt.get("text", ""))
		tx.text_changed.connect(_set_st_text.bind(key))
		vb.add_child(tx)
		var cm = LineEdit.new()
		cm.placeholder_text = "комментарий (не в журнал)"
		cm.text = str(stt.get("comment", ""))
		cm.text_changed.connect(_set_st_comment.bind(key))
		vb.add_child(cm)
		sb.add_child(p)
	var ba = Button.new()
	ba.text = "+ стадия"
	ba.pressed.connect(_add_stage)
	sb.add_child(ba)
func _set_title(v):
	_q()["title"] = v
	_save()
func _set_gold(v):
	var Q = _q()
	if not Q.has("reward"):
		Q["reward"] = {}
	Q["reward"]["gold"] = int(v)
	_save()
func _set_st_type(i, key):
	_q()["stages"][key]["type"] = ["clear", "talk", "goto", "done"][i]
	_save()
func _set_st_target(v, key):
	var st = _q()["stages"][key]
	if st.get("type", "clear") == "talk":
		st["who"] = v
		st.erase("loc")
	else:
		st["loc"] = v
		st.erase("who")
	_save()
func _set_st_text(v, key):
	_q()["stages"][key]["text"] = v
	_save()
func _add_stage():
	var Q = _q()
	if not Q.has("stages"):
		Q["stages"] = {}
	Q["stages"][str(Q["stages"].size() + 1)] = {"type": "clear", "loc": "", "text": ""}
	_save()
	_build()
func _save():
	var f = FileAccess.open("res://data/quests.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(DATA))
	f.close()
	get_tree().call_group("live", "live_reload")

func _st_icon(st):
	if st.get("done", false):
		return "[конец]"
	var t = str(st.get("type", "clear"))
	if t == "clear":
		return "[бой]"
	if t == "talk":
		return "[говор]"
	if t == "goto":
		return "[приход]"
	return "[конец]"
func _st_where(st):
	var t = str(st.get("type", "clear"))
	if t == "talk":
		var ch = _rj("res://data/chars.json")
		return str(ch.get(st.get("who", ""), {}).get("name", st.get("who", "")))
	if t == "done":
		return ""
	var lo = _rj("res://data/locations.json")
	return str(lo.get(st.get("loc", ""), {}).get("name", st.get("loc", "")))
func _rj(p):
	var f = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var j = JSON.parse_string(f.get_as_text())
	f.close()
	return {} if j == null else j
func _dlg_files():
	var res = []
	var d = DirAccess.open("res://data/dialogs")
	if d == null:
		return res
	d.list_dir_begin()
	var fn = d.get_next()
	while fn != "":
		if fn.ends_with(".json"):
			res.append(fn.trim_suffix(".json"))
		fn = d.get_next()
	return res
func _set_st_type2(i, key):
	var types = ["clear", "talk", "goto", "done"]
	var st = _q()["stages"][key]
	st["type"] = types[i]
	if types[i] == "done":
		st["done"] = true
	else:
		st.erase("done")
	st.erase("loc")
	st.erase("who")
	_save()
	_build()
func _set_st_target2(i, key):
	if i <= 0:
		return
	var st = _q()["stages"][key]
	if str(st.get("type", "")) == "talk":
		st["who"] = _rj("res://data/chars.json").keys()[i - 1]
	else:
		st["loc"] = _rj("res://data/locations.json").keys()[i - 1]
	_save()
	_build()
func _set_st_dlg2(i, key):
	var st = _q()["stages"][key]
	if i <= 0:
		st.erase("dlg")
	else:
		st["dlg"] = _dlg_files()[i - 1]
	_save()
	_build()
func _del_stage(key):
	_q()["stages"].erase(key)
	_save()
	_build()

func _set_st_comment(v, key):
	_q()["stages"][key]["comment"] = v
	_save()
func _activation_text():
	var res = []
	var d = DirAccess.open("res://data/dialogs")
	if d == null:
		return "Начало квеста: в диалоге fx квест = %s:1" % id
	d.list_dir_begin()
	var fn = d.get_next()
	while fn != "":
		if fn.ends_with(".json"):
			var f = FileAccess.open("res://data/dialogs/" + fn, FileAccess.READ)
			if f != null:
				var j = JSON.parse_string(f.get_as_text())
				f.close()
				if j != null:
					for Ln in j.get("lines", []):
						var q = str(Ln.get("fx", {}).get("quest", ""))
						if q.begins_with(id + ":"):
							res.append(fn.trim_suffix(".json") + " (fx " + q + ")")
		fn = d.get_next()
	if res.size() == 0:
		return "Начало квеста: НЕ задано. В диалоге строка с fx квест = %s:1" % id
	return "Начало квеста: " + ", ".join(res)
