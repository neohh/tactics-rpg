class_name CombatModes
extends RefCounted
# Реестр боевых режимов. Чтобы добавить режим:
#   1) создать скрипт-наследник CombatModeBase в scripts/combat/;
#   2) добавить ветку в script_for() ниже.
# Ключи — литералы Game.CombatMode (autoload недоступен в const-выражениях):
#   0 = REALTIME_FP, 1 = HYBRID_QTE, 2 = TURN_BASED.

const REALTIME_SCRIPT = preload("res://scripts/combat/realtime_mode.gd")
const TURN_SCRIPT = preload("res://scripts/combat/turn_mode.gd")

static func script_for(mode_id: int) -> GDScript:
	match mode_id:
		0:
			return REALTIME_SCRIPT
		1, 2:
			return TURN_SCRIPT
	return null

static func make(mode_id: int, battle: Node3D) -> CombatModeBase:
	var s = script_for(mode_id)
	if s == null:
		return null
	var inst: CombatModeBase = s.new()
	inst.setup(battle, mode_id)
	return inst
