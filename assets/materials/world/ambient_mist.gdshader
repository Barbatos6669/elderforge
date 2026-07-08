shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

uniform vec4 mist_color : source_color = vec4(0.62, 0.78, 0.82, 0.20);
uniform float alpha_strength : hint_range(0.0, 1.0, 0.01) = 0.26;
uniform float edge_softness : hint_range(0.5, 6.0, 0.1) = 2.4;
uniform float noise_scale : hint_range(1.0, 32.0, 0.5) = 9.0;
uniform float drift_speed : hint_range(0.0, 1.0, 0.01) = 0.05;

float hash21(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 uv) {
	vec2 cell = floor(uv);
	vec2 local = fract(uv);
	vec2 smooth_local = local * local * (3.0 - 2.0 * local);

	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));

	return mix(mix(a, b, smooth_local.x), mix(c, d, smooth_local.x), smooth_local.y);
}

void fragment() {
	vec2 centered_uv = UV * 2.0 - 1.0;
	float radial_fade = pow(clamp(1.0 - length(centered_uv), 0.0, 1.0), edge_softness);
	float drifting_noise = value_noise(UV * noise_scale + vec2(TIME * drift_speed, TIME * drift_speed * 0.37));
	float soft_noise = mix(0.62, 1.0, drifting_noise);

	ALBEDO = mist_color.rgb;
	ALPHA = mist_color.a * alpha_strength * radial_fade * soft_noise;
}
