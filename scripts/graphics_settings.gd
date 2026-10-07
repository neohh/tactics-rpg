# scripts/graphics_settings.gd
# Единый модуль управления графическими фичами (туман, суточный цикл, шейдеры освещения спрайтов).
# Позволяет на лету переключать любую фичу тумблером (через код, меню настроек или горячую клавишу F3).
class_name GraphicsSettings
extends RefCounted

const SAVE_PATH = "user://graphics_settings.json"

static var fog_enabled: bool = true
static var day_night_enabled: bool = true
static var sprite_lighting_enabled: bool = true
static var proximity_fade_enabled: bool = true

static var _loaded: bool = false

## Загрузка настроек
static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	if FileAccess.file_exists(SAVE_PATH):
		var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f != null:
			var txt = f.get_as_text()
			f.close()
			var parsed = JSON.parse_string(txt)
			if parsed is Dictionary:
				fog_enabled = bool(parsed.get("fog_enabled", true))
				day_night_enabled = bool(parsed.get("day_night_enabled", true))
				sprite_lighting_enabled = bool(parsed.get("sprite_lighting_enabled", true))
				proximity_fade_enabled = bool(parsed.get("proximity_fade_enabled", true))

## Сохранение настроек
static func save_settings() -> void:
	var d = {
		"fog_enabled": fog_enabled,
		"day_night_enabled": day_night_enabled,
		"sprite_lighting_enabled": sprite_lighting_enabled,
		"proximity_fade_enabled": proximity_fade_enabled,
	}
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d, "\t"))
		f.close()

## Переключение тумана по периметру
static func set_fog_enabled(val: bool) -> void:
	fog_enabled = val
	save_settings()
	_apply_to_scene()

## Переключение динамического неба и солнца
static func set_day_night_enabled(val: bool) -> void:
	day_night_enabled = val
	save_settings()
	_apply_to_scene()

## Переключение шейдера освещения спрайтов
static func set_sprite_lighting_enabled(val: bool) -> void:
	sprite_lighting_enabled = val
	save_settings()
	_apply_to_scene()

## Переключение мягких краев тумана (proximity fade)
static func set_proximity_fade_enabled(val: bool) -> void:
	proximity_fade_enabled = val
	save_settings()
	_apply_to_scene()

static func _apply_to_scene() -> void:
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root != null:
		var cur = main_loop.current_scene
		if cur != null and cur.has_method("_apply_graphics_settings"):
			cur._apply_graphics_settings()
