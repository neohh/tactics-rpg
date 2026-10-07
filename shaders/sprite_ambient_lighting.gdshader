shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap;
uniform bool proximity_fade_enabled = true;
uniform float proximity_fade_distance : hint_range(0.0, 10.0) = 1.5;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

void vertex() {
	// Сферический биллборд с сохранением масштаба ноды
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
}

void fragment() {
	vec4 tex = texture(texture_albedo, UV);
	ALBEDO = tex.rgb * COLOR.rgb;
	ALPHA = tex.a * COLOR.a;

	if (proximity_fade_enabled) {
		float depth = texture(depth_texture, SCREEN_UV).r;
		// В Godot 4 глубина из depth_texture
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
		vec4 view_pos = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		view_pos.xyz /= view_pos.w;
		// Разница глубин: если объект пересекает геометрию, плавно гасим прозрачность на стыке
		float scene_depth = -view_pos.z;
		float vertex_depth = -VERTEX.z;
		float diff = scene_depth - vertex_depth;
		if (diff >= 0.0 && diff < proximity_fade_distance) {
			ALPHA *= clamp(diff / proximity_fade_distance, 0.0, 1.0);
		}
	}
}

void light() {
	// Всегда освещённая сторона: спрайт тумана не погружается в темноту при вращении камеры
	DIFFUSE_LIGHT += LIGHT_COLOR * (ALBEDO * ATTENUATION);
}
