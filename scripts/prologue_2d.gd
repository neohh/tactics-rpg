extends CanvasLayer

signal finished

var story_steps = [
	{
		"title": "Холодный рассвет на старом тракте",
		"speaker": "Каэл",
		"portrait": "res://art/swordrer.png",
		"bg_color": Color(0.04, 0.05, 0.07, 0.96),
		"text": "Дым от догорающего костра щиплет глаза. Мой прежний отряд наёмников распался после последней стычки: кто-то сбежал при первой опасности, кто-то лёг в сырую землю.\n\nВ кармане осталось всего полсотни звонких монет, верный клинок за поясом и пустой желудок.",
		"hint": "💡 Еда и время: Перемещение между поселениями на глобальной карте расходует 1 запас провизии и 2 часа времени. Следите за припасами, чтобы не страдать от усталости."
	},
	{
		"title": "Деревенские крыши на горизонте",
		"speaker": "Каэл",
		"portrait": "res://art/swordrer.png",
		"bg_color": Color(0.05, 0.06, 0.08, 0.96),
		"text": "На холме показались крыши деревни. В округе неспокойно: доходят слухи, что шайка головорезов намертво перекрыла перевал.\n\nОдному соваться туда — верная гибель. Нужно встретиться со Старостой, а затем заглянуть в местную таверну и нанять верных клинков в новый отряд.",
		"hint": "💡 Наём отряда: В деревенской таверне [N] всегда можно найти вольных бойцов разных классов (лучники, алебардисты, маги), готовых присоединиться к отряду за золото."
	}
]

var step_idx: int = 0
var title_lbl: Label
var speaker_lbl: Label
var text_lbl: Label
var hint_lbl: Label
var port_rect: TextureRect
var port_box: PanelContainer
var hint_panel: PanelContainer
var next_btn: Button
var skip_btn: Button
var step_lbl: Label

func _ready():
	_build_ui()
	_show_step(0)

func _build_ui():
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	# Затемнённый глубокий атмосферный фон
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.03, 0.05, 0.92)
	root.add_child(bg)

	# Центральное окно 2D-новеллы
	var panel = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -440
	panel.offset_right = 440
	panel.offset_top = -250
	panel.offset_bottom = 250

	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.09, 0.12, 0.98)
	st.border_color = Color(0.82, 0.52, 0.22, 1.0) # Бронзово-медная рамка
	st.set_border_width_all(2)
	st.set_corner_radius_all(8)
	st.content_margin_left = 24
	st.content_margin_right = 24
	st.content_margin_top = 20
	st.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", st)
	root.add_child(panel)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	# Шапка новеллы
	var head = HBoxContainer.new()
	vb.add_child(head)

	title_lbl = Label.new()
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	head.add_child(title_lbl)

	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)

	step_lbl = Label.new()
	step_lbl.add_theme_font_size_override("font_size", 12)
	step_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	head.add_child(step_lbl)

	var sep = HSeparator.new()
	sep.modulate = Color(0.8, 0.55, 0.25, 0.5)
	vb.add_child(sep)

	# Основная секция: Портрет слева + Текст справа
	var body = HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(body)

	port_box = PanelContainer.new()
	port_box.custom_minimum_size = Vector2(130, 150)
	var p_st = StyleBoxFlat.new()
	p_st.bg_color = Color(0.12, 0.13, 0.17, 1.0)
	p_st.border_color = Color(0.7, 0.45, 0.2, 0.9)
	p_st.set_border_width_all(2)
	p_st.set_corner_radius_all(6)
	port_box.add_theme_stylebox_override("panel", p_st)
	body.add_child(port_box)

	port_rect = TextureRect.new()
	port_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	port_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	port_box.add_child(port_rect)

	var text_vb = VBoxContainer.new()
	text_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vb.add_theme_constant_override("separation", 8)
	body.add_child(text_vb)

	speaker_lbl = Label.new()
	speaker_lbl.add_theme_font_size_override("font_size", 14)
	speaker_lbl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.4))
	text_vb.add_child(speaker_lbl)

	text_lbl = Label.new()
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_lbl.add_theme_font_size_override("font_size", 13)
	text_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.94))
	text_vb.add_child(text_lbl)

	# Блок полезных подсказок по механике
	hint_panel = PanelContainer.new()
	var h_st = StyleBoxFlat.new()
	h_st.bg_color = Color(0.06, 0.08, 0.11, 0.9)
	h_st.border_color = Color(0.35, 0.6, 0.85, 0.7) # Синеватый тон для обучения
	h_st.set_border_width_all(1)
	h_st.set_corner_radius_all(4)
	h_st.content_margin_left = 12
	h_st.content_margin_right = 12
	h_st.content_margin_top = 8
	h_st.content_margin_bottom = 8
	hint_panel.add_theme_stylebox_override("panel", h_st)
	vb.add_child(hint_panel)

	hint_lbl = Label.new()
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_lbl.add_theme_font_size_override("font_size", 12)
	hint_lbl.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	hint_panel.add_child(hint_lbl)

	# Нижняя панель с кнопками
	var foot = HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	vb.add_child(foot)

	skip_btn = Button.new()
	skip_btn.text = "Пропустить введение"
	skip_btn.custom_minimum_size = Vector2(160, 32)
	skip_btn.pressed.connect(_on_finish)
	foot.add_child(skip_btn)

	var sp2 = Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp2)

	next_btn = Button.new()
	next_btn.text = "Далее ➔"
	next_btn.custom_minimum_size = Vector2(140, 32)
	var b_st = StyleBoxFlat.new()
	b_st.bg_color = Color(0.18, 0.14, 0.08, 0.95)
	b_st.border_color = Color(0.85, 0.55, 0.25, 1.0)
	b_st.set_border_width_all(1)
	b_st.set_corner_radius_all(4)
	next_btn.add_theme_stylebox_override("normal", b_st)
	next_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	next_btn.pressed.connect(_on_next)
	foot.add_child(next_btn)

func _show_step(i: int):
	step_idx = i
	if step_idx >= story_steps.size():
		_on_finish()
		return

	var d = story_steps[step_idx]
	title_lbl.text = d.get("title", "")
	speaker_lbl.text = "— " + d.get("speaker", "")
	text_lbl.text = d.get("text", "")
	var h_txt = d.get("hint", "")
	hint_lbl.text = h_txt
	hint_panel.visible = (h_txt != "")
	step_lbl.text = "%d / %d" % [step_idx + 1, story_steps.size()]

	var p_path = d.get("portrait", "")
	if p_path != "" and FileAccess.file_exists(p_path):
		var img = Image.new()
		if img.load(p_path) == OK:
			port_rect.texture = ImageTexture.create_from_image(img)
			port_box.visible = true
	else:
		port_box.visible = false

	if step_idx == story_steps.size() - 1:
		next_btn.text = "В путь! ⚔️"
	else:
		next_btn.text = "Далее ➔"

func _on_next():
	_show_step(step_idx + 1)

func _on_finish():
	finished.emit()
	queue_free()
