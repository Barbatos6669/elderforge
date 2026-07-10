shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 grass_shadow : source_color = vec4(0.13, 0.22, 0.12, 1.0);
uniform vec4 grass_mid : source_color = vec4(0.18, 0.30, 0.15, 1.0);
uniform vec4 grass_light : source_color = vec4(0.24, 0.38, 0.18, 1.0);
uniform vec4 moss_warm : source_color = vec4(0.30, 0.35, 0.16, 1.0);
uniform vec4 soil_shadow : source_color = vec4(0.13, 0.095, 0.055, 1.0);
uniform vec4 soil_warm : source_color = vec4(0.24, 0.16, 0.09, 1.0);
uniform float large_noise_scale : hint_range(0.005, 0.35, 0.005) = 0.13;
uniform float small_noise_scale : hint_range(0.05, 1.2, 0.01) = 0.62;
uniform float worn_patch_strength : hint_range(0.0, 0.5, 0.01) = 0.08;

varying vec3 world_position;

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

float fbm(vec2 uv) {
	return value_noise(uv) * 0.55
		+ value_noise(uv * 2.17 + vec2(19.4, 8.1)) * 0.30
		+ value_noise(uv * 4.03 + vec2(-5.8, 27.2)) * 0.15;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 world_uv = world_position.xz;
	vec2 warp = vec2(
		fbm(world_uv * 0.055 + vec2(11.0, -4.0)),
		fbm(world_uv * 0.055 + vec2(-17.0, 23.0))
	) * 4.0;
	float large_variation = fbm((world_uv + warp) * large_noise_scale);
	float small_variation = fbm((world_uv + warp * 0.35) * small_noise_scale);
	float warm_variation = fbm((world_uv + warp) * 0.065 + vec2(31.0, -12.0));
	float worn_patches = smoothstep(0.68, 0.92, fbm((world_uv + warp) * 0.11 + vec2(7.0, 14.0)));

	float grass_tint = clamp(
		0.54
		+ (large_variation - 0.5) * 0.26
		+ (small_variation - 0.5) * 0.14
		+ (warm_variation - 0.5) * 0.08,
		0.0,
		1.0
	);
	vec3 grass_color = mix(grass_shadow.rgb, grass_light.rgb, grass_tint);
	grass_color = mix(grass_color, grass_mid.rgb, 0.35);
	grass_color = mix(grass_color, moss_warm.rgb, warm_variation * 0.06);
	vec3 soil_color = mix(soil_shadow.rgb, soil_warm.rgb, large_variation);
	float soil_amount = clamp(worn_patches * worn_patch_strength + (1.0 - small_variation) * 0.01, 0.0, 0.08);

	ALBEDO = mix(grass_color, soil_color, soil_amount);
	ROUGHNESS = 0.92;
	SPECULAR = 0.18;
	AO = mix(0.82, 1.0, small_variation);
}
