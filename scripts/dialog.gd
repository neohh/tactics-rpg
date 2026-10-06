extends CanvasLayer
var hook = true
var preview_mode = false
var chars = {}
var data = {}
var idx = 0
var root: Control
var bg: ColorRect
var bg_img: TextureRect
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
	bg_img = TextureRect.new()
	bg_img.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_img.visible = false
	root.add_child(bg_img)
	
	# Главная панель диалога
	var box = Panel.new()
	var box_style = StyleBoxFlat.new()
	box_style.bg_color = Color(0.07, 0.08, 0.11, 0.96)
	box_style.border_color = Color(0.78, 0.48, 0.22, 0.85) # Медный/бронзовый кант в тон игры
	box_style.set_border_width_all(2)
	box_style.set_corner_radius_all(8)
	box.add_theme_stylebox_override("panel", box_style)
	box.anchor_left = 0.05
	box.anchor_right = 0.95
	box.anchor_top = 0.62
	box.anchor_bottom = 0.95
	root.add_child(box)

	# Рамка для иконки/портрета говорящего
	var port_frame = Panel.new()
	var pf_style = StyleBoxFlat.new()
	pf_style.bg_color = Color(0.12, 0.13, 0.17, 1.0)
	pf_style.border_color = Color(0.85, 0.55, 0.25, 0.9)
	pf_style.set_border_width_all(2)
	pf_style.set_corner_radius_all(6)
	port_frame.add_theme_stylebox_override("panel", pf_style)
	port_frame.position = Vector2(18, 16)
	port_frame.size = Vector2(120, 120)
	box.add_child(port_frame)

	p_rect = ColorRect.new()
	p_rect.position = Vector2(4, 4)
	p_rect.size = Vector2(112, 112)
	port_frame.add_child(p_rect)

	p_img = TextureRect.new()
	p_img.position = Vector2(4, 4)
	p_img.size = Vector2(112, 112)
	p_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	port_frame.add_child(p_img)

	# Имя персонажа
	name_l = Label.new()
	name_l.position = Vector2(154, 14)
	name_l.add_theme_font_size_override("font_size", 16)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_l)

	# Текст реплики
	text_l = Label.new()
	text_l.position = Vector2(154, 42)
	text_l.size = Vector2(850, 70)
	text_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_l.add_theme_font_size_override("font_size", 14)
	text_l.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	text_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(text_l)

	# Контейнер для вариантов выбора
	choice_box = VBoxContainer.new()
	choice_box.position = Vector2(154, 116)
	choice_box.custom_minimum_size = Vector2(800, 40)
	choice_box.add_theme_constant_override("separation", 6)
	box.add_child(choice_box)
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
	_apply_bg(L)
	text_l.text = L.get("text", "")
	for c in choice_box.get_children():
		c.queue_free()
	for c in L.get("choices", []):
		var target_idx = int(c.get("to", idx + 1))
		var b = Button.new()
		b.text = "▸  " + str(c.get("t", ""))
		b.custom_minimum_size = Vector2(0, 34)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		# Стиль для кнопок выбора реплик
		var c_normal = StyleBoxFlat.new()
		c_normal.bg_color = Color(0.12, 0.14, 0.19, 0.95)
		c_normal.border_color = Color(0.78, 0.48, 0.22, 0.8) # Медный/янтарный контур
		c_normal.set_border_width_all(1)
		c_normal.set_corner_radius_all(6)
		c_normal.content_margin_left = 14
		c_normal.content_margin_right = 14
		c_normal.content_margin_top = 6
		c_normal.content_margin_bottom = 6
		b.add_theme_stylebox_override("normal", c_normal)

		var c_hover = c_normal.duplicate()
		c_hover.bg_color = Color(0.20, 0.23, 0.32, 1.0)
		c_hover.border_color = Color(1.0, 0.75, 0.3, 1.0) # Яркая золотая подсветка при наведении
		c_hover.set_border_width_all(2)
		b.add_theme_stylebox_override("hover", c_hover)

		var c_pressed = c_normal.duplicate()
		c_pressed.bg_color = Color(0.26, 0.20, 0.10, 1.0)
		c_pressed.border_color = Color(1.0, 0.85, 0.4, 1.0)
		b.add_theme_stylebox_override("pressed", c_pressed)

		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75))
		b.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))

		if not preview_mode and target_idx >= 0 and target_idx < lines.size():
			var target_fx = lines[target_idx].get("fx", {})
			if target_fx.has("gold") and int(target_fx["gold"]) < 0:
				var cost = -int(target_fx["gold"])
				if Game.gold < cost:
					b.disabled = true
					b.text += " (нужно %d золота)" % cost
		b.pressed.connect(_pick.bind(target_idx))
		choice_box.add_child(b)

func _apply_bg(L):
	var bg_path = str(L.get("bg", data.get("bg", "")))
	if bg_path != "":
		var tx = _tex(bg_path)
		if tx != null:
			bg_img.texture = tx
			bg_img.visible = true
			bg.color = Color(0, 0, 0, 1.0)
			return
	bg_img.visible = false
	bg.color = Color(0, 0, 0, 0.55)

func _apply_portrait(ch):
	var path = str(ch.get("img", ""))
	if path == "":
		p_img.visible = false
		p_rect.visible = true
		p_rect.color = _col(ch.get("color", "#888888"))
		return
	var tx = _tex(path)
	if tx != null:
		p_img.texture = tx
		p_img.visible = true
		p_rect.visible = false
	else:
		p_img.visible = false
		p_rect.visible = true
		p_rect.color = _col(ch.get("color", "#888888"))

func _tex(path):
	if path == "":
		return null
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	if not FileAccess.file_exists(path):
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
		_apply_bg(L)
