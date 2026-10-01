extends Control
var le = null
var DATA = {}
var dirty = false
var ttl: Label
var conf: ConfirmationDialog
var conf2: ConfirmationDialog
var pending_id = ""
func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	DATA = _lj("res://data/locations.json")
	var top = HBoxContainer.new()
	top.position = Vector2(8, 4)
	add_child(top)
	var bb = Button.new()
	bb.text = "← в игру"
	bb.pressed.connect(_back)
	top.add_child(bb)
	if (Game.edit_loc == "" or not DATA.has(Game.edit_loc)) and DATA.size() > 0:
		Game.edit_loc = DATA.keys()[0]
	ttl = Label.new()
	ttl.text = "МАСТЕРСКАЯ ЛОКАЦИЙ: %s" % Game.edit_loc
	top.add_child(ttl)
	conf = ConfirmationDialog.new()
	add_child(conf)
	conf.confirmed.connect(func(): _write(); _exit())
	conf.canceled.connect(_exit)
	conf2 = ConfirmationDialog.new()
	add_child(conf2)
	conf2.confirmed.connect(func(): _write(); _do_switch())
	conf2.canceled.connect(_do_switch)
	_mount(Game.edit_loc)
func _mount(id):
	if le != null:
		le.queue_free()
	le = load("res://scripts/loc_editor.gd").new()
	le.setup(DATA, id, "res://data/locations.json", true)
	le.dirty.connect(func(): dirty = true)
	le.save_req.connect(_write)
	le.set_anchors_preset(Control.PRESET_FULL_RECT)
	le.offset_top = 34
	add_child(le)
	dirty = false
func switch_loc(id):
	pending_id = id
	if dirty:
		conf2.dialog_text = "Сохранить изменения в «%s»?" % _name_of(Game.edit_loc)
		conf2.popup_centered()
	else:
		_do_switch()
func _do_switch():
	Game.edit_loc = pending_id
	DATA = _lj("res://data/locations.json")
	ttl.text = "МАСТЕРСКАЯ ЛОКАЦИЙ: %s" % pending_id
	_mount(pending_id)
func _back():
	if dirty:
		conf.dialog_text = "Сохранить изменения в «%s»?" % _name_of(Game.edit_loc)
		conf.popup_centered()
	else:
		_exit()
func _name_of(id):
	return str(DATA.get(id, {}).get("name", id))
func _write():
	DataLoader.save_json("res://data/locations.json", DATA)
	get_tree().call_group("live", "live_reload")
	dirty = false
func _exit():
	var ret = Game.return_scene if (Game.return_scene != null and Game.return_scene != "") else "res://constructor.tscn"
	get_tree().change_scene_to_file(ret)
func _lj(p):
	return DataLoader.load_json(p)
