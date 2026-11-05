extends CombatModeBase
# Пошаговый и гибридный режимы. Логика хода (активации, AI врага, QTE-дуэли)
# живёт в самой сцене world3d.gd и не переносится — класс нужен как режим-обёртка,
# чтобы вход/выход реалтайма корректно возвращал тактический интерфейс и камеру.

func can_enter() -> bool:
	return true

func block_reason() -> String:
	return ""

func enter(prev_mode: int) -> void:
	# Переключение внутри пошаговых режимов (гибрид <-> классика) не должно
	# сбрасывать текущий выбор юнита и ход.
	if prev_mode == 1 or prev_mode == 2:
		return
	# Пул активаций НЕ пересчитывается: остаток хода сохраняется через
	# реалтайм-переключение, иначе каждый F6-цикл дарил бы свежий ход.
	battle.combat_ui_root.visible = true
	battle.combat_ui_root.modulate.a = 1.0
	battle.hl_root.visible = true
	battle.hover_hl_root.visible = true
	battle.selected = -1
	battle.acted_idx = -1
	battle.shove_mode = false
	battle.arrow_mode = false
	battle.heal_mode = false
	battle.fire1_mode = false
	battle.casting = false
	if not battle.game_over3:
		battle.status.text = "Твой ход: клик по своему юниту."
	battle._upd_info()

func exit() -> void:
	pass

func is_active() -> bool:
	return false
