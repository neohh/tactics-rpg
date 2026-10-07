# scripts/day_night.gd
# Динамический суточный цикл: процедурное небо, глобальное солнце/луна и рассеянный свет.
class_name DayNight
extends RefCounted

static var current_visual_hour: float = 8.0
static var sky_mat: ProceduralSkyMaterial = null
static var _cloud_shader: Shader = null
static var _tree_shader: Shader = null

static func get_cloud_material(tex: Texture2D) -> Material:
	GraphicsSettings.load_settings()
	if not GraphicsSettings.sprite_lighting_enabled:
		var bm = StandardMaterial3D.new()
		bm.albedo_texture = tex
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		bm.cull_mode = BaseMaterial3D.CULL_DISABLED
		return bm
	if _cloud_shader == null:
		_cloud_shader = load("res://shaders/sprite_ambient_lighting.gdshader")
	var sm = ShaderMaterial.new()
	sm.shader = _cloud_shader
	sm.set_shader_parameter("texture_albedo", tex)
	sm.set_shader_parameter("proximity_fade_enabled", GraphicsSettings.proximity_fade_enabled)
	sm.set_shader_parameter("proximity_fade_distance", 1.5)
	return sm

static func get_tree_material(tex: Texture2D) -> Material:
	GraphicsSettings.load_settings()
	if not GraphicsSettings.sprite_lighting_enabled:
		var bm = StandardMaterial3D.new()
		bm.albedo_texture = tex
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		bm.alpha_scissor_threshold = 0.35
		bm.cull_mode = BaseMaterial3D.CULL_DISABLED
		return bm
	if _tree_shader == null:
		_tree_shader = load("res://shaders/tree_ambient_lighting.gdshader")
	var sm = ShaderMaterial.new()
	sm.shader = _tree_shader
	sm.set_shader_parameter("texture_albedo", tex)
	return sm

static func get_actor_material(tex: Texture2D) -> Material:
	return get_tree_material(tex)

## Настройка динамического неба и глобального освещения
static func setup(env: Environment, sun: DirectionalLight3D, initial_hour: float = 8.0) -> void:
	GraphicsSettings.load_settings()
	current_visual_hour = initial_hour

	if not GraphicsSettings.day_night_enabled:
		# Базовое статическое окружение
		if env != null:
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.06, 0.07, 0.09)
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.55, 0.55, 0.6)
			env.ambient_light_energy = 0.7
		if sun != null:
			sun.light_color = Color(1.0, 0.95, 0.85)
			sun.light_energy = 1.0
			sun.rotation_degrees = Vector3(-50, 30, 0)
			sun.shadow_enabled = true
		return

	if env != null:
		sky_mat = ProceduralSkyMaterial.new()
		var sky = Sky.new()
		sky.sky_material = sky_mat
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_sky_contribution = 0.55
		env.tonemap_mode = Environment.TONE_MAPPER_ACES

	if sun != null:
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 150.0

	apply_hour(env, sun, current_visual_hour)

## Плавное обновление в _process
static func update(delta: float, target_hour: float, env: Environment, sun: DirectionalLight3D, speed: float = 2.5) -> void:
	if not GraphicsSettings.day_night_enabled:
		return
	# Обработка перехода через полночь (23:00 -> 01:00)
	var diff = target_hour - current_visual_hour
	if diff > 12.0:
		diff -= 24.0
	elif diff < -12.0:
		diff += 24.0

	if abs(diff) > 0.01:
		current_visual_hour += diff * clampf(delta * speed, 0.0, 1.0)
		if current_visual_hour >= 24.0:
			current_visual_hour -= 24.0
		elif current_visual_hour < 0.0:
			current_visual_hour += 24.0
		apply_hour(env, sun, current_visual_hour)
	elif current_visual_hour != target_hour:
		current_visual_hour = target_hour
		apply_hour(env, sun, current_visual_hour)

