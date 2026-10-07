extends Node
var con_win = null
var work_node = null
var mode_lab: Label
func _ready():
	mode_lab = Label.new()
	get_tree().root.add_child.call_deferred(mode_lab)
	mode_lab.anchor_top = 1.0
	mode_lab.anchor_bottom = 1.0
	mode_lab.offset_left = 8
	mode_lab.offset_top = -24
	mode_lab.offset_bottom = -4
	mode_lab.modulate = Color(1, 1, 0.6)
func _process(_d):
	var cur = get_tree().current_scene
	work_node = cur if (cur != null and cur.is_in_group("work")) else null
	if mode_lab != null:
		var n = cur.name if cur != null else "?"
		var txt = "БОЙ" if n == "World3D" else ("МАСТЕРСКАЯ" if n == "Work3D" else ("КАРТА" if n == "Overworld3D" else "МЕНЮ"))
		mode_lab.text = "РЕЖИМ: " + txt
func _unhandled_input(ev):
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_C:
		toggle()
	elif ev is InputEventKey and ev.pressed and ev.keycode == KEY_F3:
		toggle_graphics()

var gfx_win = null
func toggle_graphics():
	if gfx_win == null or not is_instance_valid(gfx_win):
		open_graphics_window()
	else:
		gfx_win.visible = not gfx_win.visible

func open_graphics_window():
	GraphicsSettings.load_settings()
	if gfx_win != null and is_instance_valid(gfx_win):
		gfx_win.visible = true
		return
	gfx_win = Window.new()
	gfx_win.title = "Настройки графики (F3)"
	gfx_win.size = Vector2i(380, 260)
	gfx_win.exclusive = false
	gfx_win.unresizable = true
	var screen = DisplayServer.screen_get_size()
	gfx_win.position = Vector2i(int((screen.x - 380) * 0.5), int((screen.y - 260) * 0.5))
	gfx_win.close_requested.connect(func(): gfx_win.visible = false)

	var p = Panel.new()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	gfx_win.add_child(p)

	var vb = VBoxContainer.new()
	vb.position = Vector2(20, 16)
	vb.size = Vector2(340, 220)
	vb.add_theme_constant_override("separation", 10)
	p.add_child(vb)

	var title = Label.new()
	title.text = "ГРАФИКА И ЭФФЕКТЫ [F3]"
	title.add_theme_font_size_override("font_size", 16)
	vb.add_child(title)

	var chk_fog = CheckBox.new()
	chk_fog.text = "Плотный туман по границе острова"
	chk_fog.button_pressed = GraphicsSettings.fog_enabled
	chk_fog.toggled.connect(func(v): GraphicsSettings.set_fog_enabled(v))
	vb.add_child(chk_fog)

	var chk_day = CheckBox.new()
	chk_day.text = "Суточный цикл и динамическое небо"
	chk_day.button_pressed = GraphicsSettings.day_night_enabled
	chk_day.toggled.connect(func(v): GraphicsSettings.set_day_night_enabled(v))
	vb.add_child(chk_day)

	var chk_lit = CheckBox.new()
	chk_lit.text = "Освещение спрайтов (шейдеры Direct Light)"
	chk_lit.button_pressed = GraphicsSettings.sprite_lighting_enabled
	chk_lit.toggled.connect(func(v): GraphicsSettings.set_sprite_lighting_enabled(v))
	vb.add_child(chk_lit)

	var chk_fade = CheckBox.new()
	chk_fade.text = "Мягкие края тумана (Proximity Fade)"
	chk_fade.button_pressed = GraphicsSettings.proximity_fade_enabled
	chk_fade.toggled.connect(func(v): GraphicsSettings.set_proximity_fade_enabled(v))
	vb.add_child(chk_fade)

	var b_close = Button.new()
	b_close.text = "Закрыть"
	b_close.pressed.connect(func(): gfx_win.visible = false)
	vb.add_child(b_close)

	get_tree().root.add_child(gfx_win)

func toggle():
	if con_win == null:
		open()
	else:
		con_win.visible = not con_win.visible
		if con_win.visible:
			_layout()
func open():
	if con_win == null:
		con_win = Window.new()
		con_win.title = "Конструктор"
		var con = load("res://scripts/constructor.gd").new()
		con.embedded = true
		con_win.add_child(con)
		get_tree().root.add_child(con_win)
		_layout()
	else:
		con_win.visible = true
func _layout():
	var screen = DisplayServer.screen_get_size()
	var half = int(screen.x * 0.5)
	DisplayServer.window_set_size(Vector2i(half - 6, 700))
	DisplayServer.window_set_position(Vector2i(0, 0))
	con_win.size = Vector2i(screen.x - half - 10, 760)
	con_win.position = Vector2i(half + 2, 0)
func show_work():
	get_tree().change_scene_to_file("res://work3d.tscn")
func hide_work():
	pass

var dialog_prev = null
func dialog_preview(data, chars_dict):
	if dialog_prev == null or not is_instance_valid(dialog_prev):
		dialog_prev = load("res://scripts/dialog.gd").new()
		get_tree().root.add_child(dialog_prev)
	dialog_prev.play_preview(data, chars_dict)
func dialog_preview_stop():
	if dialog_prev != null and is_instance_valid(dialog_prev):
		dialog_prev.queue_free()
		dialog_prev = null
