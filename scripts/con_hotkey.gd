extends Node
var con_win = null
var work_node = null
var mode_lab: Label
func _ready():
	mode_lab = Label.new()
	get_tree().root.add_child(mode_lab)
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
