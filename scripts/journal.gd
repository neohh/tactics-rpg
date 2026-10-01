extends CanvasLayer
var root: Control
var lab: Label
func _ready():
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(_click)
	add_child(root)
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	lab = Label.new()
	lab.position = Vector2(40, 40)
	lab.add_theme_font_size_override("font_size", 16)
	root.add_child(lab)
	refresh()
func refresh():
	lab.text = Game.journal_text() + "\n(клик — закрыть)"
func _click(ev):
	if ev is InputEventMouseButton and ev.pressed:
		visible = false

func _unhandled_input(ev):
	if visible and ev is InputEventKey and ev.pressed and ev.keycode == KEY_J:
		visible = false
		get_viewport().set_input_as_handled()
