extends Control
var lines = []
var sel = -1
var drag_node = -1
var drag_off = Vector2()
var wire_from = null
var mouse_pos = Vector2()
var zoom = 1.0
var pan = Vector2()
var panning = false
var mid_drag = false
signal selected(i)
signal changed
const W = 170.0
func _w2s(p):
	return p * zoom + pan
func _s2w(p):
	return (p - pan) / zoom
func _node_h(i):
	return 44.0 + lines[i].get("choices", []).size() * 16.0
func _wrect(i):
	return Rect2(float(lines[i].get("px", 20)), float(lines[i].get("py", 20)), W, _node_h(i))
func _srect(i):
	var r = _wrect(i)
	return Rect2(_w2s(r.position), r.size * zoom)
func _in_sock(i):
	var r = _wrect(i)
	return _w2s(Vector2(r.position.x, r.position.y + 20))
func _out_sock(i, port):
	var r = _wrect(i)
	if port < 0:
		return _w2s(Vector2(r.end.x, r.position.y + 12))
	return _w2s(Vector2(r.end.x, r.position.y + 28 + port * 16))
func _target_of(i, port):
	var L = lines[i]
	if port < 0:
		return int(L["next"]) if L.has("next") else -1
	var ch = L.get("choices", [])
	if port < ch.size():
		return int(ch[port].get("to", -1))
	return -1
func _draw():
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.09, 0.09, 0.12))
	var n = lines.size()
	for i in n:
		var t = _target_of(i, -1)
		if t >= 0 and t < n:
			_wire(_out_sock(i, -1), _in_sock(t), Color(0.8, 0.8, 0.8), "")
		var ch = lines[i].get("choices", [])
		for k in ch.size():
			var t2 = int(ch[k].get("to", -1))
			if t2 >= 0 and t2 < n:
				_wire(_out_sock(i, k), _in_sock(t2), Color(1, 0.75, 0.2), str(k + 1))
	for i in n:
		var r = _srect(i)
		draw_rect(r, Color(0.16, 0.17, 0.22))
		if i == sel:
			draw_polyline(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]), Color(1, 0.85, 0.2), 2.0)
		var L = lines[i]
		var who = str(L.get("who", ""))
		draw_string(ThemeDB.fallback_font, r.position + Vector2(4, 14 * zoom), "%d [%s] %s" % [i, who if who != "" else "-", str(L.get("text", "")).substr(0, 14)], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 11, Color.WHITE)
		var ch = L.get("choices", [])
		for k in ch.size():
			draw_string(ThemeDB.fallback_font, r.position + Vector2(6, (32 + k * 16) * zoom), "%d: %s" % [k + 1, str(ch[k].get("t", "")).substr(0, 12)], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 10, Color(1, 0.8, 0.4))
		draw_circle(_in_sock(i), 5, Color(0.5, 0.8, 1))
		draw_circle(_out_sock(i, -1), 5, Color(0.9, 0.9, 0.9))
		for k in ch.size():
			draw_circle(_out_sock(i, k), 5, Color(1, 0.75, 0.2))
	if wire_from != null:
		_wire(_out_sock(wire_from["i"], wire_from["port"]), mouse_pos, Color(1, 1, 1, 0.6), "")
func _wire(p1, p2, col, lab):
	draw_line(p1, p2, col, 2.0)
	var d = (p2 - p1).normalized()
	draw_colored_polygon(PackedVector2Array([p2, p2 - d * 8 + Vector2(-d.y, d.x) * 4, p2 - d * 8 + Vector2(d.y, -d.x) * 4]), col)
	if lab != "":
		draw_string(ThemeDB.fallback_font, (p1 + p2) * 0.5 + Vector2(2, -4), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
func _sock_hit(p):
	var n = lines.size()
	for i in n:
		if (p - _in_sock(i)).length() < 7:
			return {"i": i, "port": -2}
	for i in n:
		if (p - _out_sock(i, -1)).length() < 7:
			return {"i": i, "port": -1}
		for k in lines[i].get("choices", []).size():
			if (p - _out_sock(i, k)).length() < 7:
				return {"i": i, "port": k}
	return {}
func _node_hit(p):
	for i in range(lines.size() - 1, -1, -1):
		if _srect(i).has_point(p):
			return i
	return -1
func _gui_input(ev):
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(ev.position, 1.15)
			return
		if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(ev.position, 1.0 / 1.15)
			return
		if ev.button_index == MOUSE_BUTTON_MIDDLE:
			mid_drag = true
			return
		if ev.button_index == MOUSE_BUTTON_LEFT:
			var sh = _sock_hit(ev.position)
			if sh.has("port") and sh["port"] >= -1:
				wire_from = sh
				mouse_pos = ev.position
				return
			var i = _node_hit(ev.position)
			if i >= 0:
				sel = i
				drag_node = i
				drag_off = _s2w(ev.position) - _wrect(i).position
				selected.emit(i)
				queue_redraw()
				return
			panning = true
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			var sh = _sock_hit(ev.position)
			if sh.has("port") and sh["port"] >= -1:
				_clear_out(sh["i"], sh["port"])
	elif ev is InputEventMouseMotion:
		mouse_pos = ev.position
		if drag_node >= 0:
			var w = _s2w(ev.position) - drag_off
			lines[drag_node]["px"] = int(w.x)
			lines[drag_node]["py"] = int(w.y)
			queue_redraw()
		elif mid_drag:
			pan += ev.relative
			queue_redraw()
		elif panning:
			pan += ev.relative
			queue_redraw()
		elif wire_from != null:
			queue_redraw()
	elif ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_MIDDLE:
		mid_drag = false
	elif ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if wire_from != null:
			var sh = _sock_hit(ev.position)
			var target = sh["i"] if sh.has("port") and sh["port"] == -2 else _node_hit(ev.position)
			if target >= 0 and target != wire_from["i"]:
				_connect(wire_from["i"], wire_from["port"], target)
			wire_from = null
			queue_redraw()
		panning = false
		if drag_node >= 0:
			drag_node = -1
			changed.emit()
func _zoom_at(m, f):
	var nz = clampf(zoom * f, 0.4, 2.5)
	var w = _s2w(m)
	zoom = nz
	pan = m - w * zoom
	queue_redraw()
func _connect(i, port, target):
	var L = lines[i]
	if port < 0:
		L["next"] = target
	else:
		var ch = L.get("choices", [])
		if port < ch.size():
			ch[port]["to"] = target
	changed.emit()
	queue_redraw()
func _clear_out(i, port):
	var L = lines[i]
	if port < 0:
		L.erase("next")
	else:
		var ch = L.get("choices", [])
		if port < ch.size():
			ch[port].erase("to")
	changed.emit()
	queue_redraw()
