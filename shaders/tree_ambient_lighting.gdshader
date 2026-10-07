shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap;

void vertex() {
	// Y-Billboard (всегда поворачивается лицом к камере вокруг оси Y)
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]
	);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
}

void fragment() {
	vec4 tex = texture(texture_albedo, UV);
	ALBEDO = tex.rgb * COLOR.rgb;
	ALPHA = tex.a * COLOR.a;
	ALPHA_SCISSOR_THRESHOLD = 0.35;
}

void light() {
	// Всегда освещённая сторона: спрайт никогда не уходит в контражурную тень
	DIFFUSE_LIGHT += LIGHT_COLOR * (ALBEDO * ATTENUATION);
}
