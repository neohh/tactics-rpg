class_name CombatModeBase
extends RefCounted
# Контракт боевого режима для сцены боя (world3d.gd).
#
# Разделение ответственности:
#   - СЦЕНА владеет данными: юниты (units3), камера-риг, terrain, тактический UI.
#   - РЕЖИМ владеет поведением: управление, AI, HUD режима, правила входа/выхода.
#
# У режима НЕТ собственного _process и _unhandled_input: сцена сама вызывает
# process() и input() у активного режима. Одновременно активен ровно один режим,
# поэтому режимы не пересекаются. Новый режим = унаследовать этот класс и
# добавить ветку в combat_modes.gd (реестр).
#
# Обращение к сцене — через переменную battle (duck typing, как в GDScript принято):
# battle.units3, battle.cam, battle._th(...) и т.д.

var battle: Node3D
var mode_id: int = -1

func setup(b: Node3D, mid: int) -> void:
	battle = b
	mode_id = mid

func id() -> int:
	return mode_id

# Можно ли включить этот режим прямо сейчас (false — переключение будет откачено).
func can_enter() -> bool:
	return true

# Текст для строки статуса сцены, когда can_enter() == false.
func block_reason() -> String:
	return ""

# Вход в режим. prev_mode — id предыдущего режима (-1 если режима не было);
# режимы-наследники могут по нему не сбрасывать состояние при "холом" переключении.
func enter(_prev_mode: int) -> void:
	pass

# Выход из режима: режим обязан вернуть сцене камеру, мышь и видимость юнитов.
func exit() -> void:
	pass

# true — режим сейчас перехватил управление (сцена не применяет свою камеру
# и не обрабатывает свой пошаговый ввод). Для событийных режимов (пошаговый)
# всегда false: сценой управляет сама сцена.
func is_active() -> bool:
	return false

func process(_delta: float) -> void:
	pass

# Возвращает true, если событие поглощено режимом.
func input(_ev: InputEvent) -> bool:
	return false
