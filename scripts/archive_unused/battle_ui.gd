class_name BattleUI
extends Control

# BattleUI — только отображение боя.
# Не меняет состояние боя напрямую. Только показывает данные и шлёт сигналы.

signal end_turn_pressed
signal start_pressed
signal skill_pressed(id: String)

var status: Label
var info: Label
var act_lab: Label
var skills_box: VBoxContainer
var start_btn: Button
var end_turn_btn: Button

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()

func _build():
	end_turn_btn = Button.new()
	end_turn_btn.focus_mode = Control.FOCUS_NONE
	end_turn_btn.text = "Завершить ход"
	end_turn_btn.position = Vector2(10, 10)
	end_turn_btn.pressed.connect(func(): end_turn_pressed.emit())
	add_child(end_turn_btn)

	start_btn = Button.new()
	start_btn.focus_mode = Control.FOCUS_NONE
	start_btn.text = "В БОЙ"
	start_btn.position = Vector2(150, 10)
	start_btn.visible = false
	start_btn.pressed.connect(func(): start_pressed.emit())
	add_child(start_btn)

	act_lab = Label.new()
	act_lab.position = Vector2(400, 10)
	act_lab.add_theme_color_override("font_color", Color(1, 0.9, 0.1))
	add_child(act_lab)

	status = Label.new()
	status.position = Vector2(10, 45)
	add_child(status)

	info = Label.new()
	info.position = Vector2(10, 70)
	add_child(info)

	skills_box = VBoxContainer.new()
	skills_box.position = Vector2(880, 60)
	skills_box.custom_minimum_size = Vector2(240, 0)
	add_child(skills_box)

func set_status(t: String):
	if status != null:
		status.text = t

func set_info(t: String):
	if info != null:
		info.text = t

func set_activations(left: int):
	if act_lab != null:
		act_lab.text = "Активаций: %d из 2" % left

func set_start_visible(v: bool):
	if start_btn != null:
		start_btn.visible = v

func set_end_turn_visible(v: bool):
	if end_turn_btn != null:
		end_turn_btn.visible = v

func set_end_turn_enabled(v: bool):
	if end_turn_btn != null:
		end_turn_btn.disabled = not v

func clear_skills():
	if skills_box == null:
		return
	for c in skills_box.get_children():
		c.queue_free()

func show_unit_skills(unit: Dictionary, classes: Dictionary):
	clear_skills()
	if unit.is_empty():
		return

	var title = Label.new()
	title.text = "НАВЫКИ"
	skills_box.add_child(title)

	var nm = Label.new()
	nm.text = str(classes.get(str(unit.get("cls", "")), {}).get("name", ""))
	skills_box.add_child(nm)

	var cls = str(unit.get("cls", ""))
	if cls == "swordsman":
		_add_skill_button("shove", "Толчок")
	elif cls == "archer":
		_add_skill_button("fire_arrow", "Огненная стрела")
	elif cls == "assassin":
		_add_label("Проскользнуть: сквозь юнитов (QTE)")
	elif cls == "mage":
		_add_skill_button("heal", "Лечение (%d)" % int(unit.get("heal_uses", 0)))
		_add_skill_button("mage_fire", "Огонь 3x3 (%d)" % int(unit.get("fire_uses", 0)))
	elif cls == "halberd":
		_add_label("Дальность 2; бьёт подошедших вплотную")

func _add_skill_button(id: String, text: String):
	var b = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = text
	b.pressed.connect(func(): skill_pressed.emit(id))
	skills_box.add_child(b)

func _add_label(text: String):
	var l = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	skills_box.add_child(l)
