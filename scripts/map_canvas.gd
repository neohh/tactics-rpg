extends Control
var DATA = {}
var sel = ""
var link_mode = false
var drag_id = ""
var drag_off = Vector2()
var K = 0.5
signal picked(id)
signal moved(id)
signal link_req(a, b)
func _ready():
	size = Vector2(760, 420)
func _p(id):
	return Vector2(DATA[id].get("pos", [200, 200])[0] * K, DATA[id].get("pos", [200, 200])[1] * K)
func _draw():
	draw_rect(Rect2(0, 0, size.x, size.y), Color(0.08, 0.09, 0.11))
	for id in DATA:
		for lk in DATA[id].get("links", []):
			if DATA.has(lk) and str(id) < str(lk):
				draw_line(_p(id), _p(lk), Color(0.4, 0.35, 0.28), 2.0)
	for id in DATA:
		var c = _p(id)
		var col = {"town": Color(0.8,0.7,0.4), "camp": Color(0.8,0.3,0.2), "cave": Color(0.5,0.5,0.6), "field": Color(0.3,0.6,0.3)}.get(DATA[id].get("type", "field"), Color(0.6,0.6,0.6))
		draw_circle(c, 10, col)
		if id == sel:
			draw_arc(c, 13, 0, TAU, 24, Color(1, 0.85, 0.2), 2.0)
		draw_string(ThemeDB.fallback_font, c + Vector2(-30, 26), str(DATA[id].get("name", id)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
func _hit(p):
	var bi = ""
	var bd = 14.0
	for id in DATA:
		var d = (p - _p(id)).length()
		if d < bd:
			bd = d
			bi = id
	return bi
func _gui_input(ev):
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var id = _hit(ev.position)
		if link_mode and sel != "" and id != "" and id != sel:
			link_req.emit(sel, id)
			return
		if id != "":
			sel = id
			drag_id = id
			drag_off = ev.position - _p(id)
			picked.emit(id)
			queue_redraw()
	elif ev is InputEventMouseMotion and drag_id != "":
		var np = (ev.position - drag_off) / K
		DATA[drag_id]["pos"] = [int(clampf(np.x, 0, 1400)), int(clampf(np.y, 0, 800))]
		queue_redraw()
	elif ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if drag_id != "":
			drag_id = ""
			moved.emit(sel)