## Применение параметров освещения для заданного часа (0.0 .. 24.0)
static func apply_hour(env: Environment, sun: DirectionalLight3D, h: float) -> void:
	# Нормализуем час
	h = fposmod(h, 24.0)

	# Определяем фазы суток:
	# 0..4 Ночь, 4..7 Рассвет, 7..11 Утро, 11..16 День, 16..19 Полдник, 19..22 Закат, 22..24 Ночь
	var sun_color: Color
	var sun_energy: float
	var ambient_color: Color
	var ambient_energy: float
	var sky_top: Color
	var sky_horiz: Color
	var ground_bot: Color
	var ground_horiz: Color

	var sun_rot_y: float = (h / 24.0) * 360.0 - 90.0
	var sun_pitch: float = 0.0

	if h >= 5.0 and h < 8.0:
		# РАССВЕТ (5:00 - 8:00)
		var t = (h - 5.0) / 3.0
		sun_pitch = lerpf(-5.0, -35.0, t)
		sun_color = Color(1.0, 0.72, 0.48).lerp(Color(1.0, 0.90, 0.75), t)
		sun_energy = lerpf(0.3, 0.95, t)
		ambient_color = Color(0.35, 0.38, 0.55).lerp(Color(0.60, 0.65, 0.75), t)
		ambient_energy = lerpf(0.4, 0.65, t)
		sky_top = Color(0.12, 0.20, 0.45).lerp(Color(0.24, 0.48, 0.82), t)
		sky_horiz = Color(0.95, 0.55, 0.32).lerp(Color(0.75, 0.78, 0.88), t)
		ground_horiz = Color(0.45, 0.32, 0.25).lerp(Color(0.40, 0.45, 0.50), t)
		ground_bot = Color(0.08, 0.07, 0.10)
	elif h >= 8.0 and h < 18.0:
		# ДЕНЬ (8:00 - 18:00)
		var t = (h - 8.0) / 10.0
		# Пик высоты солнца в 13:00
		var peak_factor = 1.0 - abs((h - 13.0) / 5.0)
		sun_pitch = -lerpf(35.0, 65.0, peak_factor)
		sun_color = Color(1.0, 0.98, 0.92)
		sun_energy = lerpf(0.95, 1.25, peak_factor)
		ambient_color = Color(0.60, 0.68, 0.80)
		ambient_energy = lerpf(0.6, 0.8, peak_factor)
		sky_top = Color(0.20, 0.48, 0.86)
		sky_horiz = Color(0.68, 0.80, 0.94)
		ground_horiz = Color(0.45, 0.52, 0.58)
		ground_bot = Color(0.15, 0.18, 0.16)
	elif h >= 18.0 and h < 21.5:
		# ЗАКАТ (18:00 - 21:30)
		var t = (h - 18.0) / 3.5
		sun_pitch = lerpf(-35.0, -2.0, t)
		sun_color = Color(1.0, 0.88, 0.70).lerp(Color(1.0, 0.42, 0.18), t)
		sun_energy = lerpf(0.95, 0.4, t)
		ambient_color = Color(0.55, 0.50, 0.65).lerp(Color(0.25, 0.22, 0.42), t)
		ambient_energy = lerpf(0.65, 0.35, t)
		sky_top = Color(0.20, 0.42, 0.80).lerp(Color(0.10, 0.12, 0.32), t)
		sky_horiz = Color(0.70, 0.72, 0.82).lerp(Color(0.98, 0.40, 0.18), t)
		ground_horiz = Color(0.40, 0.42, 0.45).lerp(Color(0.28, 0.16, 0.18), t)
		ground_bot = Color(0.08, 0.08, 0.10)
	else:
		# НОЧЬ (21:30 - 5:00)
		# Рассчитываем лунный свет
		var night_norm: float = 0.0
		if h >= 21.5:
			night_norm = (h - 21.5) / 7.5
		else:
			night_norm = (h + 2.5) / 7.5

		sun_pitch = -32.0 # Мягкий угол падения лунного света
		sun_rot_y = ((h + 12.0) / 24.0) * 360.0 - 90.0 # Луна с противоположной стороны
		sun_color = Color(0.60, 0.75, 0.98) # Холодный серебристо-лунный оттенок
		sun_energy = 0.24 # Приглушенный ночной свет
		ambient_color = Color(0.14, 0.18, 0.32) # Читаемый ночной эмбиент
		ambient_energy = 0.35
		sky_top = Color(0.02, 0.03, 0.08) # Глубокая темная ночь
		sky_horiz = Color(0.06, 0.09, 0.18)
		ground_horiz = Color(0.04, 0.05, 0.10)
		ground_bot = Color(0.01, 0.02, 0.04)

	# Применяем к солнцу/луне
	if sun != null:
		sun.light_color = sun_color
		sun.light_energy = sun_energy
		sun.rotation_degrees = Vector3(sun_pitch, sun_rot_y, 0.0)

	# Применяем к процедурному небу и окружению
	if sky_mat != null:
		sky_mat.sky_top_color = sky_top
		sky_mat.sky_horizon_color = sky_horiz
		sky_mat.ground_bottom_color = ground_bot
		sky_mat.ground_horizon_color = ground_horiz
		sky_mat.sun_angle_max = 25.0
		sky_mat.sun_curve = 0.12

	if env != null:
		env.ambient_light_color = ambient_color
		env.ambient_light_energy = ambient_energy
