extends CanvasLayer
var hook = true
var preview_mode = false
var chars = {}
var data = {}
var idx = 0
var root: Control
var bg: ColorRect
var p_rect: ColorRect
var p_img: TextureRect
var name_l: Label
var text_l: Label
var choice_box: VBoxContainer
signal done

func play(d):
	add_to_group("live")
	data = d
	if root == null:
		_build()
	root.visible = true
	idx = int(d.get("start", 0))
	_show()
	await done
	root.visible = false

func play_preview(d, chars_dict):
	preview_mode = true
	add_to_group("live")
	chars = chars_dict
	data = d
	if root == null:
		_build()
	root.visible = true
	if idx >= data.get("lines", []).size():
		idx = 0
	_show()

func _build():
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(_adv)
	root.add_child(bg)
	var box = ColorRect.new()
	box.color = Color(0.08, 0.08, 0.12, 0.92)
	box.anchor_left = 0.05
	box.anchor_right = 0.95
	box.anchor_top = 0.66
	box.anchor_bottom = 0.95
	root.add_child(box)
	p_rect = ColorRect.new()
	p_rect.position = Vector2(16, 16)
	p_rect.size = Vector2(110, 110)
	box.add_child(p_rect)
	p_img = TextureRect.new()
	p_img.position = Vector2(16, 16)
	p_img.size = Vector2(110, 110)
	p_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	box.add_child(p_img)
	name_l = Label.new()
	name_l.anchor_left = 0.22
	name_l.anchor_top = 0.68
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(name_l)
	text_l = Label.new()
	text_l.anchor_left = 0.22
	text_l.anchor_top = 0.74
	text_l.anchor_right = 0.93
	text_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(text_l)
	choice_box = VBoxContainer.new()
	choice_box.anchor_left = 0.22
	choice_box.anchor_top = 0.82
	root.add_child(choice_box)
	if preview_mode:
		var bx = Button.new()
		bx.text = "✕ выйти"
		bx.anchor_left = 1.0
		bx.anchor_right = 1.0
		bx.offset_left = -110
		bx.offset_right = -8
		bx.offset_top = 8
		bx.offset_bottom = 44
		bx.pressed.connect(func(): queue_free())
		root.add_child(bx)

func _adv(ev):
	if ev is InputEventMouseButton and ev.pressed:
		if preview_mode and ev.button_index == MOUSE_BUTTON_RIGHT:
			root.visible = false
			return
		if ev.button_index != MOUSE_BUTTON_LEFT:
			return
		if choice_box.get_child_count() == 0:
			var Ls = data.get("lines", [])
			if idx < Ls.size():
				var nxt = int(Ls[idx].get("next", idx + 1))
				if nxt < 0 or nxt == idx:
					idx = Ls.size()
				else:
					idx = nxt
			else:
				idx += 1
			if preview_mode and idx >= Ls.size():
				idx = 0
			_show()

func _pick(to):
	idx = to
	_show()

func _col(h):
	return Color(h) if h != "" else Color.WHITE

func _show():
	if root == null:
		_build()
	var lines = data.get("lines", [])
	if idx >= lines.size():
		done.emit()
		return
	var L = lines[idx]
	var cond = L.get("cond", {})
	if cond.has("flag") and not Game.flags.get(cond["flag"], false):
		idx += 1
		_show()
		return
	if cond.has("not_flag") and Game.flags.get(cond["not_flag"], false):
		idx += 1
		_show()
		return
	var fx = L.get("fx", {})
	if preview_mode:
		fx = {}
	if fx.has("give"):
		Game.add_item(fx["give"])
	if fx.has("gold"):
		var g_delta = int(fx["gold"])
		if g_delta < 0:
			Game.gold = max(0, Game.gold + g_delta)
		else:
			Game.gold += g_delta
	if fx.has("flag"):
		var fl = str(fx["flag"])
		Game.flags[fl] = true
		if fl == "paid_bandits" or fl == "bandits_paid":
			Game.flags["paid_bandits"] = true
			Game.flags["bandits_paid"] = true
			if Game.cur_loc != "":
				Game.flags["paid_bandits_" + Game.cur_loc] = true
				Game.flags["peace_" + Game.cur_loc] = true
	if fx.has("peace"):
		Game.flags["peace_" + Game.cur_loc] = true
	if fx.has("hostile"):
		Game.flags["peace_" + Game.cur_loc] = false
	if fx.has("quest"):
		var qs = String(fx["quest"]).split(":")
		Game.quests[qs[0]] = int(qs[1])
	var ch = chars.get(L.get("who", ""), {})
	if hook and not preview_mode:
		Game.dialog_hook(L.get("who", ""))
	name_l.text = ch.get("name", "")
	name_l.add_theme_color_override("font_color", _col(ch.get("color", "#ffffff")))
	_apply_portrait(ch)
	text_l.text = L.get("text", "")
	for c in choice_box.get_children():
		c.queue_free()
	for c in L.get("choices", []):
		var target_idx = int(c.get("to", idx + 1))
		var b = Button.new()
		b.text = c.get("t", "")
		if not preview_mode and target_idx >= 0 and target_idx < lines.size():
			var target_fx = lines[target_idx].get("fx", {})
			if target_fx.has("gold") and int(target_fx["gold"]) < 0:
				var cost = -int(target_fx["gold"])
				if Game.gold < cost:
					b.disabled = true
					b.text += " (нужно %d золота)" % cost
		b.pressed.connect(_pick.bind(target_idx))
		choice_box.add_child(b)

func _apply_portrait(ch):
	var sc = float(ch.get("img_scale", 1.0))
	var ox = float(ch.get("img_ox", 0.0))
	var oy = float(ch.get("img_oy", 0.0))
	p_img.position = Vector2(16 + ox, -(110.0 * sc) - 8.0 + oy)
	p_rect.position = p_img.position
	p_img.size = Vector2(110, 110) * sc
	p_rect.size = Vector2(110, 110) * sc
	var tx = _tex(str(ch.get("img", "")))
	if tx != null:
		p_img.texture = tx
		p_img.visible = true
		p_rect.visible = false
	else:
		p_img.visible = false
		p_rect.visible = true
		p_rect.color = _col(ch.get("color", "#888888"))

func _tex(path):
	if path == "" or not FileAccess.file_exists(path):
		return null
	var im = Image.new()
	if im.load(path) != OK:
		return null
	return ImageTexture.create_from_image(im)

func live_reload():
	chars = DataLoader.load_json("res://data/chars.json", {})
	if root != null and root.visible:
		var lines = data.get("lines", [])
		if idx >= lines.size():
			return
		var L = lines[idx]
		var ch = chars.get(L.get("who", ""), {})
		name_l.text = ch.get("name", "")
		name_l.add_theme_color_override("font_color", _col(ch.get("color", "#ffffff")))
		_apply_portrait(ch)
